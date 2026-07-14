import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';

import '../data/classified_categories.dart';
import '../models/classified_post.dart';
import '../services/classified_service.dart';
import '../widgets/listing_flow_widgets.dart';
import '../../../core/services/location_service.dart';
import '../../auth/providers/auth_provider.dart';

const Color _navy = Color(0xFF1E3A5F);
const double _listingFee = 730; // Rs./year, per the Local Finds PDF

// ─────────────────────────────────────────────────────────────────────────────
// "Claimit Local Finds — Self Registration Flow" (from the PDF), minus the
// Register/Login step — this app already has the user signed in.
//
//   Select Category → Business Name → Business Details → Business Address
//   → Contact Details → Upload Photo → Review → Make Payment → Publish
// ─────────────────────────────────────────────────────────────────────────────

class LocalFindAddListingFlow extends StatefulWidget {
  /// Pre-selected zone (when launched from a zone's subcategory screen).
  /// If null, the flow starts by asking the user to pick a zone.
  final LocalFindZone? initialZone;
  /// Pre-selected subcategory name (e.g. "Grocery") — set when the user
  /// tapped "+" while already browsing a specific subcategory list, so the
  /// flow doesn't make them pick it again. Matched against
  /// [initialZone]'s subcategories by name.
  final String? initialSubcategoryName;
  const LocalFindAddListingFlow({super.key, this.initialZone, this.initialSubcategoryName});

  @override
  State<LocalFindAddListingFlow> createState() => _LocalFindAddListingFlowState();
}

class _LocalFindAddListingFlowState extends State<LocalFindAddListingFlow> {
  // 0=category(optional), 1=subcategory(optional), 2=business name,
  // 3=details, 4=address, 5=contact, 6=photo, 7=review, 8=payment
  late int _step;
  LocalFindZone? _zone;
  ClassifiedSubcategory? _subcategory;
  // True once we know step 1 (subcategory) should never be shown for this
  // flow instance — either the zone has no subcategories, or one arrived
  // pre-selected via initialSubcategoryName. Computed once per zone
  // selection (see _recomputeSubcategorySkip) and used only for back-
  // navigation bookkeeping — it intentionally does NOT change just because
  // the user picks a subcategory normally on step 1.
  bool _subcategoryStepSkipped = false;

  final _businessNameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  late TextEditingController _phoneCtrl;

  double? _lat, _lng;
  bool _locating = false;

  XFile? _photo;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _zone = widget.initialZone;
    if (_zone != null && widget.initialSubcategoryName != null) {
      try {
        _subcategory = _zone!.subcategories
            .firstWhere((s) => s.name == widget.initialSubcategoryName);
      } catch (_) {
        _subcategory = null;
      }
    }
    _recomputeSubcategorySkip();
    _step = _zone == null ? 0 : (_subcategoryStepSkipped ? 2 : 1);
    final user = context.read<AuthProvider>().user;
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
  }

  void _recomputeSubcategorySkip() {
    _subcategoryStepSkipped =
        _subcategory != null || (_zone?.subcategories.isEmpty ?? false);
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _whatsappCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step++);
  void _back() {
    if (_step == 0) {
      context.pop();
      return;
    }
    // Skip step 1 (subcategory) on the way back too if it was never shown.
    int prev = _step - 1;
    if (prev == 1 && _subcategoryStepSkipped) prev = 0;
    // If we've walked back to the step this flow instance actually started
    // on (a zone — and possibly subcategory — was handed in), exit instead
    // of showing a category-picker step the user never saw.
    if (widget.initialZone != null && prev == 0) {
      context.pop();
      return;
    }
    setState(() => _step = prev);
  }

  String get _title {
    switch (_step) {
      case 0: return 'Select Category';
      case 1: return 'Select Subcategory';
      case 2: return 'Business Name';
      case 3: return 'Business Details';
      case 4: return 'Business Address';
      case 5: return 'Contact Details';
      case 6: return 'Upload Photo';
      case 7: return 'Review Listing';
      case 8: return 'Make Payment';
      default: return 'Local Finds';
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final pos = await LocationService.getPosition(context: context);
    if (pos == null) {
      if (mounted) setState(() => _locating = false);
      return;
    }
    _lat = pos.latitude;
    _lng = pos.longitude;
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.street, p.subLocality, p.locality, p.postalCode]
            .where((s) => s != null && s.trim().isNotEmpty)
            .join(', ');
        if (parts.isNotEmpty) _addressCtrl.text = parts;
      }
    } catch (_) {
      // Keep lat/lng even if reverse-geocoding fails — address stays editable.
    }
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1000);
    if (picked != null) setState(() => _photo = picked);
  }

  Future<void> _publish() async {
    if (_submitting || _zone == null) return;
    setState(() => _submitting = true);

    final photos = <String>[];
    if (_photo != null) {
      photos.add(base64Encode(await _photo!.readAsBytes()));
    }

    final post = ClassifiedPost(
      id: '', userId: '', userName: '', userPhone: '',
      category: _zone!.id,
      // Was hardcoded '' — meant every new Local Finds listing silently
      // failed to match the browse/filter screen's subcategory query
      // (e.g. Shop -> Grocery), even though it saved fine and showed up in
      // My Listings (which doesn't filter by subcategory at all).
      subcategory: _subcategory?.name ?? '',
      title: _businessNameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      price: 0,
      yearsOfExp: 0,
      pincode: LocationService.lastPincode,
      area: LocationService.lastArea,
      address: _addressCtrl.text.trim(),
      photos: photos,
      listingType: 'local_find',
      businessName: _businessNameCtrl.text.trim(),
      whatsapp: _whatsappCtrl.text.trim(),
      latitude: _lat,
      longitude: _lng,
      amountPaid: _listingFee,
    );

    final result = await ClassifiedService.instance.createPost(post);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result != null) {
      context.pushReplacement('/classified/list', extra: {
        'category': _zone!.id,
        'subcategory': _subcategory?.name ?? '',
        'title': _subcategory?.name ?? _zone!.label,
        'listingType': 'local_find',
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to publish. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _navy, size: 20),
            onPressed: _back,
          ),
          title: Text(
            _title,
            style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _stepCategory();
      case 1: return _stepSubcategory();
      case 2: return _stepBusinessName();
      case 3: return _stepDetails();
      case 4: return _stepAddress();
      case 5: return _stepContact();
      case 6: return _stepPhoto();
      case 7: return _stepReview();
      case 8: return _stepPayment();
      default: return const SizedBox.shrink();
    }
  }

  Widget _stepCategory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListingStepTitle('Select category'),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 16, crossAxisSpacing: 8, childAspectRatio: 0.82,
            ),
            itemCount: localFindZones.length,
            itemBuilder: (context, i) {
              final z = localFindZones[i];
              return GestureDetector(
                onTap: () => setState(() {
                  _zone = z;
                  _subcategory = null;
                  _recomputeSubcategorySkip();
                  _step = _subcategoryStepSkipped ? 2 : 1;
                }),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: const Color(0xFFF1F5F9),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Icon(z.icon, size: 26, color: _navy),
                    ),
                    const SizedBox(height: 6),
                    Text(z.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _navy)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _stepSubcategory() {
    final subs = _zone?.subcategories ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListingStepTitle('Select ${_zone?.label ?? ''} subcategory'),
        const SizedBox(height: 4),
        const Text(
          'This decides where your listing shows up when people browse.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: subs.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
            itemBuilder: (context, i) {
              final s = subs[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(s.icon, color: _navy),
                title: Text(s.name, style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937))),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
                onTap: () => setState(() { _subcategory = s; _next(); }),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _stepBusinessName() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListingStepTitle('Business name'),
        const SizedBox(height: 16),
        ListingField(controller: _businessNameCtrl, hint: 'Your business, professional, or service name'),
        const Spacer(),
        ListingPrimaryButton(
          label: 'Continue',
          onTap: () {
            if (_businessNameCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter your business name')));
              return;
            }
            _next();
          },
        ),
      ],
    );
  }

  Widget _stepDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListingStepTitle('Business details'),
        const SizedBox(height: 4),
        const Text('A short description of your business or services (up to 25 words).',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const SizedBox(height: 16),
        WordLimitedField(controller: _descCtrl, hint: 'e.g. Family-run bakery serving fresh cakes & pastries daily'),
        const Spacer(),
        ListingPrimaryButton(label: 'Continue', onTap: _next),
      ],
    );
  }

  Widget _stepAddress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListingStepTitle('Business address'),
        const SizedBox(height: 16),
        ListingField(controller: _addressCtrl, hint: 'Shop / office address', maxLines: 3),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _locating ? null : _useMyLocation,
          icon: _locating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location_rounded, size: 18),
          label: Text(_locating ? 'Detecting…' : 'Use my current location'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _navy,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const Spacer(),
        ListingPrimaryButton(
          label: 'Continue',
          onTap: () {
            if (_addressCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter an address or use your location')));
              return;
            }
            _next();
          },
        ),
      ],
    );
  }

  Widget _stepContact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListingStepTitle('Contact details'),
        const SizedBox(height: 16),
        ListingField(
          controller: _phoneCtrl, hint: 'Mobile number',
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        ListingField(
          controller: _whatsappCtrl, hint: 'WhatsApp number (optional)',
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const Spacer(),
        ListingPrimaryButton(
          label: 'Continue',
          onTap: () {
            if (_phoneCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please confirm your mobile number')));
              return;
            }
            _next();
          },
        ),
      ],
    );
  }

  Widget _stepPhoto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListingStepTitle('Upload photo'),
        const SizedBox(height: 4),
        const Text('One photo of your shop, office, product, or service.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickPhoto,
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: _photo == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: const BoxDecoration(color: Color(0xFFF3E8FF), shape: BoxShape.circle),
                        child: const Icon(Icons.upload_rounded, color: Color(0xFF7C3AED), size: 24),
                      ),
                      const SizedBox(height: 10),
                      const Text('Tap to upload', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FutureBuilder<Uint8List>(
                      future: _photo!.readAsBytes(),
                      builder: (context, snap) => snap.hasData
                          ? Image.memory(snap.data!, fit: BoxFit.cover, width: double.infinity)
                          : const SizedBox.shrink(),
                    ),
                  ),
          ),
        ),
        const Spacer(),
        ListingPrimaryButton(label: _photo == null ? 'Skip' : 'Continue', onTap: _next),
      ],
    );
  }

  Widget _stepReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListingStepTitle('Review your listing'),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_zone != null) _reviewRow('Category', _zone!.label),
                  if (_subcategory != null) _reviewRow('Subcategory', _subcategory!.name),
                  _reviewRow('Business name', _businessNameCtrl.text),
                  _reviewRow('Details', _descCtrl.text),
                  _reviewRow('Address', _addressCtrl.text),
                  _reviewRow('Phone', _phoneCtrl.text),
                  if (_whatsappCtrl.text.trim().isNotEmpty) _reviewRow('WhatsApp', _whatsappCtrl.text),
                  _reviewRow('Photo', _photo == null ? 'None' : 'Added'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListingPrimaryButton(label: 'Continue to Payment', onTap: _next),
      ],
    );
  }

  Widget _reviewRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
            Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)))),
          ],
        ),
      );

  Widget _stepPayment() {
    if (_submitting) {
      return const Center(child: CircularProgressIndicator(color: _navy));
    }
    return PaymentStep(
      amount: _listingFee,
      purpose: 'Local Finds Business Listing — ${_zone?.label ?? ''}',
      onPaid: _publish,
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../data/classified_categories.dart';
import '../models/classified_post.dart';
import '../services/classified_service.dart';
import '../widgets/listing_flow_widgets.dart';
import '../../auth/providers/auth_provider.dart';

const double _listingFee = 250; // Rs./post, per the Local Classifieds PDF

// ─────────────────────────────────────────────────────────────────────────────
// "Claimit Local Classifieds — Self Posting Flow" (from the PDF), minus the
// Register/Login step — this app already has the user signed in. Per the
// client's latest update, the Subcategory step is no longer needed.
//
//   Select Category → Title + Description → Upload Photo → Contact Details
//   → Review → Make Payment → Publish
// ─────────────────────────────────────────────────────────────────────────────

class AddPostFlowScreen extends StatefulWidget {
  const AddPostFlowScreen({super.key});

  @override
  State<AddPostFlowScreen> createState() => _AddPostFlowScreenState();
}

class _AddPostFlowScreenState extends State<AddPostFlowScreen> {
  // 0=category, 1=title+desc, 2=photo, 3=contact, 4=review, 5=payment
  int _step = 0;

  ClassifiedTopCategory? _category;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late TextEditingController _phoneCtrl;

  XFile? _photo;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step++);
  void _back() {
    if (_step == 0) {
      context.pop();
    } else {
      setState(() => _step--);
    }
  }

  String get _title {
    switch (_step) {
      case 0: return 'Select Category';
      case 1: return 'Create Your Listing';
      case 2: return 'Upload Photo';
      case 3: return 'Contact Details';
      case 4: return 'Review Listing';
      case 5: return 'Make Payment';
      default: return 'Add your new Post';
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1000);
    if (picked != null) setState(() => _photo = picked);
  }

  Future<void> _publish() async {
    if (_submitting || _category == null) return;
    setState(() => _submitting = true);

    final photos = <String>[];
    if (_photo != null) {
      photos.add(base64Encode(await _photo!.readAsBytes()));
    }

    final post = ClassifiedPost(
      id: '', userId: '', userName: '', userPhone: '',
      category: _category!.category,
      subcategory: '',
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      price: 0,
      yearsOfExp: 0,
      pincode: '',
      area: '',
      address: '',
      photos: photos,
      listingType: 'classified',
      amountPaid: _listingFee,
    );

    final result = await ClassifiedService.instance.createPost(post);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result != null) {
      context.pushReplacement('/classified/list', extra: {
        'category': _category!.category,
        'subcategory': '',
        'title': _category!.name,
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF1E40AF), size: 20),
            onPressed: _back,
          ),
          title: Text(
            _title,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
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
      case 1: return _stepTitleDescription();
      case 2: return _stepPhoto();
      case 3: return _stepContact();
      case 4: return _stepReview();
      case 5: return _stepPayment();
      default: return const SizedBox.shrink();
    }
  }

  // ── Step 0: Select Category ────────────────────────────────────────────────
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
            itemCount: localClassifiedCategories.length,
            itemBuilder: (context, i) {
              final cat = localClassifiedCategories[i];
              return GestureDetector(
                onTap: () => setState(() { _category = cat; _step = 1; }),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    cat.iconAsset != null
                        ? Image.asset(cat.iconAsset!, width: 64, height: 64)
                        : Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle, color: const Color(0xFFF1F5F9),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Icon(cat.icon, size: 26, color: const Color(0xFF334155)),
                          ),
                    const SizedBox(height: 6),
                    Text(cat.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Step 1: Title + 25-word description ────────────────────────────────────
  Widget _stepTitleDescription() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListingStepTitle('Create your listing'),
          const SizedBox(height: 16),
          ListingField(controller: _titleCtrl, hint: 'Title of your listing'),
          const SizedBox(height: 12),
          WordLimitedField(controller: _descCtrl, hint: 'Brief description (up to 25 words)'),
          const SizedBox(height: 28),
          ListingPrimaryButton(
            label: 'Continue',
            onTap: () {
              if (_titleCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a title')));
                return;
              }
              _next();
            },
          ),
        ],
      ),
    );
  }

  // ── Step 2: Upload Photo ────────────────────────────────────────────────────
  Widget _stepPhoto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListingStepTitle('Upload photo'),
        const SizedBox(height: 4),
        const Text('One clear photo of your item or service.',
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

  // ── Step 3: Contact Details ─────────────────────────────────────────────────
  Widget _stepContact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListingStepTitle('Contact details'),
        const SizedBox(height: 4),
        const Text('Confirm your mobile number — it will be shown with the listing.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const SizedBox(height: 16),
        ListingField(
          controller: _phoneCtrl, hint: 'Mobile number',
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

  // ── Step 4: Review ──────────────────────────────────────────────────────────
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
                  if (_category != null) _reviewRow('Category', _category!.name),
                  _reviewRow('Title', _titleCtrl.text),
                  _reviewRow('Description', _descCtrl.text),
                  _reviewRow('Phone', _phoneCtrl.text),
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

  // ── Step 5: Payment ─────────────────────────────────────────────────────────
  Widget _stepPayment() {
    if (_submitting) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }
    return PaymentStep(
      amount: _listingFee,
      purpose: 'Local Classifieds Listing — ${_category?.name ?? ''}',
      onPaid: _publish,
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../data/classified_categories.dart';
import '../models/classified_post.dart';
import '../services/classified_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pincode options (area → pincode → price)
// ─────────────────────────────────────────────────────────────────────────────

class _PincodeOption {
  final String area;
  final String pincode;
  final int price;
  const _PincodeOption(this.area, this.pincode, this.price);
}

const _pincodeOptions = [
  _PincodeOption('Mogappair', '600037', 200),
  _PincodeOption('Villivakkam', '600049', 200),
  _PincodeOption('Anna Nagar', '600040', 200),
  _PincodeOption('Padi', '600050', 150),
  _PincodeOption('T. Nagar', '600017', 250),
  _PincodeOption('Velachery', '600042', 200),
  _PincodeOption('Nungambakkam', '600006', 250),
  _PincodeOption('Porur', '600116', 150),
  _PincodeOption('Adyar', '600020', 200),
  _PincodeOption('Tambaram', '600045', 150),
];

// ─────────────────────────────────────────────────────────────────────────────
// AddPostFlowScreen
// ─────────────────────────────────────────────────────────────────────────────

class AddPostFlowScreen extends StatefulWidget {
  const AddPostFlowScreen({super.key});

  @override
  State<AddPostFlowScreen> createState() => _AddPostFlowScreenState();
}

class _AddPostFlowScreenState extends State<AddPostFlowScreen> {
  // Navigation step
  // 0 = select category, 1 = select subcategory,
  // 2 = details, 3 = photos, 4 = location, 5 = payment, 6 = publish
  int _step = 0;

  // Selected category/subcategory
  ClassifiedCategory? _selectedCategory;
  ClassifiedSubcategory? _selectedSubcategory;

  // Form data
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _expCtrl = TextEditingController();

  // Photos
  final List<XFile> _photos = [];

  // Location
  _PincodeOption? _selectedPincode;
  final _pincodeSearchCtrl = TextEditingController();
  List<_PincodeOption> _filteredPincodes = _pincodeOptions;

  // Payment
  String _paymentMethod = 'Credit / Debit Card';

  // Submission
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _expCtrl.dispose();
    _pincodeSearchCtrl.dispose();
    super.dispose();
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  void _next() => setState(() => _step++);
  void _back() {
    if (_step == 0) {
      context.pop();
    } else {
      setState(() => _step--);
    }
  }

  bool get _inFormFlow => _step >= 2;
  int get _formStep => _step - 2; // 0..4

  // ── Title for AppBar ───────────────────────────────────────────────────────

  String get _appBarTitle {
    if (_step == 0) return 'Add your new Post';
    if (_step == 1) return _selectedCategory?.name ?? 'Add your new Post';
    return 'Add your new Post';
  }

  // ── Photo picker ───────────────────────────────────────────────────────────

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 70, maxWidth: 800);
    if (picked.isNotEmpty) {
      setState(() {
        _photos.addAll(picked);
      });
    }
  }

  // ── Publish ────────────────────────────────────────────────────────────────

  Future<void> _publish() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    // Encode photos to base64
    final photoB64 = <String>[];
    for (final xFile in _photos) {
      final bytes = await xFile.readAsBytes();
      photoB64.add(base64Encode(bytes));
    }

    final post = ClassifiedPost(
      id: '',
      userId: '',
      userName: '',
      userPhone: '',
      category: _selectedCategory!.id,
      subcategory: _selectedSubcategory!.name,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text) ?? 0,
      yearsOfExp: int.tryParse(_expCtrl.text) ?? 0,
      pincode: _selectedPincode?.pincode ?? '',
      area: _selectedPincode?.area ?? '',
      address: '',
      paymentMethod: _paymentMethod,
      photos: photoB64,
    );

    final result = await ClassifiedService.instance.createPost(post);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result != null) {
      // Navigate to the list for the posted subcategory
      context.pushReplacement(
        '/classified/list',
        extra: {
          'category': _selectedCategory!.id,
          'subcategory': _selectedSubcategory!.name,
          'title': _selectedSubcategory!.name,
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to publish. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
            '< $_appBarTitle',
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ),
        body: Column(
          children: [
            // Stepper (only shown in form steps 2–6)
            if (_inFormFlow) _buildStepper(),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child)),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _buildStep(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stepper widget ─────────────────────────────────────────────────────────

  Widget _buildStepper() {
    const steps = [
      (Icons.list_alt_rounded, 'Details'),
      (Icons.photo_outlined, 'Photos'),
      (Icons.location_on_outlined, 'Location'),
      (Icons.currency_rupee_rounded, 'Payment'),
      (Icons.rocket_launch_rounded, 'Publish'),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            final leftDone = (i ~/ 2) < _formStep;
            return Expanded(
              child: Container(
                height: 2,
                color: leftDone
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFE2E8F0),
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final isDone = stepIdx < _formStep;
          final isCurrent = stepIdx == _formStep;
          final (icon, label) = steps[stepIdx];

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? const Color(0xFF22C55E)
                      : isCurrent
                          ? Colors.white
                          : const Color(0xFFF1F5F9),
                  border: Border.all(
                    color: isDone
                        ? const Color(0xFF22C55E)
                        : isCurrent
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFE2E8F0),
                    width: 2,
                  ),
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : icon,
                  size: 16,
                  color: isDone
                      ? Colors.white
                      : isCurrent
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFCBD5E1),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight:
                      isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent
                      ? const Color(0xFF2563EB)
                      : isDone
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF94A3B8),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Step router ────────────────────────────────────────────────────────────

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildSelectCategory();
      case 1:
        return _buildSelectSubcategory();
      case 2:
        return _buildDetailsStep();
      case 3:
        return _buildPhotosStep();
      case 4:
        return _buildLocationStep();
      case 5:
        return _buildPaymentStep();
      case 6:
        return _buildPublishStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 0: Select Category ────────────────────────────────────────────────

  Widget _buildSelectCategory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Select category',
            style: TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: classifiedCategories.length,
            itemBuilder: (context, i) {
              final cat = classifiedCategories[i];
              return _CategoryTile(
                category: cat,
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                    _step = 1;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Step 1: Select Subcategory ─────────────────────────────────────────────

  Widget _buildSelectSubcategory() {
    final subs = _selectedCategory?.subcategories ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Sub Categories',
            style: TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: subs.length,
            itemBuilder: (context, i) {
              final sub = subs[i];
              return _SubcategoryTile(
                subcategory: sub,
                categoryIcon: _selectedCategory!.icon,
                onTap: () {
                  setState(() {
                    _selectedSubcategory = sub;
                    _step = 2;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Step 2: Details ────────────────────────────────────────────────────────

  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add details',
            style: TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          _Field(
            controller: _titleCtrl,
            hint: 'Title of your service / post',
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _descCtrl,
            hint: 'Description',
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _priceCtrl,
            hint: 'Price (₹)',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _expCtrl,
            hint: 'Years of Experience',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 28),
          _PrimaryButton(
            label: 'Add details',
            onTap: () {
              if (_titleCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a title')),
                );
                return;
              }
              _next();
            },
          ),
        ],
      ),
    );
  }

  // ── Step 3: Photos ─────────────────────────────────────────────────────────

  Widget _buildPhotosStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Photos',
            style: TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),

          // Upload area
          GestureDetector(
            onTap: _pickPhotos,
            child: Container(
              width: double.infinity,
              // 160dp ≈ 20% of 800dp design baseline
              height: MediaQuery.of(context).size.height * 0.20,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFCBD5E1),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: _photos.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.upload_rounded,
                              color: Color(0xFF7C3AED), size: 24),
                        ),
                        const SizedBox(height: 10),
                        const Text('Tap to upload',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155))),
                        const Text('or drag and drop',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 4),
                        const Text('PNG, JPG up to 10MB',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFFCBD5E1))),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      itemCount: _photos.length,
                      itemBuilder: (context, i) => Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: FutureBuilder<Uint8List>(
                              future: _photos[i].readAsBytes(),
                              builder: (context, snap) => snap.hasData
                                  ? Image.memory(snap.data!,
                                      fit: BoxFit.cover)
                                  : const SizedBox.shrink(),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _photos.removeAt(i)),
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 28, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'Upload Photos',
            onTap: _next, // photos are optional
          ),
        ],
      ),
    );
  }

  // ── Step 4: Location ───────────────────────────────────────────────────────

  Widget _buildLocationStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Your Area Pincode',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),

          // Search
          TextField(
            controller: _pincodeSearchCtrl,
            onChanged: (q) {
              setState(() {
                _filteredPincodes = _pincodeOptions
                    .where((p) =>
                        p.area.toLowerCase().contains(q.toLowerCase()) ||
                        p.pincode.contains(q))
                    .toList();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search for area',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Pincode chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _filteredPincodes.map((p) {
              final selected = _selectedPincode == p;
              return GestureDetector(
                onTap: () => setState(() => _selectedPincode = p),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF2563EB)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.area,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF334155),
                        ),
                      ),
                      Text(
                        p.pincode,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected
                              ? Colors.white70
                              : const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Price based on pincode
          if (_selectedPincode != null) ...[
            Row(
              children: [
                const Text('Payment  ',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                Text(
                  '₹ ${_selectedPincode!.price}/-',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '*Your Payment Amount is Based on Pincode',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],

          const Spacer(),
          _PrimaryButton(
            label: 'Continue',
            onTap: () {
              if (_selectedPincode == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select your area pincode'),
                  ),
                );
                return;
              }
              _next();
            },
          ),
        ],
      ),
    );
  }

  // ── Step 5: Payment ────────────────────────────────────────────────────────

  Widget _buildPaymentStep() {
    const methods = [
      (Icons.credit_card_rounded, 'Credit / Debit Card', '·· ·· ·· ·· 4242'),
      (Icons.paypal_rounded, 'PayPal', 'user@email.com'),
      (Icons.apple_rounded, 'Apple Pay', 'Pay with Apple'),
      (Icons.g_mobiledata_rounded, 'Google Pay', 'Pay with Google'),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Payment  ',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
              Text(
                '₹ ${_selectedPincode?.price ?? 200}/-',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Select your payment method',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          // Payment method tiles
          ...methods.map((m) {
            final (icon, name, subtitle) = m;
            final selected = _paymentMethod == name;
            return GestureDetector(
              onTap: () => setState(() => _paymentMethod = name),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon,
                        size: 22,
                        color: selected
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF64748B)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: selected
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF1E293B),
                              )),
                          Text(subtitle,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    Radio<String>(
                      value: name,
                      groupValue: _paymentMethod,
                      activeColor: const Color(0xFF2563EB),
                      onChanged: (v) =>
                          setState(() => _paymentMethod = v!),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Add new method
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                style: BorderStyle.solid,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: Color(0xFF64748B), size: 18),
                SizedBox(width: 6),
                Text('Add New Payment Method',
                    style: TextStyle(
                        color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded,
                  size: 28, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                'Secured by 256-bit SSL encryption',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ),

          const Spacer(),
          _PrimaryButton(label: 'Pay now', onTap: _next),
        ],
      ),
    );
  }

  // ── Step 6: Publish / Preview ──────────────────────────────────────────────

  Widget _buildPublishStep() {
    final hasPhoto = _photos.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview Ad',
            style: TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),

          // Preview card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Photo or placeholder
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: hasPhoto
                      ? FutureBuilder<Uint8List>(
                          future: _photos.first.readAsBytes(),
                          builder: (context, snap) => snap.hasData
                              ? Image.memory(
                                  snap.data!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                )
                              : _previewPlaceholder(),
                        )
                      : _previewPlaceholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titleCtrl.text.isNotEmpty
                              ? _titleCtrl.text
                              : 'Your Post Title',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _descCtrl.text.isNotEmpty
                              ? _descCtrl.text
                              : 'Description...',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        if (_selectedPincode != null)
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 28, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 3),
                              Text(
                                _selectedPincode!.area,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),

          const Spacer(),
          _submitting
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF2563EB)))
              : _PrimaryButton(label: 'Publish', onTap: _publish),
        ],
      ),
    );
  }

  Widget _previewPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: const Color(0xFFEFF6FF),
      child: Icon(
        _selectedCategory?.icon ?? Icons.work_outline_rounded,
        size: 32,
        color: const Color(0xFF2563EB),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});
  final ClassifiedCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(category.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    category.subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  const _SubcategoryTile({
    required this.subcategory,
    required this.categoryIcon,
    required this.onTap,
  });
  final ClassifiedSubcategory subcategory;
  final IconData categoryIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(subcategory.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Text(
              subcategory.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF1E293B),
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D4ED8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}

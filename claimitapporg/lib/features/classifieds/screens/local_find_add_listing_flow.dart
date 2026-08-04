import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../data/classified_categories.dart';
import '../models/classified_post.dart';
import '../services/classified_service.dart';
import 'local_finds_screen.dart' show lfCurrentPosition;

// ─────────────────────────────────────────────────────────────────────────────
// Local Finds — "Register Your Business" (self-contained 3-step flow, per the
// Local Finds PDF):
//   Step 1  About Your Business    — Business Name, Address, Category
//   Step 2  Business Contact       — Email (optional), Website / Social (optional)
//   Step 3  Choose Your Plan       — Free / Standard (₹999) / Premium (₹1999),
//                                     with photo upload capped by the plan.
//
// Free publishes immediately. Paid plans publish too for now — real payment
// (Razorpay) is intentionally deferred and wired in later. The class name and
// constructor are unchanged so app routing keeps working.
// ─────────────────────────────────────────────────────────────────────────────

const Color _blue = Color(0xFF1565C0);
const Color _gold = Color(0xFFF4B400);
const Color _ink  = Color(0xFF1E293B);

class _Plan {
  final String id;       // free | standard | premium
  final String name;
  final int price;       // ₹/year (0 = free)
  final int photoLimit;
  final String tagline;
  final List<String> features;
  final String? badge;   // "Most Popular" / "Best Value"
  const _Plan(this.id, this.name, this.price, this.photoLimit, this.tagline,
      this.features, this.badge);
}

const List<_Plan> _plans = [
  _Plan('free', 'Free Plan', 0, 1,
      'List your business for free and connect with local customers.',
      ['Basic business listing', 'Show on Local Finds', 'One photo upload',
       'Direct customer contact (Call)'], null),
  _Plan('standard', 'Standard Plan', 999, 5,
      'Increase your visibility and get more inquiries from customers.',
      ['Everything in Free Plan', 'Up to 5 photos', 'Business highlights',
       'Priority listing in search'], 'Most Popular'),
  _Plan('premium', 'Premium Plan', 1999, 15,
      'Maximum visibility and more engagement for your business.',
      ['Everything in Standard Plan', 'Up to 15 photos', 'Top listing in category',
       'Business description', 'WhatsApp chat button'], 'Best Value'),
];

class LocalFindAddListingFlow extends StatefulWidget {
  /// Pre-selected zone (when launched from a category). If null, the user picks.
  final LocalFindZone? initialZone;
  /// Pre-selected subcategory name (kept for compatibility with callers).
  final String? initialSubcategoryName;
  const LocalFindAddListingFlow(
      {super.key, this.initialZone, this.initialSubcategoryName});

  @override
  State<LocalFindAddListingFlow> createState() =>
      _LocalFindAddListingFlowState();
}

class _LocalFindAddListingFlowState extends State<LocalFindAddListingFlow> {
  int _step = 0; // 0..2

  // Step 1
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _categoryId;

  // Step 2
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  // Step 3
  String _planId = 'free';
  final List<String> _photos = []; // base64 strings
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialZone?.id;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  _Plan get _plan => _plans.firstWhere((p) => p.id == _planId);
  LocalFindZone? get _zone {
    if (_categoryId == null) return null;
    for (final z in localFindZones) {
      if (z.id == _categoryId) return z;
    }
    return null;
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  bool _validateStep() {
    if (_step == 0) {
      if (_nameCtrl.text.trim().isEmpty) { _snack('Enter your business name'); return false; }
      if (_addressCtrl.text.trim().isEmpty) { _snack('Enter your business address'); return false; }
      if (_categoryId == null) { _snack('Select a business category'); return false; }
    }
    return true;
  }

  void _next() {
    if (!_validateStep()) return;
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      context.pop();
    }
  }

  Future<void> _pickPhotos() async {
    final limit = _plan.photoLimit;
    if (_photos.length >= limit) {
      _snack('Your plan allows up to $limit photo${limit > 1 ? "s" : ""}');
      return;
    }
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage(imageQuality: 60);
      for (final f in files) {
        if (_photos.length >= limit) break;
        final bytes = await f.readAsBytes();
        _photos.add(base64Encode(bytes));
      }
      if (mounted) setState(() {});
    } catch (e) {
      _snack('Could not add photos');
    }
  }

  Future<void> _submit() async {
    final zone = _zone;
    if (zone == null) { setState(() => _step = 0); _snack('Select a category'); return; }
    setState(() => _submitting = true);

    // Best-effort: stamp the business with the owner's current location so it
    // can show a distance to nearby customers. Silently skipped if unavailable.
    final pos = await lfCurrentPosition();

    final post = ClassifiedPost(
      id: '', userId: '', userName: '', userPhone: '',
      category: zone.label,
      subcategory: widget.initialSubcategoryName ?? '',
      title: _nameCtrl.text.trim(),
      description: '',
      price: _plan.price.toDouble(),
      yearsOfExp: 0,
      pincode: '',
      area: '',
      address: _addressCtrl.text.trim(),
      photos: _photos,
      listingType: 'local_find',
      businessName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      website: _websiteCtrl.text.trim(),
      plan: _planId,
      latitude: pos?.latitude,
      longitude: pos?.longitude,
    );

    // Paid plans go through a (currently static) payment step. Real Razorpay
    // is wired in later; this only simulates a successful payment.
    if (_planId != 'free') {
      final paid = await _staticPayment();
      if (!paid) {
        if (mounted) setState(() => _submitting = false);
        return;
      }
    }

    final created = await ClassifiedService.instance.createPost(post);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (created != null) {
      await _showSuccessDialog();
      if (mounted) context.pop(true);
    } else {
      _snack('Could not publish. Please try again.');
    }
  }

  // Static payment confirmation (placeholder for Razorpay). Returns true once
  // the user confirms the (simulated) payment.
  Future<bool> _staticPayment() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_plan.name, style: const TextStyle(fontWeight: FontWeight.w700, color: _blue)),
            const SizedBox(height: 6),
            Text('Amount payable: ₹${_plan.price} / year',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 8),
            const Text('Demo payment — no money is charged yet. Online payment will be enabled soon.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
            child: Text('Pay ₹${_plan.price}'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(color: Color(0xFFE7F7EC), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Color(0xFF1B7A3D), size: 36),
            ),
            const SizedBox(height: 14),
            const Text('Business Registered!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 6),
            const Text('Your business is now live on Local Finds.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['About Your Business', 'Business Contact Details', 'Choose Your Business Plan'];
    const subs = ['Tell us about your business', 'Enter your business contact details', 'Pick the plan that fits you'];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _blue, size: 20),
          onPressed: _back,
        ),
        title: const Text('Register Your Business',
            style: TextStyle(color: _blue, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: Column(
        children: [
          // Header card with progress
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titles[_step],
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 4),
                Text(subs[_step], style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                Text('Step ${_step + 1}/3',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _blue)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / 3,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFDCE7F5),
                    valueColor: const AlwaysStoppedAnimation(_blue),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _step == 0
                  ? _buildStep1()
                  : _step == 1
                      ? _buildStep2()
                      : _buildStep3(),
            ),
          ),
          // Continue / Publish button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_step < 2 ? 'Continue' : 'Publish',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1 ──────────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Business Name'),
        _field(_nameCtrl, 'Enter your business name'),
        _label('Business Address'),
        _field(_addressCtrl, 'Enter your business address', maxLines: 2),
        _label('Business Category'),
        Container(
          decoration: _boxDeco(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _categoryId,
              hint: const Text('Select a category'),
              items: localFindZones
                  .map((z) => DropdownMenuItem(value: z.id, child: Text(z.label)))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF5FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Why Register?',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _blue, fontSize: 15)),
              const SizedBox(height: 10),
              ...['Get discovered by local customers', 'Increase visibility of your business',
                  'Grow your business in your area', 'Customers can contact you directly']
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          const Icon(Icons.check_rounded, size: 16, color: _blue),
                          const SizedBox(width: 8),
                          Expanded(child: Text(t, style: const TextStyle(fontSize: 13, color: _ink))),
                        ]),
                      )),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 2 ──────────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Email (Optional)'),
        _field(_emailCtrl, 'you@example.com', keyboard: TextInputType.emailAddress),
        _label('Website / Social Media (Optional)'),
        _field(_websiteCtrl, 'https://…  or  @yourhandle'),
        const SizedBox(height: 8),
        const Text(
          'Customers will reach you by Call using your account phone number. '
          'Email and website are optional.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.5),
        ),
      ],
    );
  }

  // ── Step 3 ──────────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._plans.map(_planCard),
        const SizedBox(height: 8),
        _label('Photos (up to ${_plan.photoLimit})'),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            ..._photos.asMap().entries.map((e) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(base64Decode(e.value),
                          width: 72, height: 72, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: -6, right: -6,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(e.key)),
                        child: const CircleAvatar(
                          radius: 11, backgroundColor: Colors.white,
                          child: Icon(Icons.cancel, color: Colors.redAccent, size: 20),
                        ),
                      ),
                    ),
                  ],
                )),
            if (_photos.length < _plan.photoLimit)
              GestureDetector(
                onTap: _pickPhotos,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    border: Border.all(color: _blue),
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFEFF5FF),
                  ),
                  child: const Icon(Icons.add_a_photo_rounded, color: _blue),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _planCard(_Plan p) {
    final selected = _planId == p.id;
    return GestureDetector(
      onTap: () => setState(() => _planId = p.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF5FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? _blue : const Color(0xFFE2E8F0), width: selected ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _blue)),
                ),
                if (p.price > 0)
                  Text('₹${p.price}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _ink)),
                if (p.price > 0)
                  const Text(' /Year', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(width: 8),
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? _blue : const Color(0xFFB0BEC5)),
              ],
            ),
            const SizedBox(height: 4),
            Text(p.tagline, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4)),
            if (p.badge != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(20)),
                child: Text(p.badge!,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black)),
              ),
            ],
            const SizedBox(height: 10),
            ...p.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(children: [
                    const Icon(Icons.check_rounded, size: 15, color: _blue),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: const TextStyle(fontSize: 12.5, color: _ink))),
                  ]),
                )),
          ],
        ),
      ),
    );
  }

  // ── Small helpers ─────────────────────────────────────────────────────────
  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _ink)),
      );

  BoxDecoration _boxDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      );

  Widget _field(TextEditingController c, String hint,
      {int maxLines = 1, TextInputType? keyboard}) {
    return Container(
      decoration: _boxDeco(),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

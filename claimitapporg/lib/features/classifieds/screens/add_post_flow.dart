import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../data/classified_categories.dart';
import '../models/classified_post.dart';
import '../services/classified_service.dart';
import '../../auth/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// "Create Your Ad" — Local Classifieds self-posting flow (3 steps + success):
//   Step 1  Choose a category
//   Step 2  About Your Ad   — headline, description (25 words), contact, photos
//   Step 3  Preview Your Ad — summary + payment (static for now; Razorpay later)
// then a Payment Successful screen. User is already signed in.
// ─────────────────────────────────────────────────────────────────────────────

const Color _blue = Color(0xFF1565C0);
const Color _ink = Color(0xFF1E293B);
const Color _muted = Color(0xFF64748B);
const Color _gold = Color(0xFFF4B400);
const Color _banner = Color(0xFFE8F0FE);

const double _baseFee = 199; // ₹/post (30 days)
const double _gstRate = 0.18;

class AddPostFlowScreen extends StatefulWidget {
  const AddPostFlowScreen({super.key});

  @override
  State<AddPostFlowScreen> createState() => _AddPostFlowScreenState();
}

class _AddPostFlowScreenState extends State<AddPostFlowScreen> {
  int _step = 0; // 0 category, 1 about, 2 preview, 3 success

  String? _categoryId;
  final _headCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late final TextEditingController _phoneCtrl;
  final List<String> _photos = []; // base64
  String _payMethod = 'upi';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _headCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  ClassifiedTopCategory? get _category {
    if (_categoryId == null) return null;
    for (final c in localClassifiedCategories) {
      if (c.id == _categoryId) return c;
    }
    return null;
  }

  double get _gst => double.parse((_baseFee * _gstRate).toStringAsFixed(2));
  double get _total => double.parse((_baseFee + _gst).toStringAsFixed(2));

  int get _wordCount =>
      _descCtrl.text.trim().isEmpty ? 0 : _descCtrl.text.trim().split(RegExp(r'\s+')).length;

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _back() {
    if (_step == 0 || _step == 3) {
      context.pop();
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _pickPhotos() async {
    if (_photos.length >= 3) { _snack('You can add up to 3 photos'); return; }
    try {
      final files = await ImagePicker().pickMultiImage(imageQuality: 65, maxWidth: 1200);
      for (final f in files) {
        if (_photos.length >= 3) break;
        _photos.add(base64Encode(await f.readAsBytes()));
      }
      if (mounted) setState(() {});
    } catch (_) {
      _snack('Could not add photos');
    }
  }

  bool _validateAbout() {
    if (_headCtrl.text.trim().isEmpty) { _snack('Enter the ad headline'); return false; }
    if (_descCtrl.text.trim().isEmpty) { _snack('Write a short description'); return false; }
    if (_wordCount > 25) { _snack('Description must be 25 words or fewer'); return false; }
    if (_phoneCtrl.text.trim().isEmpty) { _snack('Enter a contact number'); return false; }
    return true;
  }

  Future<void> _payAndPublish() async {
    if (_submitting || _category == null) return;
    setState(() => _submitting = true);

    // Static payment placeholder — real Razorpay wired in later.
    final post = ClassifiedPost(
      id: '', userId: '', userName: '', userPhone: '',
      category: _category!.category,
      subcategory: '',
      title: _headCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      price: 0,
      yearsOfExp: 0,
      pincode: '',
      area: '',
      address: '',
      photos: _photos,
      listingType: 'classified',
      whatsapp: _phoneCtrl.text.trim(),
      amountPaid: _total,
    );

    final result = await ClassifiedService.instance.createPost(post);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result != null) {
      setState(() => _step = 3);
    } else {
      _snack('Could not publish. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 3) return _successScreen();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _back(); },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: _appBar('Create Your Ad'),
        body: Column(
          children: [
            _progressCard(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _step == 0
                    ? _stepCategory()
                    : _step == 1
                        ? _stepAbout()
                        : _stepPreview(),
              ),
            ),
            if (_step != 0) _bottomBar(),
          ],
        ),
      ),
    );
  }

  AppBar _appBar(String title) => AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _blue, size: 20),
          onPressed: _back,
        ),
        title: Text(title,
            style: const TextStyle(color: _blue, fontWeight: FontWeight.w700, fontSize: 18)),
      );

  Widget _progressCard() {
    const titles = ['Choose a category', 'About Your Ad', 'Preview Your Ad'];
    const subs = [
      'Select the most relevant category for your ad',
      'Tell us about your Ad',
      'Review your ad and complete payment',
    ];
    return Container(
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
          Text('Step ${_step + 1}/3',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _blue)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_step + 1) / 3,
              minHeight: 8,
              backgroundColor: const Color(0xFFDCE7F5),
              valueColor: const AlwaysStoppedAnimation(_blue),
            ),
          ),
          const SizedBox(height: 12),
          Text(titles[_step],
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 4),
          Text(subs[_step], style: const TextStyle(fontSize: 13, color: _muted)),
        ],
      ),
    );
  }

  // ── Step 1: category ────────────────────────────────────────────────────────
  Widget _stepCategory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _categoryId,
              hint: const Text('Select your business category',
                  style: TextStyle(color: _muted)),
              items: localClassifiedCategories
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Row(children: [
                          if (c.iconAsset != null)
                            Image.asset(c.iconAsset!, width: 26, height: 26),
                          const SizedBox(width: 10),
                          Text(c.name),
                        ]),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _categoryBanner(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              if (_categoryId == null) { _snack('Please choose a category'); return; }
              setState(() => _step = 1);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _categoryBanner() => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
        decoration: BoxDecoration(color: _banner, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('We Have ${localClassifiedCategories.length}+ Category in Local Classifieds',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: _blue, height: 1.3)),
                  const SizedBox(height: 6),
                  const Text('Find trusted businesses',
                      style: TextStyle(fontSize: 12.5, color: _muted)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Expanded(flex: 4, child: _BannerArt()),
          ],
        ),
      );

  // ── Step 2: about ───────────────────────────────────────────────────────────
  Widget _stepAbout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Head of the Ad'),
        _field(_headCtrl, 'Enter Ad Headline'),
        _label('Write About Your Ad'),
        Container(
          decoration: _boxDeco(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: _descCtrl,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Max 25 Words',
              border: InputBorder.none,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('$_wordCount/25',
                style: TextStyle(
                    fontSize: 12,
                    color: _wordCount > 25 ? Colors.red : _muted)),
          ),
        ),
        _label('Contact Number'),
        _field(_phoneCtrl, 'Enter Mobile Number',
            keyboard: TextInputType.phone,
            formatters: [FilteringTextInputFormatter.digitsOnly]),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('This number will be visible to interested people.',
              style: TextStyle(fontSize: 12, color: _muted)),
        ),
        _label('Upload Photos'),
        _photoPicker(),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Add up to 3 photos', style: TextStyle(fontSize: 12, color: _muted)),
        ),
      ],
    );
  }

  Widget _photoPicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickPhotos,
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFCBD5E1), width: 1.4, style: BorderStyle.solid),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.upload_rounded, color: _muted, size: 28),
                SizedBox(height: 8),
                Text('Tap to Upload or browse',
                    style: TextStyle(color: _muted, fontWeight: FontWeight.w600, fontSize: 13)),
                SizedBox(height: 2),
                Text('Supports: JPG or PNG (Max 50MB)',
                    style: TextStyle(color: _muted, fontSize: 11)),
              ],
            ),
          ),
        ),
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _photos.asMap().entries.map((e) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(base64Decode(e.value),
                          width: 76, height: 76, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: -6, right: -6,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(e.key)),
                        child: const CircleAvatar(
                          radius: 11, backgroundColor: Colors.white,
                          child: Icon(Icons.cancel, color: Colors.redAccent, size: 20)),
                      ),
                    ),
                  ],
                )).toList(),
          ),
        ],
      ],
    );
  }

  // ── Step 3: preview + payment ───────────────────────────────────────────────
  Widget _stepPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _previewCard(),
        const SizedBox(height: 20),
        const Text('Ad Publication Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 10),
        _summaryBox(),
        const SizedBox(height: 20),
        const Text('Payment Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 10),
        _paymentBox(),
        const SizedBox(height: 20),
        const Text('Choose Payment Method',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 10),
        _payMethods(),
      ],
    );
  }

  Widget _previewCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _banner,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _photos.isNotEmpty
                ? Image.memory(base64Decode(_photos.first),
                    width: 84, height: 84, fit: BoxFit.cover)
                : Container(width: 84, height: 84, color: Colors.white,
                    child: const Icon(Icons.image_rounded, color: _blue)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_headCtrl.text.trim().isEmpty ? 'Your ad title' : _headCtrl.text.trim(),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 4),
                Text(_phoneCtrl.text.trim(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _blue)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Text(_category?.name ?? '',
                      style: const TextStyle(fontSize: 11.5, color: _ink, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _banner, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            _summaryCell('Duration', '30 Days'),
            _divider(),
            _summaryCell('Visibility', 'Local'),
            _divider(),
            _summaryCell('Ad Type', 'Classifieds Ad'),
          ],
        ),
      );

  Widget _summaryCell(String k, String v) => Expanded(
        child: Column(
          children: [
            Text(k, style: const TextStyle(fontSize: 11.5, color: _muted)),
            const SizedBox(height: 4),
            Text(v,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
          ],
        ),
      );

  Widget _divider() =>
      Container(width: 1, height: 34, color: Colors.white);

  Widget _paymentBox() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _banner, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            _payRow('Basic Charge (30 Days)', '₹${_baseFee.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _payRow('GST (18%)', '₹${_gst.toStringAsFixed(2)}'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Colors.white),
            ),
            _payRow('Total Amount', '₹${_total.toStringAsFixed(2)}', bold: true),
          ],
        ),
      );

  Widget _payRow(String k, String v, {bool bold = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: TextStyle(
                  fontSize: bold ? 15 : 13.5,
                  color: bold ? _ink : _muted,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          Text(v,
              style: TextStyle(
                  fontSize: bold ? 16 : 14,
                  color: bold ? _blue : _ink,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      );

  Widget _payMethods() {
    Widget tile(String id, String label, IconData icon) {
      final active = _payMethod == id;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _payMethod = id),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? _blue : const Color(0xFFE2E8F0), width: active ? 1.6 : 1),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink)),
                    Icon(active ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 16, color: active ? _blue : const Color(0xFFB0BEC5)),
                  ],
                ),
                const SizedBox(height: 8),
                Icon(icon, size: 20, color: _muted),
              ],
            ),
          ),
        ),
      );
    }

    return Row(children: [
      tile('upi', 'UPI', Icons.account_balance_wallet_rounded),
      tile('cards', 'Cards', Icons.credit_card_rounded),
      tile('netbanking', 'Netbanking', Icons.account_balance_rounded),
    ]);
  }

  // ── Bottom bar (Back + Continue) ────────────────────────────────────────────
  Widget _bottomBar() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _back,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    side: const BorderSide(color: _blue),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : () {
                          if (_step == 1) {
                            if (_validateAbout()) setState(() => _step = 2);
                          } else {
                            _payAndPublish();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : Text(_step == 2 ? 'Continue' : 'Continue',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      );

  // ── Success screen ──────────────────────────────────────────────────────────
  Widget _successScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar('Create Your Ad'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 74, height: 74,
                decoration: const BoxDecoration(color: Color(0xFFE7F7EC), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF1B7A3D), size: 46),
              ),
              const SizedBox(height: 16),
              const Text('Payment Successful!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 6),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(fontSize: 14, color: _ink),
                  children: [
                    TextSpan(text: 'Your Local Classifieds has been '),
                    TextSpan(text: 'Live Now',
                        style: TextStyle(color: _blue, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _previewCard(),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: const Text('Ad Publication Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
              ),
              const SizedBox(height: 10),
              _summaryBox(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.pushReplacement('/classified/list', extra: {
                    'category': _category?.category ?? '',
                    'subcategory': '',
                    'title': _category?.name ?? 'Classifieds',
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Continue',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Small helpers ───────────────────────────────────────────────────────────
  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _ink)),
      );

  BoxDecoration _boxDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      );

  Widget _field(TextEditingController c, String hint,
      {TextInputType? keyboard, List<TextInputFormatter>? formatters}) {
    return Container(
      decoration: _boxDeco(),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        inputFormatters: formatters,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

// Decorative map-pin + emoji cluster for the category banner.
class _BannerArt extends StatelessWidget {
  const _BannerArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: Stack(
        clipBehavior: Clip.none,
        children: const [
          Positioned(
            left: 12, top: 26,
            child: Icon(Icons.location_on, color: Color(0xFFE53935), size: 52),
          ),
          Positioned(right: 4, top: 0, child: _EmojiChip('🏪')),
          Positioned(right: 30, top: 34, child: _EmojiChip('🧺')),
          Positioned(right: 0, top: 62, child: _EmojiChip('🍴')),
          Positioned(left: 6, bottom: 0, child: _EmojiChip('👩')),
          Positioned(left: 44, bottom: 4, child: _EmojiChip('📱')),
        ],
      ),
    );
  }
}

class _EmojiChip extends StatelessWidget {
  final String emoji;
  const _EmojiChip(this.emoji);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36, height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 5)],
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 19)),
    );
  }
}

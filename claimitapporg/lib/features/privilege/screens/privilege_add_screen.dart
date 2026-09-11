import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/location_service.dart';
import '../models/privilege_models.dart';
import '../services/privilege_service.dart';
import '../widgets/privilege_common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// List your own business as a Privilege partner — the + button on the home
// screen.
//
// Submitted as `pending`: it does not appear to other users until an admin
// approves it. Anything else would let anyone publish "50% off" claiming to be
// a hotel they don't own.
//
// Photos are sent as base64 and uploaded to S3 by the backend, matching the
// convention the bill reader and Claimit Select already use.
// ─────────────────────────────────────────────────────────────────────────────

class PrivilegeAddScreen extends StatefulWidget {
  const PrivilegeAddScreen({super.key});

  @override
  State<PrivilegeAddScreen> createState() => _PrivilegeAddScreenState();
}

class _PrivilegeAddScreenState extends State<PrivilegeAddScreen> {
  final _name      = TextEditingController();
  final _about     = TextEditingController();
  final _details   = TextEditingController();
  final _terms     = TextEditingController();
  final _discount  = TextEditingController();
  final _discLabel = TextEditingController();
  final _area      = TextEditingController();
  final _city      = TextEditingController();
  final _pincode   = TextEditingController();
  final _address   = TextEditingController();
  final _phone     = TextEditingController();

  String _category = kPrivilegeCategories.first.id;
  final List<String> _photos = [];   // base64
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _about, _details, _terms, _discount, _discLabel,
                     _area, _city, _pincode, _address, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _photos.add(base64Encode(bytes)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not read that image.');
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Business name is required'); return;
    }
    final disc = double.tryParse(_discount.text.trim());
    if (_discount.text.trim().isNotEmpty && (disc == null || disc < 0 || disc > 100)) {
      setState(() => _error = 'Discount % must be between 0 and 100'); return;
    }
    final pin = _pincode.text.trim();
    if (pin.isNotEmpty && !RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _error = 'Pincode must be 6 digits'); return;
    }
    // Without a position the listing can never appear in the radius search, so
    // it needs either a pincode (the backend resolves it) or a live location.
    if (pin.isEmpty && LocationService.selectedLat == null) {
      setState(() => _error =
          'Enter a 6-digit pincode so people nearby can find you'); return;
    }

    setState(() => _saving = true);
    final res = await PrivilegeService.instance.createOwnPartner({
      'name': _name.text.trim(),
      'category': _category,
      'about': _about.text.trim(),
      'privilege_details': _details.text.trim(),
      'terms': _terms.text.trim(),
      'discount_percent': disc ?? 0,
      'discount_label': _discLabel.text.trim(),
      'area': _area.text.trim(),
      'city': _city.text.trim(),
      'pincode': pin,
      'address': _address.text.trim(),
      'phone': _phone.text.trim(),
      'latitude': LocationService.selectedLat,
      'longitude': LocationService.selectedLng,
      'photos_base64': _photos,
    });
    if (!mounted) return;
    setState(() => _saving = false);

    if (!res.ok) {
      setState(() => _error = res.message);
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(res.message)));
    context.go('/privilege');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrivBg,
      appBar: const PrivilegeHeader(showBack: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          const Text('List your business',
              style: TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w800, color: kPrivInk)),
          const SizedBox(height: 4),
          const Text(
            'Offer a discount to Claimit users. We review every listing before '
            'it goes live.',
            style: TextStyle(fontSize: 13, color: kPrivMuted, height: 1.45),
          ),
          const SizedBox(height: 20),

          _label('Business name *'),
          _field(_name, hint: 'e.g. The Grand Residency'),

          _label('Category *'),
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kPrivLine),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                items: [
                  for (final c in kPrivilegeCategories)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(c.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, color: kPrivInk)),
                    ),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
            ),
          ),

          _label('Discount %'),
          _field(_discount,
              hint: 'e.g. 15', keyboard: TextInputType.number),

          _label('What the discount applies to'),
          _field(_discLabel, hint: 'e.g. Food and Soft Beverages'),

          _label('About'),
          _field(_about, hint: 'A short description of your business', lines: 3),

          _label('Privilege details'),
          _field(_details,
              hint: 'e.g. Get 15% off eligible food at the all-day dining '
                  'restaurant',
              lines: 3),

          _label('Terms & conditions'),
          _field(_terms,
              hint: 'e.g. Inform the billing executive before billing. Cannot '
                  'be combined with other offers.',
              lines: 3),

          const Divider(height: 30),

          _label('Area'),
          _field(_area, hint: 'e.g. Anna Nagar'),

          _label('City'),
          _field(_city, hint: 'e.g. Chennai'),

          _label('Pincode *'),
          _field(_pincode,
              hint: '600040', keyboard: TextInputType.number, maxLength: 6),

          _label('Address'),
          _field(_address, hint: 'Full address', lines: 2),

          _label('Phone'),
          _field(_phone, hint: '10-digit number', keyboard: TextInputType.phone),

          // ── Photos ───────────────────────────────────────────────────
          _label('Photos'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < _photos.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(base64Decode(_photos[i]),
                          width: 74, height: 74, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: InkWell(
                        onTap: () => setState(() => _photos.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_photos.length < 6)
                InkWell(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kPrivLine),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined,
                        size: 22, color: kPrivMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFFC62828))),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrivBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit for review',
                      style: TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: kPrivInk)),
      );

  Widget _field(
    TextEditingController c, {
    String hint = '',
    int lines = 1,
    TextInputType? keyboard,
    int? maxLength,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          maxLines: lines,
          keyboardType: keyboard,
          maxLength: maxLength,
          style: const TextStyle(fontSize: 14, color: kPrivInk),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFFA0AEC0)),
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kPrivLine),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kPrivLine),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kPrivBlue, width: 1.4),
            ),
          ),
        ),
      );
}

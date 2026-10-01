import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/privilege_models.dart';
import '../services/privilege_service.dart';
import '../widgets/privilege_common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen 4 — the eligibility pass, shown at the billing counter.
//
// The customer opens this and hands the phone to the billing executive, who
// checks the offer and taps Verify & Approve. It carries the customer's name
// and number so the executive can see who they are serving, the discount in
// large type, a live countdown, and the reference the shop can quote.
//
// The countdown is real, not decorative: the pass genuinely stops working when
// it hits zero, and the button disables itself at the same moment so nobody
// taps Approve on something the server is about to refuse.
// ─────────────────────────────────────────────────────────────────────────────

class PrivilegePassScreen extends StatefulWidget {
  final PrivilegePass pass;
  const PrivilegePassScreen({super.key, required this.pass});

  @override
  State<PrivilegePassScreen> createState() => _PrivilegePassScreenState();
}

class _PrivilegePassScreenState extends State<PrivilegePassScreen> {
  late int _secondsLeft = widget.pass.secondsLeft;
  Timer? _ticker;
  bool _approving = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _countdown {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _approve() async {
    if (_approving) return;
    setState(() => _approving = true);

    final res = await PrivilegeService.instance.approvePass(widget.pass.reference);
    if (!mounted) return;
    setState(() => _approving = false);

    if (res.pass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'Could not approve.')),
      );
      return;
    }
    // Replaces this screen rather than stacking: going "back" to a pass that
    // has already been approved would invite a second tap.
    context.pushReplacement('/privilege/approved', extra: res.pass);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pass;
    final expired = _secondsLeft <= 0;

    return Scaffold(
      backgroundColor: kPrivBg,
      appBar: const PrivilegeHeader(showBack: true),
      bottomNavigationBar: const PrivilegeBottomBar(current: 2),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
        children: [
          Text(p.partnerName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: kPrivInk)),
          const SizedBox(height: 16),

          // ── Who is claiming ──────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEEF2F7),
                    border: Border.all(color: kPrivLine, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: p.userPhotoUrl.isEmpty
                      ? const Icon(Icons.person_rounded,
                          size: 42, color: kPrivMuted)
                      : CachedNetworkImage(
                          imageUrl: p.userPhotoUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              size: 42, color: kPrivMuted),
                        ),
                ),
                const SizedBox(height: 10),
                Text(p.userName.isEmpty ? 'Claimit user' : p.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kPrivInk)),
                const SizedBox(height: 2),
                Text(p.userPhone,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 14, color: kPrivMuted)),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── The discount, in the size it needs to be read across a counter
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kPrivBlue, Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(p.partnerName.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Colors.white70)),
                const SizedBox(height: 8),
                const Text('ELIGIBLE DISCOUNT',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white70)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${p.percentText}%',
                      style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: kPrivYellow,
                          height: 1.05)),
                ),
                if (p.discountLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(p.discountLabel,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Countdown ────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Text(
                  expired
                      ? 'This pass has expired'
                      : 'Valid for $_countdown minutes',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: expired ? const Color(0xFFB91C1C) : kPrivBlue),
                ),
                const SizedBox(height: 2),
                Text(
                  expired
                      ? 'Go back and open it again at the counter'
                      : 'Keep this open at the billing counter',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: kPrivMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _row('Issued', _pretty(p.issuedAt)),
          const SizedBox(height: 4),
          _row('Transaction Reference', p.reference),
          const SizedBox(height: 16),

          // ── Instruction to the executive ─────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('For Billing Executive',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5D4037))),
                SizedBox(height: 2),
                Text('Check the offer details above, then approve below.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF6D4C41))),
              ],
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (expired || _approving) ? null : _approve,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrivBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF90A4AE),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _approving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(expired ? 'Pass expired' : 'Verify & Approve Discount',
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12.5, color: kPrivMuted)),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kPrivInk)),
          ),
        ],
      );

  /// "2026-09-02T11:42:00+05:30" -> "02 Sep 2026 – 11:42 AM".
  /// Falls back to the raw string rather than throwing on an odd value.
  static String _pretty(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final h24 = d.hour;
      final h = h24 % 12 == 0 ? 12 : h24 % 12;
      final ampm = h24 < 12 ? 'AM' : 'PM';
      final mm = d.minute.toString().padLeft(2, '0');
      return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} '
             '${d.year} – $h:$mm $ampm';
    } catch (_) {
      return iso;
    }
  }
}

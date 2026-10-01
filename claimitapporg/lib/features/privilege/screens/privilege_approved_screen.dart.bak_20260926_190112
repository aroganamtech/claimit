import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/privilege_models.dart';
import '../widgets/privilege_common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen 5 — discount approved.
//
// Deliberately NO "Scan Final Bill" button. The mockup had one, but Ramesh's
// instruction was "here dont need scan bill but show histry" — so this screen
// ends the journey and points at the history instead. Reward/Redeem Zone is
// where bill scanning lives; mixing the two here would ask the user to do a
// second, unrelated thing at the moment they are trying to pay.
// ─────────────────────────────────────────────────────────────────────────────

class PrivilegeApprovedScreen extends StatelessWidget {
  final PrivilegePass pass;
  const PrivilegeApprovedScreen({super.key, required this.pass});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrivBg,
      appBar: const PrivilegeHeader(),
      bottomNavigationBar: const PrivilegeBottomBar(current: 2),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 26),
        children: [
          const Center(
            child: Icon(Icons.check_circle_rounded, size: 92, color: kPrivGreen),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text('Discount Approved',
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: kPrivGreen)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Approved at ${PrivilegeTime.pretty(pass.approvedAt)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kPrivMuted),
            ),
          ),
          const SizedBox(height: 22),

          // ── What was approved ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Column(
              children: [
                Text(pass.partnerName.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Color(0xFF6D4C41))),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${pass.percentText}% OFF',
                      style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF5D4037),
                          height: 1.1)),
                ),
                if (pass.discountLabel.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(pass.discountLabel,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF6D4C41))),
                ],
                const SizedBox(height: 10),
                Text('Ref : ${pass.reference}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5D4037))),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── What the executive does next ─────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF90CAF9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Billing Executive',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D47A1))),
                const SizedBox(height: 3),
                Text(
                  'Please apply the ${pass.percentText}% discount to eligible '
                  'items before generating the final bill.',
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF1565C0), height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => context.go('/privilege/history'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrivBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('View My Privileges',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: TextButton(
              onPressed: () => context.go('/privilege'),
              child: const Text('Back to Privilege',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kPrivBlue)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared date formatting, so no two screens render the same timestamp in two
/// different ways.
class PrivilegeTime {
  static String pretty(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final h24 = d.hour;
      final h = h24 % 12 == 0 ? 12 : h24 % 12;
      final ampm = h24 < 12 ? 'AM' : 'PM';
      final mm = d.minute.toString().padLeft(2, '0');
      return '$h:$mm $ampm, ${d.day.toString().padLeft(2, '0')} '
             '${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

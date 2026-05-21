import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'shop_list_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RedeemEligibilityScreen
// Shown after the loading screen confirms eligibility.
// Screenshot: blue circle ✓ → "I am eligible for the Redeem of X% Discount
// on my bill today at" → shop card → "Scan Bill" CTA
// ─────────────────────────────────────────────────────────────────────────────

class RedeemEligibilityScreen extends StatefulWidget {
  final ShopItem shop;
  final bool eligible;
  final int discount;
  final String message;

  const RedeemEligibilityScreen({
    super.key,
    required this.shop,
    required this.eligible,
    required this.discount,
    required this.message,
  });

  @override
  State<RedeemEligibilityScreen> createState() =>
      _RedeemEligibilityScreenState();
}

class _RedeemEligibilityScreenState extends State<RedeemEligibilityScreen>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF1565C0);

  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _scaleCtrl.forward();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shop;
    final eligible = widget.eligible;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _blue, size: 20),
        ),
        title: Row(
          children: [
            Image.asset('assets/icons/main_icon.png', width: 28, height: 28,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            const SizedBox(width: 6),
            const Text('claimit',
                style: TextStyle(
                    color: _blue, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Icon(Icons.notifications_none_rounded,
                color: _blue, size: 24),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 40),

            // ── Animated circle icon ───────────────────────────────────────
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: eligible
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  eligible ? Icons.check_rounded : Icons.close_rounded,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Eligibility message ────────────────────────────────────────
            if (eligible) ...[
              const Text(
                'I am eligible for the',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A)),
                  children: [
                    const TextSpan(text: 'Redeem of '),
                    TextSpan(
                      text: '${widget.discount}% Discount',
                      style: const TextStyle(color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'on my bill today at',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A)),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Text(
                'Not eligible right now',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A)),
                textAlign: TextAlign.center,
              ),
              if (widget.message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.message,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF6B7280)),
                  textAlign: TextAlign.center,
                ),
              ],
            ],

            const SizedBox(height: 24),

            // ── Shop card ──────────────────────────────────────────────────
            _ShopCard(shop: s, discount: widget.discount),

            const Spacer(),

            // ── CTA buttons ────────────────────────────────────────────────
            if (eligible) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.push('/bill-reader/scanner'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: const Text('Scan Bill',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => context.go('/home'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Back to Home',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final ShopItem shop;
  final int discount;
  const _ShopCard({required this.shop, required this.discount});

  @override
  Widget build(BuildContext context) {
    final s = shop;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72,
              height: 72,
              child: s.imageData != null && s.imageData!.isNotEmpty
                  ? Image.memory(
                      base64Decode(s.imageData!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(s),
                    )
                  : _fallback(s),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1A1A1A))),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 12, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 3),
                    Text(s.location,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '$discount% Offer On Products',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(ShopItem s) => Container(
        color: s.fallbackColor,
        alignment: Alignment.center,
        child: Icon(s.fallbackIcon, color: Colors.grey.shade400, size: 30),
      );
}

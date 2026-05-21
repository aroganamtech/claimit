import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/location_service.dart';
import '../services/shop_service.dart';
import 'shop_list_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RedeemLoadingScreen
// Shows 3 sequential check steps, then navigates to the eligibility screen.
// Mimics screenshot: spinning loader → step reveals → shop card preview
// ─────────────────────────────────────────────────────────────────────────────

class RedeemLoadingScreen extends StatefulWidget {
  final ShopItem shop;
  const RedeemLoadingScreen({super.key, required this.shop});

  @override
  State<RedeemLoadingScreen> createState() => _RedeemLoadingScreenState();
}

class _RedeemLoadingScreenState extends State<RedeemLoadingScreen>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF1565C0);

  late AnimationController _spinCtrl;
  int _doneSteps = 0; // 0 = none, 1,2,3 = steps done
  bool _finished = false;

  final List<String> _steps = [
    'Locating your location',
    'Verifying Your points',
    'Checking Discount Offers',
  ];

  Position? _position;
  bool _eligible = false;
  int _discount = 0;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _runChecks();
  }

  Future<void> _runChecks() async {
    // Step 1 — locate
    // LocationService handles: service-off dialog, deniedForever settings
    // dialog, 10 s timeout, and getLastKnownPosition fallback automatically.
    _position = await LocationService.getPosition(
      context: mounted ? context : null,
    );
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _doneSteps = 1);

    // Step 2 — verify points (small delay simulates server round-trip)
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _doneSteps = 2);

    // Step 3 — check discount eligibility via backend
    final result = await ShopService.instance.checkRedeemEligibility(
      shopId: widget.shop.id,
      lat: _position?.latitude,
      lng: _position?.longitude,
    );
    _eligible = result.eligible;
    _discount = result.discount > 0 ? result.discount : widget.shop.discount;
    _message  = result.message;

    if (!mounted) return;
    setState(() { _doneSteps = 3; _finished = true; });
    _spinCtrl.stop();

    // Brief pause so the user sees all 3 checks complete, then push
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    context.pushReplacement(
      '/redeem-eligibility',
      extra: {
        'shop': widget.shop,
        'eligible': _eligible,
        'discount': _discount,
        'message': _message,
      },
    );
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shop;
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // ── Spinner ────────────────────────────────────────────────────
            Center(
              child: _finished
                  ? const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF4CAF50), size: 64)
                  : RotationTransition(
                      turns: _spinCtrl,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _blue,
                            width: 4,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: const BoxDecoration(
                              color: _blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 40),

            // ── Check steps ────────────────────────────────────────────────
            ..._steps.asMap().entries.map((e) {
              final idx  = e.key;
              final text = e.value;
              final done = _doneSteps > idx;
              final active = _doneSteps == idx && !_finished;

              return AnimatedOpacity(
                opacity: _doneSteps >= idx ? 1.0 : 0.35,
                duration: const Duration(milliseconds: 400),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    children: [
                      // Icon
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: done
                            ? const Icon(Icons.check_rounded,
                                key: ValueKey('done'),
                                color: Color(0xFF4CAF50),
                                size: 22)
                            : active
                                ? SizedBox(
                                    key: const ValueKey('spin'),
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: _blue,
                                    ),
                                  )
                                : const Icon(Icons.remove_rounded,
                                    key: ValueKey('idle'),
                                    color: Color(0xFFBDBDBD),
                                    size: 22),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 15,
                          color: done
                              ? const Color(0xFF1A1A1A)
                              : active
                                  ? _blue
                                  : const Color(0xFF9E9E9E),
                          fontWeight: done || active
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // ── Shop preview card (appears after step 3 visible) ───────────
            if (_doneSteps >= 3)
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 400),
                child: _ShopPreviewCard(shop: s),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Small shop card preview ───────────────────────────────────────────────────
class _ShopPreviewCard extends StatelessWidget {
  final ShopItem shop;
  const _ShopPreviewCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 70,
              height: 70,
              child: shop.imageData != null && shop.imageData!.isNotEmpty
                  ? Image.memory(
                      base64Decode(shop.imageData!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(shop),
                    )
                  : _fallback(shop),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shop.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1A1A1A))),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 11, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 2),
                    Text(shop.location,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${shop.discount}% Offer On Products',
                  style: const TextStyle(
                      fontSize: 12,
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
        child: Icon(s.fallbackIcon, color: Colors.grey.shade400, size: 28),
      );
}

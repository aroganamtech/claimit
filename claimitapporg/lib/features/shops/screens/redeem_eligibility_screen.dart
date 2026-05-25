// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'shop_list_screen.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// // RedeemEligibilityScreen
// // Shown after the loading screen confirms eligibility.
// // Screenshot: blue circle ✓ → "I am eligible for the Redeem of X% Discount
// // on my bill today at" → shop card → "Scan Bill" CTA
// // ─────────────────────────────────────────────────────────────────────────────

// class RedeemEligibilityScreen extends StatefulWidget {
//   final ShopItem shop;
//   final bool eligible;
//   final int discount;
//   final String message;

//   const RedeemEligibilityScreen({
//     super.key,
//     required this.shop,
//     required this.eligible,
//     required this.discount,
//     required this.message,
//   });

//   @override
//   State<RedeemEligibilityScreen> createState() =>
//       _RedeemEligibilityScreenState();
// }

// class _RedeemEligibilityScreenState extends State<RedeemEligibilityScreen>
//     with SingleTickerProviderStateMixin {
//   static const _blue = Color(0xFF1565C0);

//   late AnimationController _scaleCtrl;
//   late Animation<double> _scaleAnim;

//   @override
//   void initState() {
//     super.initState();
//     _scaleCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 700),
//     );
//     _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
//     _scaleCtrl.forward();
//   }

//   @override
//   void dispose() {
//     _scaleCtrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = widget.shop;
//     final eligible = widget.eligible;

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0.5,
//         shadowColor: Colors.black12,
//         surfaceTintColor: Colors.transparent,
//         leading: GestureDetector(
//           onTap: () => context.pop(),
//           child: const Icon(Icons.arrow_back_ios_new_rounded,
//               color: _blue, size: 20),
//         ),
//         title: Row(
//           children: [
//             Image.asset('assets/icons/main_icon.png', width: 28, height: 28,
//                 errorBuilder: (_, __, ___) => const SizedBox.shrink()),
//             const SizedBox(width: 6),
//             const Text('claimit',
//                 style: TextStyle(
//                     color: _blue, fontWeight: FontWeight.bold, fontSize: 18)),
//           ],
//         ),
//         actions: const [
//           Padding(
//             padding: EdgeInsets.only(right: 14),
//             child: Icon(Icons.notifications_none_rounded,
//                 color: _blue, size: 24),
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 24),
//         child: Column(
//           children: [
//             const SizedBox(height: 40),

//             // ── Animated circle icon ───────────────────────────────────────
//             ScaleTransition(
//               scale: _scaleAnim,
//               child: Container(
//                 width: 110,
//                 height: 110,
//                 decoration: BoxDecoration(
//                   color: eligible
//                       ? const Color(0xFF2563EB)
//                       : const Color(0xFFEF4444),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(
//                   eligible ? Icons.check_rounded : Icons.close_rounded,
//                   color: Colors.white,
//                   size: 60,
//                 ),
//               ),
//             ),

//             const SizedBox(height: 28),

//             // ── Eligibility message ────────────────────────────────────────
//             if (eligible) ...[
//               const Text(
//                 'I am eligible for the',
//                 style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Color(0xFF1A1A1A)),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 4),
//               RichText(
//                 textAlign: TextAlign.center,
//                 text: TextSpan(
//                   style: const TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: Color(0xFF1A1A1A)),
//                   children: [
//                     const TextSpan(text: 'Redeem of '),
//                     TextSpan(
//                       text: '${widget.discount}% Discount',
//                       style: const TextStyle(color: Color(0xFF2563EB)),
//                     ),
//                     const TextSpan(text: ' + '),
//                     const TextSpan(
//                       text: '1% Cashback',
//                       style: TextStyle(color: Color(0xFF059669)),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 4),
//               const Text(
//                 'on my bill today at',
//                 style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Color(0xFF1A1A1A)),
//                 textAlign: TextAlign.center,
//               ),
//             ] else ...[
//               const Text(
//                 'Not eligible right now',
//                 style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Color(0xFF1A1A1A)),
//                 textAlign: TextAlign.center,
//               ),
//               if (widget.message.isNotEmpty) ...[
//                 const SizedBox(height: 8),
//                 Text(
//                   widget.message,
//                   style: const TextStyle(
//                       fontSize: 14, color: Color(0xFF6B7280)),
//                   textAlign: TextAlign.center,
//                 ),
//               ],
//             ],

//             const SizedBox(height: 24),

//             // ── Shop card ──────────────────────────────────────────────────
//             _ShopCard(shop: s, discount: widget.discount),

//             const Spacer(),

//             // ── CTA buttons ────────────────────────────────────────────────
//             if (eligible) ...[
//               SizedBox(
//                 width: double.infinity,
//                 height: 52,
//                 child: ElevatedButton(
//                   onPressed: () => context.push('/bill-reader/scanner'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: _blue,
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(30)),
//                     elevation: 0,
//                   ),
//                   child: const Text('Scan Bill',
//                       style: TextStyle(
//                           fontSize: 17, fontWeight: FontWeight.bold)),
//                 ),
//               ),
//               const SizedBox(height: 12),
//             ],
//             SizedBox(
//               width: double.infinity,
//               height: 48,
//               child: OutlinedButton(
//                 onPressed: () => context.go('/home'),
//                 style: OutlinedButton.styleFrom(
//                   foregroundColor: _blue,
//                   side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(30)),
//                 ),
//                 child: const Text('Back to Home',
//                     style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
//               ),
//             ),
//             const SizedBox(height: 32),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _ShopCard extends StatelessWidget {
//   final ShopItem shop;
//   final int discount;
//   const _ShopCard({required this.shop, required this.discount});

//   @override
//   Widget build(BuildContext context) {
//     final s = shop;
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xFFE5E7EB)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.06),
//             blurRadius: 12,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           ClipRRect(
//             borderRadius: BorderRadius.circular(10),
//             child: SizedBox(
//               width: 72,
//               height: 72,
//               child: s.imageData != null && s.imageData!.isNotEmpty
//                   ? Image.memory(
//                       base64Decode(s.imageData!),
//                       fit: BoxFit.cover,
//                       errorBuilder: (_, __, ___) => _fallback(s),
//                     )
//                   : _fallback(s),
//             ),
//           ),
//           const SizedBox(width: 14),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(s.name,
//                     style: const TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                         color: Color(0xFF1A1A1A))),
//                 const SizedBox(height: 3),
//                 Row(
//                   children: [
//                     const Icon(Icons.location_on_rounded,
//                         size: 28, color: Color(0xFF9CA3AF)),
//                     const SizedBox(width: 3),
//                     Text(s.location,
//                         style: const TextStyle(
//                             fontSize: 12, color: Color(0xFF6B7280))),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Wrap(
//                   spacing: 6,
//                   children: [
//                     _OfferTag(
//                       label: '$discount% Discount',
//                       bg: const Color(0xFFFFF7ED),
//                       border: const Color(0xFFFB923C),
//                       fg: const Color(0xFFC2410C),
//                     ),
//                     const _OfferTag(
//                       label: '+ 1% Cashback',
//                       bg: Color(0xFFECFDF5),
//                       border: Color(0xFF6EE7B7),
//                       fg: Color(0xFF065F46),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _fallback(ShopItem s) => Container(
//         color: s.fallbackColor,
//         alignment: Alignment.center,
//         child: Icon(s.fallbackIcon, color: Colors.grey.shade400, size: 30),
//       );
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Small offer tag pill
// // ─────────────────────────────────────────────────────────────────────────────
// class _OfferTag extends StatelessWidget {
//   final String label;
//   final Color bg;
//   final Color border;
//   final Color fg;
//   const _OfferTag({
//     required this.label,
//     required this.bg,
//     required this.border,
//     required this.fg,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
//       decoration: BoxDecoration(
//         color: bg,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: border.withOpacity(0.6)),
//       ),
//       child: Text(
//         label,
//         style: TextStyle(
//           fontSize: 11,
//           fontWeight: FontWeight.w600,
//           color: fg,
//         ),
//       ),
//     );
//   }
// }
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'shop_list_screen.dart';

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
    with TickerProviderStateMixin {
  static const _blue = Color(0xFF1565C0);

  // Entrance Controllers
  late AnimationController _entranceCtrl;
  
  // Staggered components
  late Animation<double> _iconScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _cardScale;
  late Animation<Offset> _cardSlide;

  // Continuous loop engine for attention-grabbing background elements
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    // 1. Entrance timeline controller
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Big green/blue status circle entry pop
    _iconScale = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );

    // Headline slide + fade sequence
    _textFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.3, 0.7, curve: Curves.easeIn),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutBack), // Fixed curve name
    ));

    // Lower merchant details card sliding pop up
    _cardScale = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutBack), // Fixed curve name
    ));

    // 2. Loop dynamic values (Subtle persistent organic pulsing and glowing)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _glowAnim = Tween<double>(begin: 4.0, end: 16.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Run sequences
    _entranceCtrl.forward().then((_) {
      _pulseCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
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
        // title: Image.asset(
        //   'assets/images/main_logo1.png', 
        //   height: 32,
        //   fit: BoxFit.contain,
        //   errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        // ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Icon(Icons.notifications_none_rounded,
                color: _blue, size: 24),
          ),
        ],
      ),
      // Wrap in SingleChildScrollView so content never overflows on small phones.
      body: SafeArea(
        top: false,          // AppBar already handles top inset
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            // Minimum height = full visible screen so the Spacer-equivalent
            // (SizedBox below) still pushes the CTA to the bottom on large phones.
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  kToolbarHeight -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 24),

            // ── Premium Floating Status Badge ────────────────────────────────
            ScaleTransition(
              scale: _iconScale,
              child: AnimatedBuilder(
                animation: _glowAnim,
                builder: (context, child) {
                  return Container(
                    width: 115,
                    height: 115,
                    decoration: BoxDecoration(
                      color: eligible ? const Color(0xFF2563EB) : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (eligible ? const Color(0xFF2563EB) : const Color(0xFFEF4444)).withOpacity(0.25),
                          blurRadius: _glowAnim.value * 1.5,
                          spreadRadius: _glowAnim.value * 0.3,
                        )
                      ],
                    ),
                    child: child,
                  );
                },
                child: Icon(
                  eligible ? Icons.check_rounded : Icons.close_rounded,
                  color: Colors.white,
                  size: 65,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Dynamic Text & Reward Visual Block ──────────────────────────
            if (eligible) ...[
              FadeTransition(
                opacity: _textFade,
                child: SlideTransition(
                  position: _textSlide,
                  child: Column(
                    children: [
                      const Text(
                        'I AM ELIGIBLE FOR THE',
                        style: TextStyle(
                            fontSize: 14,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF9CA3AF)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      
                      // Elastic pop interactive promo container box
                      ScaleTransition(
                        scale: _entranceCtrl.isAnimating ? _textFade : _pulseAnim,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              // Massive clear typography layouts
                              // FittedBox ensures this never overflows on narrow screens
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${widget.discount}% DISCOUNT',
                                  style: const TextStyle(
                                    fontSize: 32,        // reduced from 38
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2563EB),
                                    letterSpacing: -1.0,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(width: 32, height: 1.5, color: const Color(0xFFCBD5E1)), // Fixed typo
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'PLUS',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.0),
                                    ),
                                  ),
                                  Container(width: 32, height: 1.5, color: const Color(0xFFCBD5E1)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '1% CASHBACK',
                                  style: TextStyle(
                                    fontSize: 26,          // reduced from 32
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF059669),
                                    letterSpacing: -0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 18),
                      // const Text(
                      //   'on my bill today at',
                      //   style: TextStyle(
                      //       fontSize: 18,
                      //       fontWeight: FontWeight.w500,
                      //       color: Color(0xFF6B7280)),
                      //   textAlign: TextAlign.center,
                      // ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              FadeTransition(
                opacity: _textFade,
                child: const Text(
                  'Not eligible right now',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A)),
                  textAlign: TextAlign.center,
                ),
              ),
              if (widget.message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.message,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  textAlign: TextAlign.center,
                ),
              ],
            ],

            const SizedBox(height: 24),

            // ── Merchant Info Profile Card Sequence ─────────────────────────
            FadeTransition(
              opacity: _cardScale,
              child: SlideTransition(
                position: _cardSlide,
                child: ScaleTransition(
                  scale: _cardScale,
                  child: _ShopCard(shop: s, discount: widget.discount),
                ),
              ),
            ),

            // Spacer equivalent — pushes CTA to bottom on large screens,
            // collapses to minimum on small screens (works with IntrinsicHeight).
            const Expanded(child: SizedBox(height: 24)),

            // ── Functional Navigation Layout Call to Actions ────────────────
            if (eligible) ...[
              FadeTransition(
                opacity: _cardScale,
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => context.push('/bill-reader/scanner'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 3,
                      shadowColor: _blue.withOpacity(0.4),
                    ),
                    child: const Text('Scan Bill',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FadeTransition(
              opacity: _cardScale,
              child: SizedBox(
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
            ),
            const SizedBox(height: 32),
          ],
        ),       // Column
      ),         // IntrinsicHeight
      ),         // ConstrainedBox
        ),       // SingleChildScrollView padding
      ),         // SafeArea
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 74,
              height: 74,
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 15, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(s.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280))),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _OfferTag(
                      label: '$discount% Discount',
                      bg: const Color(0xFFFFF7ED),
                      border: const Color(0xFFFB923C),
                      fg: const Color(0xFFC2410C),
                    ),
                    _OfferTag(
                      label: '+ 1% Cashback',
                      bg: const Color(0xFFECFDF5),
                      border: const Color(0xFF6EE7B7),
                      fg: const Color(0xFF065F46),
                    ),
                  ],
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

class _OfferTag extends StatelessWidget {
  final String label;
  final Color bg;
  final Color border;
  final Color fg;
  const _OfferTag({
    required this.label,
    required this.bg,
    required this.border,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
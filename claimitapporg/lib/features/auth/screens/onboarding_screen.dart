// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';

// class OnboardingScreen extends StatefulWidget {
//   const OnboardingScreen({super.key});

//   @override
//   State<OnboardingScreen> createState() => _OnboardingScreenState();
// }

// class _OnboardingScreenState extends State<OnboardingScreen> {
//   final PageController _pageController = PageController();
//   int _currentPage = 0;

//   final List<_OnboardingSlide> _slides = const [
//     _OnboardingSlide(
//       title: 'Shop IT',
//       description:
//           'Shop at Claimit-affiliated Reward Zones\nand earn Free Redeemable Reward Points\nplus 1% Cashback on every purchase.',
//       illustrationIcon: Icons.shopping_bag_outlined,
//       badgeIcon: Icons.star_rounded,
//     ),
//     _OnboardingSlide(
//       title: 'Scan IT',
//       description:
//           'Scan your bill with the Claimit App to\ninstantly receive Redeemable Reward\nPoints and 1% Cashback in your wallet.',
//       illustrationIcon: Icons.document_scanner_outlined,
//       badgeIcon: Icons.receipt_long_outlined,
//     ),
//     _OnboardingSlide(
//       title: 'Earn IT',
//       description:
//           'At Claimit-affiliated Redeem Zones,\nscan your bill to enjoy Rewards as Discounts\nplus 1% Cashback on every purchase.',
//       illustrationIcon: Icons.workspace_premium_outlined,
//       badgeIcon: Icons.star_border_outlined,
//     ),
//   ];

//   void _onNext() {
//     if (_currentPage < _slides.length - 1) {
//       _pageController.nextPage(
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeInOut,
//       );
//     } else {
//       context.go('/auth/register');
//     }
//   }

//   void _onBack() {
//     _pageController.previousPage(
//       duration: const Duration(milliseconds: 300),
//       curve: Curves.easeInOut,
//     );
//   }

//   @override
//   void dispose() {
//     _pageController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Stack(
//         children: [
//           Positioned(
//             top: -size.height * 0.04,
//             right: -size.width * 0.10,
//             child: Opacity(
//               opacity: 0.50,
//               child: Image.asset(
//                 'assets/images/watermark_c.png',
//                 width: size.width * 0.65,
//                 fit: BoxFit.contain,
//                 errorBuilder: (_, __, ___) => const SizedBox.shrink(),
//               ),
//             ),
//           ),
//           Positioned(
//             bottom: -size.height * 0.02,
//             left: -size.width * 0.10,
//             child: Transform.rotate(
//               angle: -0.15,
//               child: Opacity(
//                 opacity: 0.40,
//                 child: Image.asset(
//                   'assets/images/watermark_c.png',
//                   width: size.width * 0.58,
//                   fit: BoxFit.contain,
//                   errorBuilder: (_, __, ___) => const SizedBox.shrink(),
//                 ),
//               ),
//             ),
//           ),
//           SafeArea(
//             child: Column(
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 20,
//                     vertical: 12,
//                   ),
//                   child: Row(
//                     children: [
//                       if (_currentPage > 0)
//                         GestureDetector(
//                           onTap: _onBack,
//                           child: const Icon(
//                             Icons.arrow_back_ios_new_rounded,
//                             size: 22,
//                             color: Color(0xFF1E3A8A),
//                           ),
//                         )
//                       else
//                         const SizedBox(width: 22),
//                       Expanded(child: Center(child: _ClaimitLogo())),
//                       GestureDetector(
//                         onTap: () => context.go('/auth/register'),
//                         child: const Text(
//                           'Skip',
//                           style: TextStyle(
//                             fontSize: 15,
//                             color: Color(0xFF1E3A8A),
//                             fontWeight: FontWeight.w500,
//                             decoration: TextDecoration.underline,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Expanded(
//                   child: PageView.builder(
//                     controller: _pageController,
//                     onPageChanged: (i) => setState(() => _currentPage = i),
//                     itemCount: _slides.length,
//                     itemBuilder: (context, index) =>
//                         _SlideContent(slide: _slides[index]),
//                   ),
//                 ),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: List.generate(_slides.length, (i) {
//                     final active = i == _currentPage;
//                     return AnimatedContainer(
//                       duration: const Duration(milliseconds: 300),
//                       margin: const EdgeInsets.symmetric(horizontal: 4),
//                       width: active ? 10 : 8,
//                       height: active ? 10 : 8,
//                       decoration: BoxDecoration(
//                         color: active
//                             ? const Color(0xFF2563EB)
//                             : const Color(0xFFCBD5E1),
//                         shape: BoxShape.circle,
//                       ),
//                     );
//                   }),
//                 ),
//                 const SizedBox(height: 28),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 32),
//                   child: SizedBox(
//                     width: double.infinity,
//                     height: 52,
//                     child: ElevatedButton(
//                       onPressed: _onNext,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF2563EB),
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(30),
//                         ),
//                         elevation: 0,
//                       ),
//                       child: Text(
//                         _currentPage < _slides.length - 1
//                             ? 'Next'
//                             : 'Get Started',
//                         style: const TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 36),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _ClaimitLogo extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           width: 36,
//           height: 36,
//           decoration: const BoxDecoration(
//             shape: BoxShape.circle,
//             gradient: LinearGradient(
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//               colors: [Color(0xFFFFD93D), Color(0xFFF59E0B)],
//             ),
//           ),
//           child: Stack(
//             alignment: Alignment.center,
//             children: [
//               const Text(
//                 'c',
//                 style: TextStyle(
//                   fontSize: 20,
//                   color: Colors.white,
//                   fontWeight: FontWeight.w300,
//                   height: 1,
//                 ),
//               ),
//               Positioned(
//                 top: 5,
//                 right: 5,
//                 child: Icon(
//                   Icons.star_rounded,
//                   color: Colors.white.withOpacity(0.9),
//                   size: 8,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(width: 6),
//         const Text(
//           'claimit',
//           style: TextStyle(
//             fontSize: 22,
//             fontWeight: FontWeight.bold,
//             color: Color(0xFF2563EB),
//             letterSpacing: 0.5,
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _SlideContent extends StatelessWidget {
//   final _OnboardingSlide slide;
//   const _SlideContent({required this.slide});

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 28),
//       child: Column(
//         children: [
//           const SizedBox(height: 8),
//           Container(
//             width: double.infinity,
//             height: size.height * 0.30,
//             decoration: BoxDecoration(
//               color: const Color(0xFFDCECFB),
//               borderRadius: BorderRadius.circular(24),
//             ),
//             child: Stack(
//               alignment: Alignment.center,
//               children: [
//                 Column(
//                   mainAxisAlignment: MainAxisAlignment.end,
//                   children: [
//                     Container(
//                       width: 44,
//                       height: 44,
//                       decoration: const BoxDecoration(
//                         color: Color(0xFFFFCBA4),
//                         shape: BoxShape.circle,
//                       ),
//                     ),
//                     Container(
//                       width: 80,
//                       height: 90,
//                       decoration: const BoxDecoration(
//                         color: Color(0xFFFFD93D),
//                         borderRadius: BorderRadius.only(
//                           topLeft: Radius.circular(40),
//                           topRight: Radius.circular(40),
//                         ),
//                       ),
//                       child: Center(
//                         child: Icon(
//                           slide.illustrationIcon,
//                           color: Colors.white,
//                           size: 34,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 Positioned(
//                   top: 18,
//                   right: 24,
//                   child: Container(
//                     width: 54,
//                     height: 54,
//                     decoration: const BoxDecoration(
//                       color: Color(0xFFFFD93D),
//                       shape: BoxShape.circle,
//                     ),
//                     child: Icon(slide.badgeIcon, color: Colors.white, size: 30),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 32),
//           Text(
//             slide.title,
//             style: const TextStyle(
//               fontSize: 26,
//               fontWeight: FontWeight.bold,
//               color: Color(0xFF1E3A8A),
//             ),
//           ),
//           const SizedBox(height: 16),
//           Text(
//             slide.description,
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               fontSize: 14,
//               color: Color(0xFF4B5563),
//               height: 1.65,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _OnboardingSlide {
//   final String title;
//   final String description;
//   final IconData illustrationIcon;
//   final IconData badgeIcon;

//   const _OnboardingSlide({
//     required this.title,
//     required this.description,
//     required this.illustrationIcon,
//     required this.badgeIcon,
//   });
// }
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 1. Updated the slide data to take image paths instead of icons
  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      title: 'SHOP',
      description:
          'Shop at Claimit affiliates to earn\n100% Reward Points plus 1% Cashback\non your daily purchases.',
      imageAsset: 'assets/images/onb1.png',
    ),
    _OnboardingSlide(
      title: 'SCAN',
      description:
          'Scan your paper bill in the app\nto instantly collect your points and cash\ndirectly into your digital wallets.',
      imageAsset: 'assets/images/onb2.png',
    ),
    _OnboardingSlide(
      title: 'ENJOY',
      description:
          'Enjoy Exclusive, Unbeatable Discounts\n+1% extra Cashback by using your reward\npoints at nearby affiliated businesses.',
      imageAsset: 'assets/images/onb3.png',
    ),
  ];

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/auth/register');
    }
  }

  void _onBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -size.height * 0.04,
            right: -size.width * 0.10,
            child: Opacity(
              opacity: 0.50,
              child: Image.asset(
                'assets/images/watermark_c.png',
                width: size.width * 0.65,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.02,
            left: -size.width * 0.10,
            child: Transform.rotate(
              angle: -0.15,
              child: Opacity(
                opacity: 0.40,
                child: Image.asset(
                  'assets/images/watermark_c.png',
                  width: size.width * 0.58,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 12),
                  child: Row(
                    children: [
                      if (_currentPage > 0)
                        GestureDetector(
                          onTap: _onBack,
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 26,
                            color: Color(0xFF1E3A8A),
                          ),
                        )
                      else
                        const SizedBox(width: 22),
                      Expanded(child: Center(child: _ClaimitLogo())),
                      GestureDetector(
                        onTap: () => context.go('/auth/register'),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1E3A8A),
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _slides.length,
                    itemBuilder: (context, index) =>
                        _SlideContent(slide: _slides[index]),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 10 : 8,
                      height: active ? 10 : 8,
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFCBD5E1),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage < _slides.length - 1
                            ? 'Next'
                            : 'Get Started',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimitLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/home_main_logo.png',
      height: 38,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Text(
        'claimit',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2563EB),
        ),
      ),
      
    );
  }
}

class _SlideContent extends StatelessWidget {
  final _OnboardingSlide slide;
  const _SlideContent({required this.slide});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SingleChildScrollView(
      child: SizedBox(
        width: size.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: size.height * 0.10),

            // Image — centered with explicit width so it never drifts
            Center(
              child: SizedBox(
                width: size.width * 0.85,
                height: size.height * 0.35,
                child: Image.asset(
                  slide.imageAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.image_not_supported_outlined,
                    size: 64,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ),

            SizedBox(height: size.height * 0.03),

            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                slide.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4B5563),
                  height: 1.65,
                ),
              ),
            ),
            SizedBox(height: size.height * 0.05),
          ],
        ),
      ),
    );
  }
}

// 3. Updated data model to use imageAsset instead of icons
class _OnboardingSlide {
  final String title;
  final String description;
  final String imageAsset;

  const _OnboardingSlide({
    required this.title,
    required this.description,
    required this.imageAsset,
  });
}
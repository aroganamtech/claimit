// // // import 'package:flutter/material.dart';
// // // import 'package:go_router/go_router.dart';
// // // import '../../../core/theme/app_theme.dart';

// // // /// The persistent shell that wraps every main tab.
// // // class HomeScreen extends StatelessWidget {
// // //   final Widget child;
// // //   const HomeScreen({super.key, required this.child});

// // //   int _selectedIndex(BuildContext context) {
// // //     final loc = GoRouterState.of(context).matchedLocation;
// // //     if (loc.startsWith('/home')) return 0;
// // //     if (loc.startsWith('/claims') && !loc.contains('new')) return 1;
// // //     if (loc.startsWith('/notifications')) return 2;
// // //     if (loc.startsWith('/profile')) return 3;
// // //     return 0;
// // //   }

// // //   void _showFeaturedZones(BuildContext context) {
// // //     showModalBottomSheet(
// // //       context: context,
// // //       backgroundColor: Colors.transparent,
// // //       isDismissible: true,
// // //       enableDrag: true,
// // //       builder: (_) => const _FeaturedZonesSheet(),
// // //     );
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final sel = _selectedIndex(context);

// // //     return Scaffold(
// // //       backgroundColor: const Color(0xFFF5F5F5),
// // //       body: child,

// // //       // ── Yellow centred FAB ─────────────────────────────────────────────
// // //       floatingActionButton: FloatingActionButton(
// // //         backgroundColor: const Color(0xFFEAB308),
// // //         elevation: 6,
// // //         shape: const CircleBorder(),
// // //         onPressed: () => _showFeaturedZones(context),
// // //         child: const Icon(
// // //           Icons.local_offer_rounded,
// // //           color: Colors.white,
// // //           size: 26,
// // //         ),
// // //       ),
// // //       floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

// // //       // ── Bottom App Bar (notched for FAB) ───────────────────────────────
// // //       bottomNavigationBar: BottomAppBar(
// // //         notchMargin: 8.0,
// // //         shape: const CircularNotchedRectangle(),
// // //         color: Colors.white,
// // //         elevation: 8,
// // //         padding: EdgeInsets.zero,
// // //         height: 64,
// // //         child: Row(
// // //           children: [
// // //             // Left half
// // //             Expanded(
// // //               child: Row(
// // //                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// // //                 children: [
// // //                   _NavItem(
// // //                     icon: Icons.home_outlined,
// // //                     activeIcon: Icons.home_rounded,
// // //                     label: 'Home',
// // //                     isSelected: sel == 0,
// // //                     onTap: () => context.go('/home'),
// // //                   ),
// // //                   _NavItem(
// // //                     icon: Icons.grid_view_outlined,
// // //                     activeIcon: Icons.grid_view_rounded,
// // //                     label: 'Browse',
// // //                     isSelected: sel == 1,
// // //                     onTap: () => context.go('/claims'),
// // //                   ),
// // //                 ],
// // //               ),
// // //             ),
// // //             // Gap for FAB
// // //             const SizedBox(width: 72),
// // //             // Right half
// // //             Expanded(
// // //               child: Row(
// // //                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// // //                 children: [
// // //                   _NavItem(
// // //                     icon: Icons.notifications_outlined,
// // //                     activeIcon: Icons.notifications_rounded,
// // //                     label: 'Alerts',
// // //                     isSelected: sel == 2,
// // //                     onTap: () => context.go('/notifications'),
// // //                   ),
// // //                   _NavItem(
// // //                     icon: Icons.person_outline_rounded,
// // //                     activeIcon: Icons.person_rounded,
// // //                     label: 'Profile',
// // //                     isSelected: sel == 3,
// // //                     onTap: () => context.go('/profile'),
// // //                   ),
// // //                 ],
// // //               ),
// // //             ),
// // //           ],
// // //         ),
// // //       ),
// // //     );
// // //   }
// // // }

// // // // ─────────────────────────────────────────────────────────────────────────────
// // // // Featured Zones bottom sheet
// // // // ─────────────────────────────────────────────────────────────────────────────

// // // class _ZoneItem {
// // //   final String label;
// // //   final IconData icon;
// // //   final String route;
// // //   const _ZoneItem({
// // //     required this.label,
// // //     required this.icon,
// // //     required this.route,
// // //   });
// // // }

// // // const _zones = [
// // //   _ZoneItem(
// // //     label: 'Reward\nZone',
// // //     icon: "assets/icons/reward_zone.png",
// // //     route: '/home',
// // //   ),
// // //   _ZoneItem(
// // //     label: 'Redeem\nZone',
// // //     icon: Icons.card_giftcard_rounded,
// // //     route: '/home',
// // //   ),
// // //   _ZoneItem(
// // //     label: 'Brand\nDeals',
// // //     icon: Icons.diamond_rounded,
// // //     route: '/claims',
// // //   ),
// // //   _ZoneItem(
// // //     label: 'Nearby\nDeals',
// // //     icon: Icons.store_rounded,
// // //     route: '/claims',
// // //   ),
// // //   _ZoneItem(
// // //     label: 'Promo\nReelz',
// // //     icon: Icons.movie_creation_rounded,
// // //     route: '/national-ads',
// // //   ),
// // //   _ZoneItem(
// // //     label: 'Local\nClassifieds',
// // //     icon: Icons.newspaper_rounded,
// // //     route: '/home',
// // //   ),
// // // ];

// // // class _FeaturedZonesSheet extends StatelessWidget {
// // //   const _FeaturedZonesSheet();

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return Container(
// // //       decoration: const BoxDecoration(
// // //         color: Colors.white,
// // //         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// // //       ),
// // //       padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
// // //       child: Column(
// // //         mainAxisSize: MainAxisSize.min,
// // //         children: [
// // //           // ── Drag handle ───────────────────────────────────────────────
// // //           Container(
// // //             width: 40,
// // //             height: 4,
// // //             margin: const EdgeInsets.only(bottom: 18),
// // //             decoration: BoxDecoration(
// // //               color: const Color(0xFFE5E7EB),
// // //               borderRadius: BorderRadius.circular(2),
// // //             ),
// // //           ),

// // //           // ── Title row ─────────────────────────────────────────────────
// // //           Row(
// // //             children: [
// // //               const Text(
// // //                 'Featured Zones',
// // //                 style: TextStyle(
// // //                   fontSize: 20,
// // //                   fontWeight: FontWeight.bold,
// // //                   color: Color(0xFF1E40AF),
// // //                 ),
// // //               ),
// // //               const SizedBox(width: 6),
// // //               Container(
// // //                 width: 8,
// // //                 height: 8,
// // //                 decoration: const BoxDecoration(
// // //                   color: Colors.redAccent,
// // //                   shape: BoxShape.circle,
// // //                 ),
// // //               ),
// // //             ],
// // //           ),

// // //           const SizedBox(height: 20),

// // //           // ── 3×2 grid ──────────────────────────────────────────────────
// // //           GridView.count(
// // //             crossAxisCount: 3,
// // //             shrinkWrap: true,
// // //             physics: const NeverScrollableScrollPhysics(),
// // //             mainAxisSpacing: 16,
// // //             crossAxisSpacing: 8,
// // //             childAspectRatio: 0.9,
// // //             children: _zones
// // //                 .map((z) => _ZoneTile(
// // //                       zone: z,
// // //                       onTap: () {
// // //                         Navigator.of(context).pop();
// // //                         if (z.route == '/national-ads') {
// // //                           context.push(z.route);
// // //                         } else {
// // //                           context.go(z.route);
// // //                         }
// // //                       },
// // //                     ))
// // //                 .toList(),
// // //           ),

// // //           const SizedBox(height: 8),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // // }

// // // // ─────────────────────────────────────────────────────────────────────────────
// // // // Single zone tile
// // // // ─────────────────────────────────────────────────────────────────────────────

// // // class _ZoneTile extends StatelessWidget {
// // //   final _ZoneItem zone;
// // //   final VoidCallback onTap;
// // //   const _ZoneTile({required this.zone, required this.onTap});

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return GestureDetector(
// // //       onTap: onTap,
// // //       child: Column(
// // //         mainAxisSize: MainAxisSize.min,
// // //         children: [
// // //           // Yellow circle with icon + red badge
// // //           Stack(
// // //             clipBehavior: Clip.none,
// // //             children: [
// // //               Container(
// // //                 width: 72,
// // //                 height: 72,
// // //                 decoration: BoxDecoration(
// // //                   shape: BoxShape.circle,
// // //                   color: const Color(0xFFFEF3C7),
// // //                   border: Border.all(
// // //                     color: const Color(0xFFEAB308).withOpacity(0.4),
// // //                     width: 2,
// // //                   ),
// // //                   boxShadow: [
// // //                     BoxShadow(
// // //                       color: const Color(0xFFEAB308).withOpacity(0.18),
// // //                       blurRadius: 10,
// // //                       offset: const Offset(0, 3),
// // //                     ),
// // //                   ],
// // //                 ),
// // //                 child: Center(
// // //                   child: Icon(
// // //                     zone.icon,
// // //                     size: 32,
// // //                     color: const Color(0xFFD97706),
// // //                   ),
// // //                 ),
// // //               ),
// // //               // Red badge dot top-right
// // //               Positioned(
// // //                 top: 2,
// // //                 right: 2,
// // //                 child: Container(
// // //                   width: 14,
// // //                   height: 14,
// // //                   decoration: const BoxDecoration(
// // //                     color: Colors.redAccent,
// // //                     shape: BoxShape.circle,
// // //                   ),
// // //                   child: const Center(
// // //                     child: Icon(
// // //                       Icons.close_rounded,
// // //                       size: 9,
// // //                       color: Colors.white,
// // //                     ),
// // //                   ),
// // //                 ),
// // //               ),
// // //             ],
// // //           ),

// // //           const SizedBox(height: 8),

// // //           // Label
// // //           Text(
// // //             zone.label,
// // //             textAlign: TextAlign.center,
// // //             style: const TextStyle(
// // //               fontSize: 12,
// // //               fontWeight: FontWeight.w600,
// // //               color: Color(0xFF1F2937),
// // //               height: 1.3,
// // //             ),
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // // }

// // // // ─────────────────────────────────────────────────────────────────────────────
// // // // Single nav item
// // // // ─────────────────────────────────────────────────────────────────────────────

// // // class _NavItem extends StatelessWidget {
// // //   final IconData icon;
// // //   final IconData activeIcon;
// // //   final String label;
// // //   final bool isSelected;
// // //   final VoidCallback onTap;

// // //   const _NavItem({
// // //     required this.icon,
// // //     required this.activeIcon,
// // //     required this.label,
// // //     required this.isSelected,
// // //     required this.onTap,
// // //   });

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final color = isSelected
// // //         ? AppTheme.secondaryColor
// // //         : const Color(0xFF9CA3AF);

// // //     return GestureDetector(
// // //       onTap: onTap,
// // //       behavior: HitTestBehavior.opaque,
// // //       child: SizedBox(
// // //         width: 64,
// // //         child: Column(
// // //           mainAxisAlignment: MainAxisAlignment.center,
// // //           children: [
// // //             Icon(isSelected ? activeIcon : icon, color: color, size: 24),
// // //             const SizedBox(height: 3),
// // //             Text(
// // //               label,
// // //               style: TextStyle(
// // //                 fontSize: 10,
// // //                 fontWeight:
// // //                     isSelected ? FontWeight.w600 : FontWeight.normal,
// // //                 color: color,
// // //               ),
// // //             ),
// // //           ],
// // //         ),
// // //       ),
// // //     );
// // //   }
// // // }
// // import 'package:flutter/material.dart';
// // import 'package:go_router/go_router.dart';
// // import 'package:provider/provider.dart';
// // import '../../../core/theme/app_theme.dart';
// // import '../../auth/providers/auth_provider.dart';
// // import '../../profile/providers/profile_provider.dart';
// // import '../../shops/models/shop_category.dart';

// // /// The persistent shell that wraps every main tab.
// // class HomeScreen extends StatefulWidget {
// //   final Widget child;
// //   const HomeScreen({super.key, required this.child});

// //   @override
// //   State<HomeScreen> createState() => _HomeScreenState();
// // }

// // class _HomeScreenState extends State<HomeScreen> {
// //   @override
// //   void initState() {
// //     super.initState();
// //     // Pre-load liked shop IDs and show account-linking nudge on first frame
// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       context.read<ProfileProvider>().fetchLikedIds();
// //       context.read<ProfileProvider>().fetchLikedDealIds();
// //       _maybeShowAccountLinkPopup();
// //     });
// //   }

// //   void _maybeShowAccountLinkPopup() {
// //     final auth = context.read<AuthProvider>();
// //     if (!auth.shouldShowAccountLinkPopup) return;
// //     auth.markAccountLinkPopupShown(); // mark immediately so it won't repeat

// //     final viaPhone = auth.loggedInViaPhone;
// //     final title = viaPhone ? 'Add Email for Email Login' : 'Add Mobile for Phone Login';
// //     final message = viaPhone
// //         ? 'You logged in with your mobile number. Add your email address in your profile so you can also log in with email next time.'
// //         : 'You logged in with your email. Add your mobile number in your profile so you can also log in with your phone number next time.';
// //     final icon = viaPhone ? Icons.email_outlined : Icons.phone_outlined;

// //     showDialog(
// //       context: context,
// //       barrierDismissible: true,
// //       builder: (ctx) => AlertDialog(
// //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
// //         contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
// //         content: Column(
// //           mainAxisSize: MainAxisSize.min,
// //           children: [
// //             Container(
// //               padding: const EdgeInsets.all(14),
// //               decoration: BoxDecoration(
// //                 color: AppTheme.primaryColor.withOpacity(0.1),
// //                 shape: BoxShape.circle,
// //               ),
// //               child: Icon(icon, size: 32, color: AppTheme.primaryColor),
// //             ),
// //             const SizedBox(height: 16),
// //             Text(
// //               title,
// //               textAlign: TextAlign.center,
// //               style: const TextStyle(
// //                 fontSize: 17,
// //                 fontWeight: FontWeight.bold,
// //                 color: AppTheme.textPrimary,
// //               ),
// //             ),
// //             const SizedBox(height: 10),
// //             Text(
// //               message,
// //               textAlign: TextAlign.center,
// //               style: const TextStyle(
// //                 fontSize: 13,
// //                 color: AppTheme.textSecondary,
// //                 height: 1.5,
// //               ),
// //             ),
// //             const SizedBox(height: 20),
// //             SizedBox(
// //               width: double.infinity,
// //               child: ElevatedButton.icon(
// //                 icon: const Icon(Icons.person_outline, size: 26),
// //                 label: const Text('Go to Profile'),
// //                 style: ElevatedButton.styleFrom(
// //                   backgroundColor: AppTheme.primaryColor,
// //                   foregroundColor: Colors.white,
// //                   shape: RoundedRectangleBorder(
// //                     borderRadius: BorderRadius.circular(10),
// //                   ),
// //                   padding: const EdgeInsets.symmetric(vertical: 12),
// //                 ),
// //                 onPressed: () {
// //                   Navigator.of(ctx).pop();
// //                   context.push('/profile/edit');
// //                 },
// //               ),
// //             ),
// //             TextButton(
// //               onPressed: () => Navigator.of(ctx).pop(),
// //               child: const Text(
// //                 'Maybe Later',
// //                 style: TextStyle(color: AppTheme.textSecondary),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   int _selectedIndex(BuildContext context) {
// //     final loc = GoRouterState.of(context).matchedLocation;
// //     if (loc.startsWith('/home')) return 0;
// //     if (loc.startsWith('/redeem-zone')) return 1;
// //     if (loc.startsWith('/claims') && !loc.contains('new')) return 1;
// //     if (loc.startsWith('/notifications')) return 2;
// //     if (loc.startsWith('/profile')) return 3;
// //     return 0;
// //   }

// //   void _showFeaturedZones(BuildContext context) {
// //     showModalBottomSheet(
// //       context: context,
// //       backgroundColor: Colors.transparent,
// //       isDismissible: true,
// //       enableDrag: true,
// //       builder: (_) => const _FeaturedZonesSheet(),
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     final sel = _selectedIndex(context);

// //     return Scaffold(
// //       body: widget.child,

// //       // ── Yellow centred FAB ─────────────────────────────────────────────
// //       floatingActionButton: SizedBox(
// //         width: 68,
// //         height: 68,
// //         child: FloatingActionButton(
// //           backgroundColor: const Color(0xFFEAB308),
// //           elevation: 6,
// //           shape: const CircleBorder(),
// //           onPressed: () => _showFeaturedZones(context),
// //           child: Image.asset(
// //             "assets/icons/main_icon.png",
// //             width: 54,
// //             height: 54,
// //             fit: BoxFit.contain,
// //           ),
// //         ),
// //       ),
// //       floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

// //       // ── Bottom App Bar (notched for FAB) ───────────────────────────────
// //       // Height is adaptive: kBottomNavigationBarHeight (56) + extra for tall
// //       // phones so the bar is never cramped on any device.
// //       bottomNavigationBar: BottomAppBar(
// //   notchMargin: 10.0,
// //   shape: const CircularNotchedRectangle(),
// //   color: const Color.fromARGB(255, 20, 143, 208), 
// //   elevation: 8,
// //   padding: EdgeInsets.zero,
// //   height: kBottomNavigationBarHeight + 16, // 72
// //   child: Row(
// //     children: [
// //       // Left half
// //       Expanded(
// //         child: Row(
// //           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// //           children: [
// //             _NavItem(
// //               icon: Icons.home_outlined,
// //               activeIcon: Icons.home_rounded,
// //               label: 'Home',
// //               isSelected: sel == 0,
// //               onTap: () => context.go('/home'),
// //               assetIcon: 'assets/icons/home_page_icons/icon2.png',
// //               assetActiveIcon: 'assets/icons/home_page_icons/icon1.png',
// //               assetPadding: const EdgeInsets.all(4.0), // 👈 Shrinks the large Home image internally
// //             ),
// //             _NavItem(
// //               icon: Icons.play_circle_outline_rounded,
// //               activeIcon: Icons.play_circle_rounded,
// //               label: 'Reels',
// //               isSelected: sel == 1,
// //               onTap: () => context.go('/reelz'),
// //               // assetIcon: 'assets/icons/home_page_icons/reels_icon.png', // Add if available
// //               // assetPadding: const EdgeInsets.all(4.0), // 👈 Apply same padding if the image is too large
// //             ),
// //           ],
// //         ),
// //       ),
      
// //       // Gap for FAB
// //       const SizedBox(width: 72),
      
// //       // Right half
// //       Expanded(
// //         child: Row(
// //           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// //           children: [
// //             _NavItem(
// //               icon: Icons.qr_code_scanner_rounded,
// //               activeIcon: Icons.qr_code_scanner_rounded,
// //               label: 'Scan Bill',
// //               isSelected: false, 
// //               onTap: () => context.push('/bill-reader'),
// //               assetIcon: 'assets/icons/home_page_icons/icon5.png',
// //               assetActiveIcon: 'assets/icons/home_page_icons/icon6.png',
// //               assetPadding: EdgeInsets.zero, // Keep zero because the image itself is already small
// //             ),
// //             _NavItem(
// //               icon: Icons.person_outline_rounded,
// //               activeIcon: Icons.person_rounded,
// //               label: 'Profile',
// //               isSelected: sel == 3,
// //               onTap: () => context.go('/profile'),
// //               assetIcon: 'assets/icons/home_page_icons/icon7.png',
// //               assetActiveIcon: 'assets/icons/home_page_icons/icon8.png',
// //               assetPadding: EdgeInsets.zero, // Keep zero because the image itself is already small
// //             ),
// //           ],
// //         ),
// //       ),
// //     ],
// //   ),
// // ),
// //     );
// //   }
// // }

// // // ─────────────────────────────────────────────────────────────────────────────
// // // Featured Zones bottom sheet
// // // ─────────────────────────────────────────────────────────────────────────────

// // class _ZoneItem {
// //   final String label;
// //   final dynamic icon; 
// //   final String route;
// //   const _ZoneItem({
// //     required this.label,
// //     required this.icon,
// //     required this.route,
// //   });
// // }

// // const _zones = [
// //   _ZoneItem(
// //     label: 'Reward\nZone',
// //     icon: "assets/images/f1.png", 
// //     route: '/home',
// //   ),
// //   _ZoneItem(
// //     label: 'Redeem\nZone',
// //     icon: "assets/images/f2.png",
// //     route: '/home',
// //   ),
// //   _ZoneItem(
// //     label: 'Brand\nDeals',
// //     icon: "assets/images/f3.png",
// //     route: '/claims',
// //   ),
// //   _ZoneItem(
// //     label: 'Nearby\nDeals',
// //     icon: "assets/images/f4.png",
// //     route: '/claims',
// //   ),
// //   _ZoneItem(
// //     label: 'Promo\nReelz',
// //     icon: "assets/images/f5.png",
// //     route: '/reelz',
// //   ),
// //   _ZoneItem(
// //     label: 'Local\nClassifieds',
// //     icon: "assets/images/f6.png",
// //     route: '/classified',
// //   ),
  
// // ];

// // class _FeaturedZonesSheet extends StatelessWidget {
// //   const _FeaturedZonesSheet();

// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       decoration: BoxDecoration(
// //         color: Theme.of(context).colorScheme.surface,
// //         borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
// //       ),
// //       padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
// //       child: Column(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           // ── Drag handle ───────────────────────────────────────────────
// //           Container(
// //             width: 40,
// //             height: 4,
// //             margin: const EdgeInsets.only(bottom: 18),
// //             decoration: BoxDecoration(
// //               color: const Color(0xFFE5E7EB),
// //               borderRadius: BorderRadius.circular(2),
// //             ),
// //           ),

// //           // ── Title row ─────────────────────────────────────────────────
// //           Row(
// //             children: [
// //               Text(
// //                 'Featured Zones',
// //                 style: TextStyle(
// //                   fontSize: 20,
// //                   fontWeight: FontWeight.bold,
// //                   color: Theme.of(context).colorScheme.primary,
// //                 ),
// //               ),
// //               const SizedBox(width: 6),
// //               Container(
// //                 width: 8,
// //                 height: 8,
// //                 decoration: const BoxDecoration(
// //                   color: Colors.redAccent,
// //                   shape: BoxShape.circle,
// //                 ),
// //               ),
// //             ],
// //           ),

// //           const SizedBox(height: 20),

// //           // ── 3 columns grid ─────────────────────────────────────────────
// //           GridView.count(
// //             crossAxisCount: 3,
// //             shrinkWrap: true,
// //             physics: const NeverScrollableScrollPhysics(),
// //             mainAxisSpacing: 8,
// //             crossAxisSpacing: 8,
// //             childAspectRatio: 0.95,
// //             children: _zones
// //                 .map((z) => _ZoneTile(
// //                       zone: z,
// //                       onTap: () {
// //                         Navigator.of(context).pop();
// //                         final label = z.label.replaceAll('\n', ' ');
// //                         if (label == 'Reward Zone') {
// //                           // id=0 → all shops, opens on Rewards tab
// //                           context.push('/shops', extra: const ShopCategory(
// //                             id: 0,
// //                             name: 'Reward Zone',
// //                             icon: Icons.card_membership_rounded,
// //                             color: Color(0xFF2563EB),
// //                           ));
// //                         } else if (label == 'Redeem Zone') {
// //                           // id=-1 → all shops, opens on Redeem tab
// //                           context.push('/shops', extra: const ShopCategory(
// //                             id: -1,
// //                             name: 'Redeem Zone',
// //                             icon: Icons.redeem_rounded,
// //                             color: Color(0xFF059669),
// //                           ));
// //                         } else if (label == 'Brand Deals') {
// //                           context.push('/brands');
// //                         } else if (label == 'Nearby Deals') {
// //                           context.push('/nearby-deals');
// //                         } else if (label == 'Promo Reelz') {
// //                           context.push('/reelz');
// //                         } else if (label == 'Local Classifieds') {
// //                           context.push('/classified');
// //                         } else {
// //                           context.go(z.route);
// //                         }
// //                       },
// //                     ))
// //                 .toList(),
// //           ),

// //           const SizedBox(height: 8),
// //         ],
// //       ),
// //     );
// //   }
// // }

// // // ─────────────────────────────────────────────────────────────────────────────
// // // Single zone tile
// // // ─────────────────────────────────────────────────────────────────────────────

// // class _ZoneTile extends StatelessWidget {
// //   final _ZoneItem zone;
// //   final VoidCallback onTap;
// //   const _ZoneTile({required this.zone, required this.onTap});

// //   @override
// //   Widget build(BuildContext context) {
// //     return GestureDetector(
// //       onTap: onTap,
// //       child: Column(
// //         mainAxisSize: MainAxisSize.min,
// //         crossAxisAlignment: CrossAxisAlignment.center,
// //         children: [
// //           Stack(
// //             clipBehavior: Clip.none,
// //             children: [
// //               SizedBox(
// //                 width: 64,
// //                 height: 64,
// //                 child: Center(
// //                   child: zone.icon is String
// //                       ? Image.asset(
// //                           zone.icon,
// //                           width: 56,
// //                           height: 56,
// //                           fit: BoxFit.contain,
// //                           errorBuilder: (_, __, ___) => const Icon(
// //                             Icons.broken_image,
// //                             size: 32,
// //                             color: Color(0xFFD97706),
// //                           ),
// //                         )
// //                       : Icon(
// //                           zone.icon as IconData,
// //                           size: 32,
// //                           color: const Color(0xFFD97706),
// //                         ),
// //                 ),
// //               ),
// //               // Positioned(
// //               //   top: -2,
// //               //   right: -2,
// //               //   child: Container(
// //               //     width: 14,
// //               //     height: 14,
// //               //     decoration: const BoxDecoration(
// //               //       color: Colors.redAccent,
// //               //       shape: BoxShape.circle,
// //               //     ),
// //               //     child: const Center(
// //               //       child: Icon(
// //               //         Icons.close_rounded,
// //               //         size: 9,
// //               //         color: Colors.white,
// //               //       ),
// //               //     ),
// //               //   ),
// //               // ),
// //             ],
// //           ),

// //           const SizedBox(height: 4), // Reduced from 8 to pull the label right below the icon

// //           // Label
// //           Text(
// //             zone.label,
// //             textAlign: TextAlign.center,
// //             maxLines: 2,
// //             overflow: TextOverflow.ellipsis,
// //             style: TextStyle(
// //               fontSize: 12,
// //               fontWeight: FontWeight.w600,
// //               color: Theme.of(context).colorScheme.onSurface,
// //               height: 1.2,
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }

// // // ─────────────────────────────────────────────────────────────────────────────
// // // Single nav item
// // // ─────────────────────────────────────────────────────────────────────────────

// // class _NavItem extends StatefulWidget {
// //   final IconData icon;
// //   final IconData activeIcon;
// //   final String label;
// //   final bool isSelected;
// //   final VoidCallback onTap;
// //   // Optional asset paths from home_page_icons (normal / active)
// //   final String? assetIcon;
// //   final String? assetActiveIcon;
// //   // Override icon size (use for assets with more whitespace like Scan Bill/Profile)
// //   final double? sizeOverride;
// //   final EdgeInsets assetPadding;

// //   const _NavItem({
// //     required this.icon,
// //     required this.activeIcon,
// //     required this.label,
// //     required this.isSelected,
// //     required this.onTap,
// //     this.assetIcon,
// //     this.assetActiveIcon,
// //     this.sizeOverride,
// //   });

// //   @override
// //   State<_NavItem> createState() => _NavItemState();
// // }

// // class _NavItemState extends State<_NavItem> {
// //   bool isHovered = false;

// //   @override
// //   Widget build(BuildContext context) {
// //     final Color color;
// //     if (widget.isSelected) {
// //       color = const Color.fromARGB(255, 238, 255, 0); // selected yellow
// //     } else if (isHovered) {
// //       color = Colors.yellow;
// //     } else {
// //       color = Colors.white;
// //     }

// //     // Choose asset path when available
// //     final assetPath = widget.isSelected
// //         ? (widget.assetActiveIcon ?? widget.assetIcon)
// //         : widget.assetIcon;

// //     final screenW = MediaQuery.of(context).size.width;
// //     // Use sizeOverride when provided (for assets with extra whitespace),
// //     // otherwise calculate from screen width — clamped 28–34
// //     final iconSize = widget.sizeOverride ?? (screenW * 0.09).clamp(28.0, 34.0);

// //     return MouseRegion(
// //       cursor: SystemMouseCursors.click,
// //       onEnter: (_) => setState(() => isHovered = true),
// //       onExit: (_) => setState(() => isHovered = false),
// //       child: GestureDetector(
// //         onTap: widget.onTap,
// //         behavior: HitTestBehavior.opaque,
// //         child: ConstrainedBox(
// //           constraints: const BoxConstraints(minWidth: 60, maxWidth: 100),
// //           child: Column(
// //             mainAxisAlignment: MainAxisAlignment.center,
// //             children: [
// //               if (assetPath != null)
// //                 Image.asset(
// //                   assetPath,
// //                   width: iconSize,
// //                   height: iconSize,
// //                   fit: BoxFit.contain,
// //                   color: color,
// //                   colorBlendMode: BlendMode.srcIn,
// //                   errorBuilder: (_, __, ___) => Icon(
// //                     widget.isSelected ? widget.activeIcon : widget.icon,
// //                     color: color,
// //                     size: iconSize,
// //                   ),
// //                 )
// //               else
// //                 Icon(
// //                   widget.isSelected ? widget.activeIcon : widget.icon,
// //                   color: color,
// //                   size: iconSize,
// //                 ),

// //               const SizedBox(height: 3),

// //               Text(
// //                 widget.label,
// //                 maxLines: 1,
// //                 overflow: TextOverflow.ellipsis,
// //                 style: TextStyle(
// //                   fontSize: (screenW * 0.028).clamp(10.0, 13.0),
// //                   fontWeight:
// //                       widget.isSelected ? FontWeight.w700 : FontWeight.w600,
// //                   color: color,
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }

// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:provider/provider.dart';
// import '../../../core/theme/app_theme.dart';
// import '../../auth/providers/auth_provider.dart';
// import '../../profile/providers/profile_provider.dart';
// import '../../shops/models/shop_category.dart';

// /// The persistent shell that wraps every main tab.
// class HomeScreen extends StatefulWidget {
//   final Widget child;
//   const HomeScreen({super.key, required this.child});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<ProfileProvider>().fetchLikedIds();
//       context.read<ProfileProvider>().fetchLikedDealIds();
//       _maybeShowAccountLinkPopup();
//     });
//   }

//   void _maybeShowAccountLinkPopup() {
//     final auth = context.read<AuthProvider>();
//     if (!auth.shouldShowAccountLinkPopup) return;
//     auth.markAccountLinkPopupShown();

//     final viaPhone = auth.loggedInViaPhone;
//     final title = viaPhone ? 'Add Email for Email Login' : 'Add Mobile for Phone Login';
//     final message = viaPhone
//         ? 'You logged in with your mobile number. Add your email address in your profile so you can also log in with email next time.'
//         : 'You logged in with your email. Add your mobile number in your profile so you can also log in with your phone number next time.';
//     final icon = viaPhone ? Icons.email_outlined : Icons.phone_outlined;

//     showDialog(
//       context: context,
//       barrierDismissible: true,
//       builder: (ctx) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 color: AppTheme.primaryColor.withOpacity(0.1),
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(icon, size: 32, color: AppTheme.primaryColor),
//             ),
//             const SizedBox(height: 16),
//             Text(
//               title,
//               textAlign: TextAlign.center,
//               style: const TextStyle(
//                 fontSize: 17,
//                 fontWeight: FontWeight.bold,
//                 color: AppTheme.textPrimary,
//               ),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               message,
//               textAlign: TextAlign.center,
//               style: const TextStyle(
//                 fontSize: 13,
//                 color: AppTheme.textSecondary,
//                 height: 1.5,
//               ),
//             ),
//             const SizedBox(height: 20),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 icon: const Icon(Icons.person_outline, size: 26),
//                 label: const Text('Go to Profile'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: AppTheme.primaryColor,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   padding: const EdgeInsets.symmetric(vertical: 12),
//                 ),
//                 onPressed: () {
//                   Navigator.of(ctx).pop();
//                   context.push('/profile/edit');
//                 },
//               ),
//             ),
//             TextButton(
//               onPressed: () => Navigator.of(ctx).pop(),
//               child: const Text(
//                 'Maybe Later',
//                 style: TextStyle(color: AppTheme.textSecondary),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   int _selectedIndex(BuildContext context) {
//     final loc = GoRouterState.of(context).matchedLocation;
//     if (loc.startsWith('/home')) return 0;
//     if (loc.startsWith('/redeem-zone')) return 1;
//     if (loc.startsWith('/claims') && !loc.contains('new')) return 1;
//     if (loc.startsWith('/notifications')) return 2;
//     if (loc.startsWith('/profile')) return 3;
//     return 0;
//   }

//   void _showFeaturedZones(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.transparent,
//       isDismissible: true,
//       enableDrag: true,
//       builder: (_) => const _FeaturedZonesSheet(),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final sel = _selectedIndex(context);

//     return Scaffold(
//       body: widget.child,

//       // ── Yellow centred FAB ─────────────────────────────────────────────
//       floatingActionButton: SizedBox(
//         width: 68,
//         height: 68,
//         child: FloatingActionButton(
//           backgroundColor: const Color(0xFFEAB308),
//           elevation: 6,
//           shape: const CircleBorder(),
//           onPressed: () => _showFeaturedZones(context),
//           child: Image.asset(
//             "assets/icons/main_icon.png",
//             width: 54,
//             height: 54,
//             fit: BoxFit.contain,
//           ),
//         ),
//       ),
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

//       // ── Bottom App Bar (notched for FAB) ───────────────────────────────
//       bottomNavigationBar: BottomAppBar(
//         notchMargin: 10.0,
//         shape: const CircularNotchedRectangle(),
//         color: const Color.fromARGB(255, 20, 143, 208), 
//         elevation: 8,
//         padding: EdgeInsets.zero,
//         height: kBottomNavigationBarHeight + 16, // Total height is 72
//         child: Row(
//           children: [
//             // Left half
//             Expanded(
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   _NavItem(
//                     icon: Icons.home_outlined,
//                     activeIcon: Icons.home_rounded,
//                     label: 'Home',
//                     isSelected: sel == 0,
//                     onTap: () => context.go('/home'),
//                     assetIcon: 'assets/icons/home_page_icons/icon2.png',
//                     assetActiveIcon: 'assets/icons/home_page_icons/icon1.png',
//                     iconSize: 32.0, // Kept at your preferred sizing
//                     fontSize: 11.0,
//                     assetPadding: const EdgeInsets.all(4.0),
//                   ),
//                   _NavItem(
//                     icon: Icons.play_circle_outline_rounded,
//                     activeIcon: Icons.play_circle_rounded,
//                     label: 'Reels',
//                     isSelected: sel == 1,
//                     onTap: () => context.go('/reelz'),
//                     iconSize: 32.0, // Kept at your preferred sizing
//                     fontSize: 11.0,
//                     assetPadding: EdgeInsets.zero,
//                   ),
//                 ],
//               ),
//             ),
            
//             // Gap for FAB
//             const SizedBox(width: 72),
            
//             // Right half
//             Expanded(
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   _NavItem(
//                     icon: Icons.qr_code_scanner_rounded,
//                     activeIcon: Icons.qr_code_scanner_rounded,
//                     label: 'Scan Bill',
//                     isSelected: false, 
//                     onTap: () => context.push('/bill-reader'),
//                     assetIcon: 'assets/icons/home_page_icons/icon5.png',
//                     assetActiveIcon: 'assets/icons/home_page_icons/icon6.png',
//                     iconSize: 45.0, // 👈 MANUALLY ADJUST ME: Scale up separate from home
//                     fontSize: 11.0,
//                     assetPadding: EdgeInsets.zero,
//                   ),
//                   _NavItem(
//                     icon: Icons.person_outline_rounded,
//                     activeIcon: Icons.person_rounded,
//                     label: 'Profile',
//                     isSelected: sel == 3,
//                     onTap: () => context.go('/profile'),
//                     assetIcon: 'assets/icons/home_page_icons/icon7.png',
//                     assetActiveIcon: 'assets/icons/home_page_icons/icon8.png',
//                     iconSize: 45.0, // 👈 MANUALLY ADJUST ME: Scale up separate from home
//                     fontSize: 11.0,
//                     assetPadding: EdgeInsets.zero,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Featured Zones bottom sheet
// // ─────────────────────────────────────────────────────────────────────────────

// class _ZoneItem {
//   final String label;
//   final dynamic icon; 
//   final String route;
//   const _ZoneItem({
//     required this.label,
//     required this.icon,
//     required this.route,
//   });
// }

// const _zones = [
//   _ZoneItem(label: 'Reward\nZone', icon: "assets/images/f1.png", route: '/home'),
//   _ZoneItem(label: 'Redeem\nZone', icon: "assets/images/f2.png", route: '/home'),
//   _ZoneItem(label: 'Brand\nDeals', icon: "assets/images/f3.png", route: '/claims'),
//   _ZoneItem(label: 'Nearby\nDeals', icon: "assets/images/f4.png", route: '/claims'),
//   _ZoneItem(label: 'Promo\nReelz', icon: "assets/images/f5.png", route: '/reelz'),
//   _ZoneItem(label: 'Local\nClassifieds', icon: "assets/images/f6.png", route: '/classified'),
// ];

// class _FeaturedZonesSheet extends StatelessWidget {
//   const _FeaturedZonesSheet();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Theme.of(context).colorScheme.surface,
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 40,
//             height: 4,
//             margin: const EdgeInsets.only(bottom: 18),
//             decoration: BoxDecoration(
//               color: const Color(0xFFE5E7EB),
//               borderRadius: BorderRadius.circular(2),
//             ),
//           ),
//           Row(
//             children: [
//               Text(
//                 'Featured Zones',
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Theme.of(context).colorScheme.primary,
//                 ),
//               ),
//               const SizedBox(width: 6),
//               Container(
//                 width: 8,
//                 height: 8,
//                 decoration: const BoxDecoration(
//                   color: Colors.redAccent,
//                   shape: BoxShape.circle,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           GridView.count(
//             crossAxisCount: 3,
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             mainAxisSpacing: 8,
//             crossAxisSpacing: 8,
//             childAspectRatio: 0.95,
//             children: _zones
//                 .map((z) => _ZoneTile(
//                       zone: z,
//                       onTap: () {
//                         Navigator.of(context).pop();
//                         final label = z.label.replaceAll('\n', ' ');
//                         if (label == 'Reward Zone') {
//                           context.push('/shops', extra: const ShopCategory(
//                             id: 0,
//                             name: 'Reward Zone',
//                             icon: Icons.card_membership_rounded,
//                             color: Color(0xFF2563EB),
//                           ));
//                         } else if (label == 'Redeem Zone') {
//                           context.push('/shops', extra: const ShopCategory(
//                             id: -1,
//                             name: 'Redeem Zone',
//                             icon: Icons.redeem_rounded,
//                             color: Color(0xFF059669),
//                           ));
//                         } else if (label == 'Brand Deals') {
//                           context.push('/brands');
//                         } else if (label == 'Nearby Deals') {
//                           context.push('/nearby-deals');
//                         } else if (label == 'Promo Reelz') {
//                           context.push('/reelz');
//                         } else if (label == 'Local Classifieds') {
//                           context.push('/classified');
//                         } else {
//                           context.go(z.route);
//                         }
//                       },
//                     ))
//                 .toList(),
//           ),
//           const SizedBox(height: 8),
//         ],
//       ),
//     );
//   }
// }

// class _ZoneTile extends StatelessWidget {
//   final _ZoneItem zone;
//   final VoidCallback onTap;
//   const _ZoneTile({required this.zone, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           Stack(
//             clipBehavior: Clip.none,
//             children: [
//               SizedBox(
//                 width: 64,
//                 height: 64,
//                 child: Center(
//                   child: zone.icon is String
//                       ? Image.asset(
//                           zone.icon,
//                           width: 56,
//                           height: 56,
//                           fit: BoxFit.contain,
//                           errorBuilder: (_, __, ___) => const Icon(
//                             Icons.broken_image,
//                             size: 32,
//                             color: Color(0xFFD97706),
//                           ),
//                         )
//                       : Icon(
//                           zone.icon as IconData,
//                           size: 32,
//                           color: const Color(0xFFD97706),
//                         ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 4),
//           Text(
//             zone.label,
//             textAlign: TextAlign.center,
//             maxLines: 2,
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//               color: Theme.of(context).colorScheme.onSurface,
//               height: 1.2,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Single Nav Item
// // ─────────────────────────────────────────────────────────────────────────────

// class _NavItem extends StatefulWidget {
//   final IconData icon;
//   final IconData activeIcon;
//   final String label;
//   final bool isSelected;
//   final VoidCallback onTap;
//   final String? assetIcon;
//   final String? assetActiveIcon;
//   final double iconSize;      
//   final double fontSize;      
//   final EdgeInsets assetPadding;

//   const _NavItem({
//     required this.icon,
//     required this.activeIcon,
//     required this.label,
//     required this.isSelected,
//     required this.onTap,
//     this.assetIcon,
//     this.assetActiveIcon,
//     required this.iconSize,
//     required this.fontSize,
//     this.assetPadding = EdgeInsets.zero,
//   });

//   @override
//   State<_NavItem> createState() => _NavItemState();
// }

// class _NavItemState extends State<_NavItem> {
//   bool isHovered = false;

//   @override
//   Widget build(BuildContext context) {
//     final Color color;
//     if (widget.isSelected) {
//       color = const Color.fromARGB(255, 238, 255, 0); 
//     } else if (isHovered) {
//       color = Colors.yellow;
//     } else {
//       color = Colors.white;
//     }

//     final assetPath = widget.isSelected
//         ? (widget.assetActiveIcon ?? widget.assetIcon)
//         : widget.assetIcon;

//     return MouseRegion(
//       cursor: SystemMouseCursors.click,
//       onEnter: (_) => setState(() => isHovered = true),
//       onExit: (_) => setState(() => isHovered = false),
//       child: GestureDetector(
//         onTap: widget.onTap,
//         behavior: HitTestBehavior.opaque,
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(minWidth: 60, maxWidth: 100),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               SizedBox(
//                 width: widget.iconSize,
//                 height: widget.iconSize,
//                 child: Center(
//                   child: assetPath != null
//                       ? Padding(
//                           padding: widget.assetPadding,
//                           child: Image.asset(
//                             assetPath,
//                             fit: BoxFit.contain,
//                             color: color,
//                             colorBlendMode: BlendMode.srcIn,
//                             errorBuilder: (_, __, ___) => Icon(
//                               widget.isSelected ? widget.activeIcon : widget.icon,
//                               color: color,
//                               size: widget.iconSize,
//                             ),
//                           ),
//                         )
//                       : Icon(
//                           widget.isSelected ? widget.activeIcon : widget.icon,
//                           color: color,
//                           size: widget.iconSize,
//                         ),
//                 ),
//               ),

//               const SizedBox(height: 4),

//               Text(
//                 widget.label,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 style: TextStyle(
//                   fontSize: widget.fontSize,
//                   fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
//                   color: color,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../shops/models/shop_category.dart';
import '../../../core/router/app_router.dart' show appRouteObserver, homeShellCovered;

/// The persistent shell that wraps every main tab.
class HomeScreen extends StatefulWidget {
  final Widget child;
  const HomeScreen({super.key, required this.child});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  PageRoute? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().fetchLikedIds();
      context.read<ProfileProvider>().fetchLikedDealIds();
      _maybeShowAccountLinkPopup();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // HomeScreen sits between the outer root route and the inner bottom-nav
    // shell navigator, so ModalRoute.of(context) here correctly resolves the
    // OUTER route — the one that actually gets covered when e.g. Scan Bill,
    // a shop page, or National Ads is pushed. Nested widgets like the home
    // banner can't resolve this themselves (see homeShellCovered docs).
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _subscribedRoute) {
      if (_subscribedRoute != null) appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
      _subscribedRoute = route;
    }
  }

  // ── RouteAware ─────────────────────────────────────────────────────────
  @override
  void didPushNext() => homeShellCovered.value = true;

  @override
  void didPopNext() => homeShellCovered.value = false;

  @override
  void dispose() {
    if (_subscribedRoute != null) appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _maybeShowAccountLinkPopup() {
    final auth = context.read<AuthProvider>();
    if (!auth.shouldShowAccountLinkPopup) return;
    auth.markAccountLinkPopupShown();

    final viaPhone = auth.loggedInViaPhone;
    final title = viaPhone ? 'Add Email for Email Login' : 'Add Mobile for Phone Login';
    final message = viaPhone
        ? 'You logged in with your mobile number. Add your email address in your profile so you can also log in with email next time.'
        : 'You logged in with your email. Add your mobile number in your profile so you can also log in with your phone number next time.';
    final icon = viaPhone ? Icons.email_outlined : Icons.phone_outlined;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_outline, size: 26),
                label: const Text('Go to Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push('/profile/edit');
                },
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Maybe Later',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/home')) return 0;
    if (loc.startsWith('/redeem-zone')) return 1;
    if (loc.startsWith('/claims') && !loc.contains('new')) return 1;
    if (loc.startsWith('/notifications')) return 2;
    if (loc.startsWith('/profile')) return 3;
    return 0;
  }

  void _showFeaturedZones(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => const _FeaturedZonesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selectedIndex(context);
    final screenW = MediaQuery.of(context).size.width;

    // ── Responsive Scale Calculations ────────────────────────────────────────
    // Scales dynamically using screen width percentages, bounded safely by clamps.
    final dynamicHomeReelsSize = (screenW * 0.075).clamp(24.0, 28.0);
    final dynamicScanProfileSize = (screenW * 0.095).clamp(30.0, 38.0);
    final dynamicFontSize = (screenW * 0.025).clamp(9.0, 11.0);

    return Scaffold(
      body: widget.child,

      // ── Yellow centred FAB ─────────────────────────────────────────────
      floatingActionButton: SizedBox(
        width: 68,
        height: 68,
        child: FloatingActionButton(
          backgroundColor: const Color(0xFFEAB308),
          elevation: 6,
          shape: const CircleBorder(),
          onPressed: () => _showFeaturedZones(context),
          child: Image.asset(
            "assets/icons/main_icon.png",
            width: 54,
            height: 54,
            fit: BoxFit.contain,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── Bottom App Bar (notched for FAB) ───────────────────────────────
      bottomNavigationBar: BottomAppBar(
        notchMargin: 10.0,
        shape: const CircularNotchedRectangle(),
        color: const Color.fromARGB(255, 20, 143, 208), 
        elevation: 8,
        padding: EdgeInsets.zero,
        height: kBottomNavigationBarHeight + 6, // Fixed safe 62dp high row
        child: Row(
          children: [
            // Left half
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home',
                    isSelected: sel == 0,
                    onTap: () => context.go('/home'),
                    assetIcon: 'assets/icons/home_page_icons/icon2.png',
                    assetActiveIcon: 'assets/icons/home_page_icons/icon1.png',
                    iconSize: dynamicHomeReelsSize, 
                    fontSize: dynamicFontSize,
                    assetPadding: const EdgeInsets.all(4.0),
                  ),
                  _NavItem(
                    icon: Icons.play_circle_outline_rounded,
                    activeIcon: Icons.play_circle_rounded,
                    label: 'Reels',
                    isSelected: sel == 1,
                    onTap: () => context.go('/reelz'),
                    iconSize: dynamicHomeReelsSize, 
                    fontSize: dynamicFontSize,
                    assetPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            
            // Gap for FAB
            const SizedBox(width: 72),
            
            // Right half
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                    icon: Icons.qr_code_scanner_rounded,
                    activeIcon: Icons.qr_code_scanner_rounded,
                    label: 'Scan Bill',
                    isSelected: false, 
                    onTap: () => context.push('/bill-reader'),
                    assetIcon: 'assets/icons/home_page_icons/icon5.png',
                    assetActiveIcon: 'assets/icons/home_page_icons/icon6.png',
                    iconSize: dynamicScanProfileSize, // Automatically scales right around 45.0
                    fontSize: dynamicFontSize,
                    assetPadding: EdgeInsets.zero,
                  ),
                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Profile',
                    isSelected: sel == 3,
                    onTap: () => context.go('/profile'),
                    assetIcon: 'assets/icons/home_page_icons/icon7.png',
                    assetActiveIcon: 'assets/icons/home_page_icons/icon8.png',
                    iconSize: dynamicScanProfileSize, // Automatically scales right around 45.0
                    fontSize: dynamicFontSize,
                    assetPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Featured Zones bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ZoneItem {
  final String label;
  final dynamic icon; 
  final String route;
  const _ZoneItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}

const _zones = [
  _ZoneItem(label: 'Reward\nZone', icon: "assets/images/f1.png", route: '/home'),
  _ZoneItem(label: 'Redeem\nZone', icon: "assets/images/f2.png", route: '/home'),
  _ZoneItem(label: 'Brand\nDeals', icon: "assets/images/f3.png", route: '/claims'),
  _ZoneItem(label: 'Nearby\nDeals', icon: "assets/images/f4.png", route: '/claims'),
  _ZoneItem(label: 'Promo\nReelz', icon: "assets/images/f5.png", route: '/reelz'),
  _ZoneItem(label: 'Local Finds\nClassifieds', icon: "assets/images/f6.png", route: '/classified'),
];

class _FeaturedZonesSheet extends StatelessWidget {
  const _FeaturedZonesSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              Text(
                'Featured Zones',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.95,
            children: _zones
                .map((z) => _ZoneTile(
                      zone: z,
                      onTap: () {
                        Navigator.of(context).pop();
                        final label = z.label.replaceAll('\n', ' ');
                        if (label == 'Reward Zone') {
                          context.push('/shops', extra: const ShopCategory(
                            id: 0,
                            name: 'Reward Zone',
                            icon: Icons.card_membership_rounded,
                            color: Color(0xFF2563EB),
                          ));
                        } else if (label == 'Redeem Zone') {
                          context.push('/shops', extra: const ShopCategory(
                            id: -1,
                            name: 'Redeem Zone',
                            icon: Icons.redeem_rounded,
                            color: Color(0xFF059669),
                          ));
                        } else if (label == 'Brand Deals') {
                          context.push('/brands');
                        } else if (label == 'Nearby Deals') {
                          context.push('/nearby-deals');
                        } else if (label == 'Promo Reelz') {
                          context.push('/reelz');
                        } else if (label == 'Local Finds Classifieds') {
                          context.push('/classified');
                        } else {
                          context.go(z.route);
                        }
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ZoneTile extends StatelessWidget {
  final _ZoneItem zone;
  final VoidCallback onTap;
  const _ZoneTile({required this.zone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Center(
                  child: zone.icon is String
                      ? Image.asset(
                          zone.icon,
                          width: 56,
                          height: 56,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            size: 32,
                            color: Color(0xFFD97706),
                          ),
                        )
                      : Icon(
                          zone.icon as IconData,
                          size: 32,
                          color: const Color(0xFFD97706),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            zone.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Single Nav Item Component
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? assetIcon;
  final String? assetActiveIcon;
  final double iconSize;      
  final double fontSize;      
  final EdgeInsets assetPadding;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.assetIcon,
    this.assetActiveIcon,
    required this.iconSize,
    required this.fontSize,
    this.assetPadding = EdgeInsets.zero,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (widget.isSelected) {
      color = const Color.fromARGB(255, 238, 255, 0); 
    } else if (isHovered) {
      color = Colors.yellow;
    } else {
      color = Colors.white;
    }

    final assetPath = widget.isSelected
        ? (widget.assetActiveIcon ?? widget.assetIcon)
        : widget.assetIcon;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 60, maxWidth: 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: widget.iconSize,
                height: widget.iconSize,
                child: Center(
                  child: assetPath != null
                      ? Padding(
                          padding: widget.assetPadding,
                          child: Image.asset(
                            assetPath,
                            fit: BoxFit.contain,
                            color: color,
                            colorBlendMode: BlendMode.srcIn,
                            errorBuilder: (_, __, ___) => Icon(
                              widget.isSelected ? widget.activeIcon : widget.icon,
                              color: color,
                              size: widget.iconSize,
                            ),
                          ),
                        )
                      : Icon(
                          widget.isSelected ? widget.activeIcon : widget.icon,
                          color: color,
                          size: widget.iconSize,
                        ),
                ),
              ),

              const SizedBox(height: 1),

              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
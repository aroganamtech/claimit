// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import '../../../core/theme/app_theme.dart';

// /// The persistent shell that wraps every main tab.
// class HomeScreen extends StatelessWidget {
//   final Widget child;
//   const HomeScreen({super.key, required this.child});

//   int _selectedIndex(BuildContext context) {
//     final loc = GoRouterState.of(context).matchedLocation;
//     if (loc.startsWith('/home')) return 0;
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
//       backgroundColor: const Color(0xFFF5F5F5),
//       body: child,

//       // ── Yellow centred FAB ─────────────────────────────────────────────
//       floatingActionButton: FloatingActionButton(
//         backgroundColor: const Color(0xFFEAB308),
//         elevation: 6,
//         shape: const CircleBorder(),
//         onPressed: () => _showFeaturedZones(context),
//         child: const Icon(
//           Icons.local_offer_rounded,
//           color: Colors.white,
//           size: 26,
//         ),
//       ),
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

//       // ── Bottom App Bar (notched for FAB) ───────────────────────────────
//       bottomNavigationBar: BottomAppBar(
//         notchMargin: 8.0,
//         shape: const CircularNotchedRectangle(),
//         color: Colors.white,
//         elevation: 8,
//         padding: EdgeInsets.zero,
//         height: 64,
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
//                   ),
//                   _NavItem(
//                     icon: Icons.grid_view_outlined,
//                     activeIcon: Icons.grid_view_rounded,
//                     label: 'Browse',
//                     isSelected: sel == 1,
//                     onTap: () => context.go('/claims'),
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
//                     icon: Icons.notifications_outlined,
//                     activeIcon: Icons.notifications_rounded,
//                     label: 'Alerts',
//                     isSelected: sel == 2,
//                     onTap: () => context.go('/notifications'),
//                   ),
//                   _NavItem(
//                     icon: Icons.person_outline_rounded,
//                     activeIcon: Icons.person_rounded,
//                     label: 'Profile',
//                     isSelected: sel == 3,
//                     onTap: () => context.go('/profile'),
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
//   final IconData icon;
//   final String route;
//   const _ZoneItem({
//     required this.label,
//     required this.icon,
//     required this.route,
//   });
// }

// const _zones = [
//   _ZoneItem(
//     label: 'Reward\nZone',
//     icon: "assets/icons/reward_zone.png",
//     route: '/home',
//   ),
//   _ZoneItem(
//     label: 'Redeem\nZone',
//     icon: Icons.card_giftcard_rounded,
//     route: '/home',
//   ),
//   _ZoneItem(
//     label: 'Brand\nDeals',
//     icon: Icons.diamond_rounded,
//     route: '/claims',
//   ),
//   _ZoneItem(
//     label: 'Nearby\nDeals',
//     icon: Icons.store_rounded,
//     route: '/claims',
//   ),
//   _ZoneItem(
//     label: 'Promo\nReelz',
//     icon: Icons.movie_creation_rounded,
//     route: '/national-ads',
//   ),
//   _ZoneItem(
//     label: 'Local\nClassifieds',
//     icon: Icons.newspaper_rounded,
//     route: '/home',
//   ),
// ];

// class _FeaturedZonesSheet extends StatelessWidget {
//   const _FeaturedZonesSheet();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // ── Drag handle ───────────────────────────────────────────────
//           Container(
//             width: 40,
//             height: 4,
//             margin: const EdgeInsets.only(bottom: 18),
//             decoration: BoxDecoration(
//               color: const Color(0xFFE5E7EB),
//               borderRadius: BorderRadius.circular(2),
//             ),
//           ),

//           // ── Title row ─────────────────────────────────────────────────
//           Row(
//             children: [
//               const Text(
//                 'Featured Zones',
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Color(0xFF1E40AF),
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

//           // ── 3×2 grid ──────────────────────────────────────────────────
//           GridView.count(
//             crossAxisCount: 3,
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             mainAxisSpacing: 16,
//             crossAxisSpacing: 8,
//             childAspectRatio: 0.9,
//             children: _zones
//                 .map((z) => _ZoneTile(
//                       zone: z,
//                       onTap: () {
//                         Navigator.of(context).pop();
//                         if (z.route == '/national-ads') {
//                           context.push(z.route);
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

// // ─────────────────────────────────────────────────────────────────────────────
// // Single zone tile
// // ─────────────────────────────────────────────────────────────────────────────

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
//         children: [
//           // Yellow circle with icon + red badge
//           Stack(
//             clipBehavior: Clip.none,
//             children: [
//               Container(
//                 width: 72,
//                 height: 72,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: const Color(0xFFFEF3C7),
//                   border: Border.all(
//                     color: const Color(0xFFEAB308).withOpacity(0.4),
//                     width: 2,
//                   ),
//                   boxShadow: [
//                     BoxShadow(
//                       color: const Color(0xFFEAB308).withOpacity(0.18),
//                       blurRadius: 10,
//                       offset: const Offset(0, 3),
//                     ),
//                   ],
//                 ),
//                 child: Center(
//                   child: Icon(
//                     zone.icon,
//                     size: 32,
//                     color: const Color(0xFFD97706),
//                   ),
//                 ),
//               ),
//               // Red badge dot top-right
//               Positioned(
//                 top: 2,
//                 right: 2,
//                 child: Container(
//                   width: 14,
//                   height: 14,
//                   decoration: const BoxDecoration(
//                     color: Colors.redAccent,
//                     shape: BoxShape.circle,
//                   ),
//                   child: const Center(
//                     child: Icon(
//                       Icons.close_rounded,
//                       size: 9,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),

//           const SizedBox(height: 8),

//           // Label
//           Text(
//             zone.label,
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//               color: Color(0xFF1F2937),
//               height: 1.3,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Single nav item
// // ─────────────────────────────────────────────────────────────────────────────

// class _NavItem extends StatelessWidget {
//   final IconData icon;
//   final IconData activeIcon;
//   final String label;
//   final bool isSelected;
//   final VoidCallback onTap;

//   const _NavItem({
//     required this.icon,
//     required this.activeIcon,
//     required this.label,
//     required this.isSelected,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final color = isSelected
//         ? AppTheme.secondaryColor
//         : const Color(0xFF9CA3AF);

//     return GestureDetector(
//       onTap: onTap,
//       behavior: HitTestBehavior.opaque,
//       child: SizedBox(
//         width: 64,
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(isSelected ? activeIcon : icon, color: color, size: 24),
//             const SizedBox(height: 3),
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 10,
//                 fontWeight:
//                     isSelected ? FontWeight.w600 : FontWeight.normal,
//                 color: color,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

/// The persistent shell that wraps every main tab.
class HomeScreen extends StatelessWidget {
  final Widget child;
  const HomeScreen({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/home')) return 0;
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: child,

      // ── Yellow centred FAB ─────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFEAB308),
        elevation: 6,
        shape: const CircleBorder(),
        onPressed: () => _showFeaturedZones(context),
        child: Image.asset("assets/icons/main_icon.png")
        //  const Icon(
        //   Icons.local_offer_rounded,
        //   color: Colors.white,
        //   size: 26,
        // ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── Bottom App Bar (notched for FAB) ───────────────────────────────
      bottomNavigationBar: BottomAppBar(
        notchMargin: 8.0,
        shape: const CircularNotchedRectangle(),
        color: const Color.fromARGB(255, 20, 143, 208),
        elevation: 8,
        padding: EdgeInsets.zero,
        height: 64,
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
                  ),
                  _NavItem(
                    icon: Icons.grid_view_outlined,
                    activeIcon: Icons.grid_view_rounded,
                    label: 'Browse',
                    isSelected: sel == 1,
                    onTap: () => context.go('/claims'),
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
                    icon: Icons.notifications_outlined,
                    activeIcon: Icons.notifications_rounded,
                    label: 'Alerts',
                    isSelected: sel == 2,
                    onTap: () => context.go('/notifications'),
                  ),
                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Profile',
                    isSelected: sel == 3,
                    onTap: () => context.go('/profile'),
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
  _ZoneItem(
    label: 'Reward\nZone',
    icon: "assets/icons/popup1.png", 
    route: '/home',
  ),
  _ZoneItem(
    label: 'Redeem\nZone',
    icon: "assets/icons/popup2.png",
    route: '/home',
  ),
  _ZoneItem(
    label: 'Brand\nDeals',
    icon: "assets/icons/popup3.png",
    route: '/claims',
  ),
  _ZoneItem(
    label: 'Nearby\nDeals',
    icon: "assets/icons/popup4.png",
    route: '/claims',
  ),
  _ZoneItem(
    label: 'Promo\nReelz',
    icon: "assets/icons/popup5.png",
    route: '/national-ads',
  ),
  _ZoneItem(
    label: 'Local\nClassifieds',
    icon: "assets/icons/popup6.png",
    route: '/home',
  ),
  
];

class _FeaturedZonesSheet extends StatelessWidget {
  const _FeaturedZonesSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ───────────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Title row ─────────────────────────────────────────────────
          Row(
            children: [
              const Text(
                'Featured Zones',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E40AF),
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

          // ── 3 columns grid ─────────────────────────────────────────────
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 2,       // Reduced from 16 to bring rows closer together
            crossAxisSpacing: 8,
            childAspectRatio: 1.15,   // Increased from 0.85 to squeeze out empty spaces underneath
            children: _zones
                .map((z) => _ZoneTile(
                      zone: z,
                      onTap: () {
                        Navigator.of(context).pop();
                        if (z.route == '/national-ads') {
                          context.push(z.route);
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

// ─────────────────────────────────────────────────────────────────────────────
// Single zone tile
// ─────────────────────────────────────────────────────────────────────────────

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
              // Positioned(
              //   top: -2,
              //   right: -2,
              //   child: Container(
              //     width: 14,
              //     height: 14,
              //     decoration: const BoxDecoration(
              //       color: Colors.redAccent,
              //       shape: BoxShape.circle,
              //     ),
              //     child: const Center(
              //       child: Icon(
              //         Icons.close_rounded,
              //         size: 9,
              //         color: Colors.white,
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),

          const SizedBox(height: 4), // Reduced from 8 to pull the label right below the icon

          // Label
          Text(
            zone.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single nav item
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color color;

    if (widget.isSelected) {
      color = const Color.fromARGB(255, 238, 255, 0); // selected color
    } else if (isHovered) {
      color = Colors.yellow; // hover color
    } else {
      color = const Color.fromARGB(255, 255, 255, 255); // default color
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isSelected
                    ? widget.activeIcon
                    : widget.icon,
                color: color,
                size: 24,
              ),

              const SizedBox(height: 3),

              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
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
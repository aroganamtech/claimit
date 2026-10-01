import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The app's ONE bottom navigation bar.
//
// This is the dashboard's bar, lifted out of home_screen.dart verbatim —
// same BottomAppBar, same notch, same colour, same _NavItem, same routes,
// same responsive sizing. home_screen.dart now calls this too, so there is a
// single definition and the bar on Local Finder / Select / Privilege cannot
// drift away from the one on the home page. A redesign happens here once.
//
// Do not copy this widget. Import it.
// ─────────────────────────────────────────────────────────────────────────────

/// Index of the highlighted destination: 0 Home · 1 Learn · 3 Profile.
/// Anything else (including -1, the default) highlights nothing, which is the
/// right state on a feature screen that is not one of the four destinations.
const int kClaimitNavNone = -1;

/// The yellow centre button that docks into the bar's notch.
///
/// [onTap] is supplied by the caller so that the home page can open its
/// Featured Zones sheet while a feature screen can simply return to the
/// dashboard — the button looks identical either way.
class ClaimitCenterFab extends StatelessWidget {
  final VoidCallback onTap;
  const ClaimitCenterFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Gone while the keyboard is up — see the note on ClaimitBottomBar.
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }
    return _fab();
  }

  Widget _fab() => SizedBox(
        width: 68,
        height: 68,
        child: FloatingActionButton(
          backgroundColor: const Color(0xFFEAB308),
          elevation: 6,
          shape: const CircleBorder(),
          onPressed: onTap,
          child: Image.asset(
            'assets/icons/main_icon.png',
            width: 54,
            height: 54,
            fit: BoxFit.contain,
          ),
        ),
      );
}

class ClaimitBottomBar extends StatelessWidget {
  /// Which destination to highlight; see [kClaimitNavNone].
  final int currentIndex;

  /// Draw the yellow centre button as part of the bar instead of relying on
  /// the Scaffold's docked [ClaimitCenterFab].
  ///
  /// Needed wherever the bar is stacked under something else — the classified
  /// detail page puts a WhatsApp/Call row above it. A `centerDocked` FAB docks
  /// to the top edge of WHATEVER the Scaffold's bottomNavigationBar is, so with
  /// a Column there the button floats above the Call row instead of sitting in
  /// the notch. Passing this instead keeps the button where it belongs.
  ///
  /// Leave it null on a plain screen and use [ClaimitCenterFab] as the
  /// Scaffold's floatingActionButton, exactly as the dashboard does.
  final VoidCallback? onCenterTap;

  const ClaimitBottomBar({
    super.key,
    this.currentIndex = kClaimitNavNone,
    this.onCenterTap,
  });

  /// Lift applied to the right-hand pair, matching the dashboard exactly.
  static const double _kNavLift = 0.0;

  @override
  Widget build(BuildContext context) {
    // ── While the keyboard is open, the whole bar goes away ─────────────────
    // A Scaffold lifts its bottomNavigationBar and its docked FAB clear of the
    // keyboard, so tapping the search field sent the yellow button sliding up
    // to sit on top of the keyboard — detached from the bar it belongs to.
    //
    // Hiding both together is what the design wants and what users expect:
    // the navigation is not reachable while you are typing anyway, and the
    // button never appears anywhere except in its notch.
    //
    // Done here rather than in each screen so it cannot be forgotten on a new
    // one, and so the bar and the button can never disagree about it — they
    // both read the same MediaQuery.
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }

    final bar = _bar(context);
    if (onCenterTap == null) return bar;

    // The button overlaps the bar's top edge by half its height, which is
    // where the notch sits. Clip.none so the overhang is not cut off.
    return SizedBox(
      height: kBottomNavigationBarHeight + 22,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(left: 0, right: 0, bottom: 0, child: bar),
          Positioned(
            top: 0,
            child: ClaimitCenterFab(onTap: onCenterTap!),
          ),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    // Scales with screen width, bounded by clamps. All four items use the same
    // icon size — that is what makes the row line up.
    final iconSize = (screenW * 0.075).clamp(24.0, 28.0);
    final fontSize = (screenW * 0.025).clamp(9.0, 11.0);

    return BottomAppBar(
      notchMargin: 10.0,
      shape: const CircularNotchedRectangle(),
      color: const Color.fromARGB(255, 20, 143, 208),
      elevation: 8,
      padding: EdgeInsets.zero,
      height: kBottomNavigationBarHeight,
      child: Row(
        children: [
          // Left half
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ClaimitNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: currentIndex == 0,
                  onTap: () => context.go('/home'),
                  assetIcon: 'assets/images/nav_home.png',
                  assetActiveIcon: 'assets/images/nav_home.png',
                  iconSize: iconSize,
                  fontSize: fontSize,
                ),
                ClaimitNavItem(
                  icon: Icons.school_outlined,
                  activeIcon: Icons.school_rounded,
                  label: 'Learn',
                  isSelected: currentIndex == 1,
                  onTap: () => context.go('/learn'),
                  assetIcon: 'assets/images/nav_learn.png',
                  assetActiveIcon: 'assets/images/nav_learn.png',
                  iconSize: iconSize,
                  fontSize: fontSize,
                ),
              ],
            ),
          ),

          // Gap for the docked centre button
          const SizedBox(width: 72),

          // Right half
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: _kNavLift),
                  child: ClaimitNavItem(
                    icon: Icons.qr_code_scanner_rounded,
                    activeIcon: Icons.qr_code_scanner_rounded,
                    label: 'Scan Bill',
                    isSelected: false,
                    onTap: () => context.push('/bill-reader'),
                    assetIcon: 'assets/images/nav_scan.png',
                    assetActiveIcon: 'assets/images/nav_scan.png',
                    iconSize: iconSize,
                    fontSize: fontSize,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: _kNavLift),
                  child: ClaimitNavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Profile',
                    isSelected: currentIndex == 3,
                    onTap: () => context.go('/profile'),
                    assetIcon: 'assets/images/nav_profile.png',
                    assetActiveIcon: 'assets/images/nav_profile.png',
                    iconSize: iconSize,
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One destination in [ClaimitBottomBar] — the dashboard's `_NavItem`, made
/// public so the bar could move out of home_screen.dart unchanged.
class ClaimitNavItem extends StatefulWidget {
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

  const ClaimitNavItem({
    super.key,
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
  State<ClaimitNavItem> createState() => _ClaimitNavItemState();
}

class _ClaimitNavItemState extends State<ClaimitNavItem> {
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
                              widget.isSelected
                                  ? widget.activeIcon
                                  : widget.icon,
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
                  fontWeight:
                      widget.isSelected ? FontWeight.bold : FontWeight.w600,
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

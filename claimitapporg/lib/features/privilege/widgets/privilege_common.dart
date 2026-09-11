import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Claimit Privilege — shared palette, header and bottom bar.
//
// The client's mockups used cream and pink. Those are dropped deliberately:
// Privilege lives inside the same app as Reward Zone, Reelz and Select, and a
// second colour system would make it look like a different product bolted on.
// This uses the Claimit brand blue and yellow, with pink kept only for the
// single "% OFF" badge where it earns its place as an accent.
//
// Every text element here is overflow-guarded (Expanded/Flexible + maxLines +
// ellipsis) so a long partner name or a large system font can't produce a
// RenderFlex overflow.
// ─────────────────────────────────────────────────────────────────────────────

const Color kPrivBlue    = Color(0xFF1565C0);  // brand blue — headers, CTAs
const Color kPrivYellow  = Color(0xFFEAB308);  // accent yellow — highlights
const Color kPrivAccent  = Color(0xFFE91E63);  // the % OFF badge only
const Color kPrivInk     = Color(0xFF1E293B);  // primary text
const Color kPrivMuted   = Color(0xFF64748B);  // secondary text
const Color kPrivBg      = Color(0xFFF4F6FA);  // page background
const Color kPrivLine    = Color(0xFFE2E8F0);  // hairlines
const Color kPrivGreen   = Color(0xFF059669);  // approved state

/// The blue "claimit | Privilege" bar every screen shares.
///
/// No drawer and no hamburger — Ramesh asked for both to go. Navigation is the
/// bottom bar plus the system back gesture, which is one less way to get lost.
class PrivilegeHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool showBack;
  final List<Widget>? actions;

  const PrivilegeHeader({super.key, this.showBack = false, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: kPrivBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: showBack ? 0 : 16,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/privilege');
                }
              },
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Exactly as the home screen draws it — height 30, no tint. The
          // white-tint experiment is reverted: one wordmark, one size, drawn
          // the same everywhere.
          Image.asset(
            'assets/images/home_main_logo.png',
            height: 30,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text(
              'claimit',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 9),
          Container(width: 1, height: 20, color: Colors.white38),
          const SizedBox(width: 9),
          const Flexible(
            child: Text(
              'Privilege',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 21,           // up from 17, per the correction sheet
                fontWeight: FontWeight.w800,
                color: kPrivYellow,
              ),
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }
}

/// Bottom bar: Home · Categories · My Privileges · Profile.
/// Matches the client's design for this feature; the app's own four-tab bar
/// stays untouched everywhere else.
class PrivilegeBottomBar extends StatelessWidget {
  final int current;
  const PrivilegeBottomBar({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, String route})>[
      (icon: Icons.home_rounded,        label: 'Home',          route: '/privilege'),
      (icon: Icons.grid_view_rounded,   label: 'Categories',    route: '/privilege/categories'),
      (icon: Icons.local_offer_rounded, label: 'My Privileges', route: '/privilege/history'),
      (icon: Icons.person_rounded,      label: 'Profile',       route: '/profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kPrivLine)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: kBottomNavigationBarHeight,
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (i == current) return;
                      context.go(items[i].route);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(items[i].icon,
                            size: 22,
                            color: i == current ? kPrivBlue : kPrivMuted),
                        const SizedBox(height: 2),
                        // FittedBox so "My Privileges" never wraps a stray
                        // letter onto a second line at a large font scale.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            items[i].label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: i == current
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: i == current ? kPrivBlue : kPrivMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pink "15% OFF" badge from the detail screen.
class PrivilegeBadge extends StatelessWidget {
  final String text;
  final double size;
  const PrivilegeBadge({super.key, required this.text, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: kPrivAccent, shape: BoxShape.circle),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled block on the detail screen (About / Privilege Details / T&C).
class PrivilegeSection extends StatelessWidget {
  final String title;
  final String body;
  const PrivilegeSection({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w700, color: kPrivInk)),
          const SizedBox(height: 5),
          Text(body,
              style: const TextStyle(
                  fontSize: 13.5, color: kPrivMuted, height: 1.5)),
        ],
      ),
    );
  }
}

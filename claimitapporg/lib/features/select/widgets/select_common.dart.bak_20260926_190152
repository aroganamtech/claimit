import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ── Claimit Select palette ────────────────────────────────────────────────────
// Scoped to this feature so nothing else in the app is affected.
//
// Claimit Select is yellow-branded. That needs THREE tokens, not one, because
// yellow works as a background but is unreadable as a foreground on white:
//
//   kSelYellow    → backgrounds: header bars, filled buttons, selected chips
//   kSelOnYellow  → text/icons sitting ON kSelYellow
//   kSelAccent    → text/icons/borders on a WHITE background (links, icons,
//                   outlined buttons, the selected nav tab). A deep gold, so
//                   it stays on-brand while remaining legible.
const Color kSelYellow   = Color(0xFFFFC107);  // brand yellow — backgrounds
const Color kSelOnYellow = Color(0xFF3A2E00);  // on-yellow text/icons
const Color kSelAccent   = Color(0xFF9A6B00);  // deep gold — readable on white
const Color kSelInk      = Color(0xFF1E293B);  // primary text
const Color kSelMuted    = Color(0xFF64748B);  // secondary text
const Color kSelBg       = Color(0xFFF4F6FA);  // page background
const Color kSelLine     = Color(0xFFE2E8F0);  // hairlines / borders

/// "Verified" tick shown next to a professional's name.
class SelVerifiedBadge extends StatelessWidget {
  const SelVerifiedBadge({super.key, this.size = 15});
  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.verified_rounded, size: size, color: kSelAccent);
}

/// Star + rating + review count, e.g. ★ 4.9 (126).
class SelRatingRow extends StatelessWidget {
  const SelRatingRow({
    super.key,
    required this.rating,
    required this.reviewCount,
    this.fontSize = 12.5,
    this.showCount = true,
  });

  final double rating;
  final int reviewCount;
  final double fontSize;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: fontSize + 4, color: const Color(0xFFF5A623)),
        const SizedBox(width: 3),
        Text(
          rating > 0 ? rating.toStringAsFixed(1) : 'New',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: kSelInk,
          ),
        ),
        if (showCount && reviewCount > 0) ...[
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '($reviewCount)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: fontSize, color: kSelMuted),
            ),
          ),
        ],
      ],
    );
  }
}

/// Circular/rounded professional photo with a graceful placeholder — network
/// images can always fail, so every use goes through this.
class SelPhoto extends StatelessWidget {
  const SelPhoto({
    super.key,
    required this.url,
    required this.width,
    this.height,
    this.radius = 12,
  });

  final String url;
  final double width;

  /// Fixed height, or null to fill whatever height the parent gives it.
  /// Passing null is only meaningful inside a bounded parent — e.g. a Row with
  /// `CrossAxisAlignment.stretch` wrapped in `IntrinsicHeight`, which is how
  /// the list card makes the photo match the height of the text beside it.
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    // A null height means "fill" — Container with an alignment expands to its
    // constraints, and BoxFit.cover on the image does the same.
    final fallback = Container(
      width: width,
      height: height,
      color: const Color(0xFFE8EDF5),
      alignment: Alignment.center,
      child: Icon(Icons.person_rounded, size: width * 0.5, color: kSelMuted),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.trim().isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            ),
    );
  }
}

/// The 4-tab bar shown across the Claimit Select screens.
/// All four tabs are live.
class SelectBottomNav extends StatelessWidget {
  const SelectBottomNav({super.key, required this.current});

  /// 0 Home · 1 Bookings · 2 Messages · 3 Profile
  final int current;

  void _go(BuildContext context, int i) {
    if (i == current) return;
    switch (i) {
      case 0:
        context.go('/select');
        break;
      case 1:
        context.go('/select/bookings');
        break;
      case 2:
        context.go('/select/messages');
        break;
      default:
        context.go('/select/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: current,
      onTap: (i) => _go(context, i),
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: kSelAccent,
      unselectedItemColor: kSelMuted,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded), label: 'Bookings'),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_rounded), label: 'Messages'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    );
  }
}

/// Shared empty-state block (no results / nothing booked yet).
class SelEmptyState extends StatelessWidget {
  const SelEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF3FB),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: kSelAccent),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kSelInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kSelMuted, height: 1.5),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

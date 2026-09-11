import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shops/models/shop_category.dart';

// ─────────────────────────────────────────────────────────────────────────────
// "Explore Claimit" — the ten product zones.
//
// These used to live as private lists inside home_screen.dart, reachable only
// through the centre button's popup. The client found that hard to discover,
// so the zones now sit on the home page as a swipeable strip (five at a time)
// AND the routing lives here, in one place.
//
// Keeping the list and the navigation together matters: a zone is opened from
// more than one screen now, and two copies of the tap logic would eventually
// disagree about where a tile goes.
// ─────────────────────────────────────────────────────────────────────────────

class ExploreZone {
  /// Shown under the icon. "\n" splits it across two lines.
  final String label;

  /// Asset path for the illustrated icon.
  final String icon;

  /// Where tapping goes. Empty means "no destination yet" — the tile is still
  /// shown but tells the user it's coming soon rather than doing nothing.
  final String route;

  const ExploreZone({
    required this.label,
    required this.icon,
    required this.route,
  });

  /// Label on one line, for comparisons and for a message to the user.
  String get flatLabel => label.replaceAll('\n', ' ');
}

/// The two zones the centre button offers. Declared on their own because the
/// popup needs them directly, and a const can't be pulled out of a const list
/// by index in Dart.
const ExploreZone kRewardZone =
    ExploreZone(label: 'Reward\nZone', icon: 'assets/images/zone_1.png', route: '/home');
const ExploreZone kRedeemZone =
    ExploreZone(label: 'Redeem\nZone', icon: 'assets/images/zone_2.png', route: '/home');

/// Page 1 of the strip.
const List<ExploreZone> kExploreZonesPage1 = [
  kRewardZone,
  kRedeemZone,
  ExploreZone(label: 'Nearby\nDeals',  icon: 'assets/images/zone_4.png', route: '/nearby-deals'),
  ExploreZone(label: 'Brand\nDeals',   icon: 'assets/images/zone_5.png', route: '/brands'),
  ExploreZone(label: 'Promo\nReelz',   icon: 'assets/images/zone_6.png', route: '/reelz'),
];

/// Page 2 of the strip — swipe left, or tap the arrow.
const List<ExploreZone> kExploreZonesPage2 = [
  ExploreZone(label: 'Local\nFinder',      icon: 'assets/images/zone_3.png',     route: '/classified'),
  ExploreZone(label: 'Claimit\nSelect',    icon: 'assets/images/zone_10.png',    route: '/select'),
  ExploreZone(label: 'Claimit\nPrivilege', icon: 'assets/images/zone_7.png',     route: '/privilege'),
  ExploreZone(label: 'Local\nClassifieds', icon: 'assets/images/zone_8.png',     route: '/classified/ads'),
  ExploreZone(label: 'Learn\nClaimit',     icon: 'assets/images/zone_learn.png', route: '/learn'),
];

/// Open a zone.
///
/// Reward and Redeem don't have routes of their own — both open the shared
/// shop list, configured differently — which is why this can't just be a
/// `context.push(zone.route)` everywhere.
///
/// [popFirst] closes an open popup/sheet before navigating. Pass false when
/// calling from a screen (the home strip), true from inside a dialog.
void openExploreZone(BuildContext context, ExploreZone zone, {bool popFirst = false}) {
  if (popFirst && Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }

  switch (zone.flatLabel) {
    case 'Reward Zone':
      context.push('/shops', extra: const ShopCategory(
        id: 0,
        name: 'Reward Zone',
        icon: Icons.card_membership_rounded,
        color: Color(0xFF2563EB),
      ));
      return;

    case 'Redeem Zone':
      context.push('/shops', extra: {
        'category': const ShopCategory(
          id: -1,
          name: 'Redeem Zone',
          icon: Icons.redeem_rounded,
          color: Color(0xFF059669),
        ),
        'isTab': true,
      });
      return;
  }

  if (zone.route.isEmpty) {
    // No screen for this one yet. Say so, rather than leaving a dead tile.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${zone.flatLabel} is coming soon'),
        duration: const Duration(seconds: 2),
      ),
    );
    return;
  }

  context.push(zone.route);
}

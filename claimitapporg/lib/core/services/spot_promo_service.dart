// ─────────────────────────────────────────────────────────────────────────────
// SpotPromoService — the paid cards in the "Spot Promos" strip.
//
//   GET /spot-promos/nearby   → promos within the selected radius
//
// ONE service, ONE endpoint, ONE collection, read by three screens: Local
// Finder, Claimit Select and Claimit Privilege. That is the product the
// advertiser buys — a single Spot Promo booking appears in the strip on all
// three pages, not three separate placements.
//
// It lives in core/services rather than inside one feature for the same
// reason the card widget does: three copies of this fetch would drift the
// first moment one of them was adjusted, and then the three strips would
// quietly stop showing the same ads.
//
// A short in-memory cache is deliberate. All three pages are reachable from
// the same bottom bar, so a user tapping between them would otherwise refetch
// identical data every time. The cache is keyed on the selected location, so
// changing location invalidates it immediately rather than showing promos for
// where the user used to be.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import '../widgets/spot_promo_card.dart';
import 'location_service.dart';

class SpotPromoDto {
  final String id;
  final String name;
  final String location;
  final String offer;
  final String distance;
  final String category;
  final String imageUrl;
  final String ctaLink;
  final bool isPremium;

  // Shown in the detail sheet when the card is tapped. All optional — a
  // promo with none of them still renders a perfectly good card.
  final String description;
  final String address;
  final String phone;
  final String timing;

  const SpotPromoDto({
    required this.id,
    required this.name,
    required this.location,
    required this.offer,
    required this.distance,
    required this.category,
    required this.imageUrl,
    required this.ctaLink,
    required this.isPremium,
    this.description = '',
    this.address = '',
    this.phone = '',
    this.timing = '',
  });

  factory SpotPromoDto.fromJson(Map<String, dynamic> j) {
    String s(dynamic v) => v == null ? '' : v.toString();
    return SpotPromoDto(
      id:       s(j['id'] ?? j['_id'] ?? j['web_ad_id']),
      name:     s(j['name'] ?? j['title']),
      location: s(j['location'] ?? j['address']),
      offer:    s(j['offer']),
      // The backend attaches `distance` as a formatted label (attach_distance),
      // the same way deals do, so no arithmetic is needed here.
      distance: s(j['distance']),
      category: s(j['category'] ?? j['type']),
      imageUrl: s(j['image_url']),
      ctaLink:  s(j['cta_link']),
      isPremium: s(j['tier']).toLowerCase() == 'premium',
      description: s(j['description']),
      address:  s(j['address']),
      phone:    s(j['phone']),
      timing:   s(j['timing']),
    );
  }

  /// Map onto the shared card model. Kept here, not in each screen, so all
  /// three pages render a promo identically.
  SpotPromo toCard() => SpotPromo(
        id:        id,
        name:      name,
        location:  location,
        offer:     offer,
        distance:  distance,
        category:  category,
        image:     imageUrl,
        isPremium: isPremium,
      );
}

class SpotPromoService {
  SpotPromoService._();
  static final SpotPromoService instance = SpotPromoService._();

  final _api = ApiClient();

  static const _path = '/spot-promos/nearby';

  /// How long a fetch is reused before going back to the network. Short
  /// enough that a newly published promo appears quickly, long enough that
  /// tapping between the three pages doesn't refetch.
  static const _ttl = Duration(minutes: 3);

  List<SpotPromoDto>? _cache;
  String? _cacheKey;
  DateTime? _cacheAt;

  /// Identity of the current location selection. When this changes the cache
  /// is stale by definition — promos are location-scoped, so serving the old
  /// list would show ads for somewhere the user has left.
  String get _locationKey =>
      '${LocationService.selectedLat ?? ''},'
      '${LocationService.selectedLng ?? ''},${LocationService.radiusKm}';

  /// GET /spot-promos/nearby
  ///
  /// Never throws and never returns null: the strip is one section of a page
  /// that has plenty else to show, so a failure here must leave the rest of
  /// the screen working. An empty list simply hides the section.
  Future<List<SpotPromoDto>> fetch({
    String? category,
    bool forceRefresh = false,
  }) async {
    final key = '$_locationKey|${category ?? ''}';
    if (!forceRefresh &&
        _cache != null &&
        _cacheKey == key &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _ttl) {
      return _cache!;
    }

    try {
      final params = <String, dynamic>{};
      if (category != null && category.isNotEmpty) params['category'] = category;
      params.addAll(LocationService.geoParams);

      final resp = await _api.get(_path, queryParams: params);
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['promos'] as List? ?? [];
        final promos = list
            .whereType<Map>()
            .map((j) => SpotPromoDto.fromJson(j.cast<String, dynamic>()))
            .where((p) => p.name.isNotEmpty)
            .toList();
        _cache = promos;
        _cacheKey = key;
        _cacheAt = DateTime.now();
        return promos;
      }
    } catch (e) {
      debugPrint('SpotPromoService.fetch error: $e');
    }
    // Offline or server error: reuse whatever was last loaded for this same
    // location rather than blanking a section that was populated a moment ago.
    if (_cache != null && _cacheKey == key) return _cache!;
    return const [];
  }

  /// Drop the cache — called after a pull-to-refresh so the user's gesture
  /// actually reaches the network.
  void invalidate() {
    _cache = null;
    _cacheKey = null;
    _cacheAt = null;
  }
}

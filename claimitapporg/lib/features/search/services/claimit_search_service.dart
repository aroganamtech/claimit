import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Client for the one search API (backend: app/routes/search.py).
//
// Everything the client's brief asks for goes through here: one search across
// all nine features, measured from the SELECTED location, filtered, sorted and
// paged. Individual feature screens use the same call with `feature` set, so
// the home page and a feature page can never disagree about what is nearby.
// ─────────────────────────────────────────────────────────────────────────────

/// One result. A merchant that belongs to several features arrives as a single
/// card carrying several badges — the de-duplication happens on the server.
class SearchCard {
  final String id;
  final String name;
  final String image;
  final String category;
  final List<String> features;       // machine keys, e.g. reward_zone
  final List<String> featureLabels;  // "Reward Zone"
  final String benefit;              // "15% off", "₹ 68,000"
  final double? distanceKm;          // null when the record has no coordinates
  final String locality;
  final String phone;
  final double? lat;
  final double? lng;
  final bool? isOpen;
  final bool sponsored;

  const SearchCard({
    required this.id,
    required this.name,
    this.image = '',
    this.category = '',
    this.features = const [],
    this.featureLabels = const [],
    this.benefit = '',
    this.distanceKm,
    this.locality = '',
    this.phone = '',
    this.lat,
    this.lng,
    this.isOpen,
    this.sponsored = false,
  });

  /// "3.2 km" — or empty when the listing has no coordinates, in which case
  /// the card simply shows no distance rather than a made-up one.
  String get distanceText =>
      distanceKm == null ? '' : '${distanceKm!.toStringAsFixed(1)} km';

  factory SearchCard.fromJson(Map<String, dynamic> j) => SearchCard(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        image: j['image'] as String? ?? '',
        category: j['category'] as String? ?? '',
        features: (j['features'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        featureLabels:
            (j['feature_labels'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        benefit: j['benefit'] as String? ?? '',
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        locality: j['locality'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        isOpen: j['is_open'] as bool?,
        sponsored: j['sponsored'] as bool? ?? false,
      );
}

/// One feature's slice of the results, for the home screen's sections.
class SearchSection {
  final String feature;
  final String label;
  final int count;
  final List<SearchCard> items;

  const SearchSection({
    required this.feature,
    required this.label,
    required this.count,
    required this.items,
  });

  factory SearchSection.fromJson(Map<String, dynamic> j) => SearchSection(
        feature: j['feature'] as String? ?? '',
        label: j['label'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
        items: ((j['items'] as List?) ?? [])
            .map((e) => SearchCard.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SearchResponse {
  final List<SearchCard> results;
  final List<SearchSection> sections;
  final int total;
  final bool hasMore;
  final bool empty;

  /// Set when nothing was found and a wider radius might help. The app shows
  /// this as an offer; the brief is explicit that the radius must never widen
  /// on its own.
  final double? suggestRadiusKm;
  final String message;

  /// How many nearby listings the "Open Now" filter removed because their
  /// opening hours aren't recorded. Shown so an empty screen can explain
  /// itself instead of looking broken.
  final int hiddenUnknownHours;

  /// True when 5 km had nothing and the server widened to 10 km by itself.
  /// [radiusUsedKm] is the radius the results actually came from, which is
  /// what the header must show — never the radius that was asked for.
  final bool autoExpanded;
  final double radiusUsedKm;

  const SearchResponse({
    this.results = const [],
    this.sections = const [],
    this.total = 0,
    this.hasMore = false,
    this.empty = true,
    this.suggestRadiusKm,
    this.message = '',
    this.hiddenUnknownHours = 0,
    this.autoExpanded = false,
    this.radiusUsedKm = 5.0,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> j) => SearchResponse(
        results: ((j['results'] as List?) ?? [])
            .map((e) => SearchCard.fromJson(e as Map<String, dynamic>))
            .toList(),
        sections: ((j['sections'] as List?) ?? [])
            .map((e) => SearchSection.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        hasMore: j['has_more'] as bool? ?? false,
        empty: j['empty'] as bool? ?? true,
        suggestRadiusKm: (j['suggest_radius_km'] as num?)?.toDouble(),
        message: j['message'] as String? ?? '',
        hiddenUnknownHours: (j['hidden_unknown_hours'] as num?)?.toInt() ?? 0,
        autoExpanded: j['auto_expanded'] as bool? ?? false,
        radiusUsedKm: (j['radius_used_km'] as num?)?.toDouble() ?? 5.0,
      );
}

/// A place the user can choose to search around, with the coordinates that
/// make a radius search possible. [listingCount] is how much Claimit content
/// sits there — shown so the user can tell a busy area from a quiet one.
class PlaceSuggestion {
  final String label;
  final String subLabel;
  final String pincode;
  final double lat;
  final double lng;
  final int listingCount;

  const PlaceSuggestion({
    required this.label,
    this.subLabel = '',
    this.pincode = '',
    required this.lat,
    required this.lng,
    this.listingCount = 0,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> j) => PlaceSuggestion(
        label: j['label'] as String? ?? '',
        subLabel: j['sub_label'] as String? ?? '',
        pincode: j['pincode'] as String? ?? '',
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
        listingCount: (j['listing_count'] as num?)?.toInt() ?? 0,
      );
}

class ClaimitSearchService {
  ClaimitSearchService._();
  static final ClaimitSearchService instance = ClaimitSearchService._();

  final ApiClient _api = ApiClient();

  /// The nine features, in home-screen order. Kept here so a screen can build
  /// filter chips without another network call, and refreshed from
  /// [loadFeatures] when the backend list changes.
  static const List<Map<String, String>> defaultFeatures = [
    {'key': 'reward_zone', 'label': 'Reward Zone'},
    {'key': 'redeem_zone', 'label': 'Redeem Zone'},
    {'key': 'nearby_deals', 'label': 'Nearby Deals'},
    {'key': 'brand_deals', 'label': 'Brand Deals'},
    {'key': 'promo_reelz', 'label': 'Promo Reelz'},
    {'key': 'local_finder', 'label': 'Local Finder'},
    {'key': 'claimit_select', 'label': 'Claimit Select'},
    {'key': 'claimit_privilege', 'label': 'Claimit Privilege'},
    {'key': 'local_classifieds', 'label': 'Local Classifieds'},
  ];

  static const List<Map<String, String>> sortOptions = [
    {'key': 'relevance', 'label': 'Most Relevant'},
    {'key': 'nearest', 'label': 'Nearest'},
    {'key': 'latest', 'label': 'Latest'},
    {'key': 'highest_discount', 'label': 'Highest Discount'},
    {'key': 'popular', 'label': 'Most Popular'},
  ];

  /// Search around a point.
  ///
  /// [lat]/[lng] are the SELECTED location — the caller passes whatever the
  /// user chose, which may be hundreds of kilometres from their phone.
  Future<SearchResponse> search({
    required double lat,
    required double lng,
    double radiusKm = 5.0,
    String? query,
    String? feature,
    String? category,
    bool openNow = false,
    bool hasReward = false,
    bool hasDiscount = false,
    String sort = 'relevance',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final resp = await _api.get('/search', queryParams: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (feature != null && feature.isNotEmpty) 'feature': feature,
        if (category != null && category.isNotEmpty) 'category': category,
        if (openNow) 'open_now': true,
        if (hasReward) 'has_reward': true,
        if (hasDiscount) 'has_discount': true,
        'sort': sort,
        'page': page,
        'limit': limit,
      });
      if (resp.statusCode == 200 && resp.data is Map) {
        return SearchResponse.fromJson(
            Map<String, dynamic>.from(resp.data as Map));
      }
    } catch (e) {
      debugPrint('ClaimitSearchService.search error: $e');
    }
    // An empty response rather than an exception: a search failure should
    // show "nothing found", never crash the screen the user is on.
    return const SearchResponse();
  }

  /// Places to search around, matched against what the user typed.
  ///
  /// These come from Claimit's own data — areas and PIN codes where there are
  /// actually listings — so a user who picks one can never land on a location
  /// that is empty by definition. Each entry carries real coordinates, which
  /// is what lets the radius search work without GPS ever being switched on.
  Future<List<PlaceSuggestion>> places(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final resp = await _api.get('/search/places', queryParams: {
        'q': q,
        'limit': 12,
      });
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = (resp.data['places'] as List?) ?? [];
        return list
            .map((e) =>
                PlaceSuggestion.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('ClaimitSearchService.places error: $e');
    }
    return const [];
  }

  /// Feature and sort lists from the backend, so the chips can't drift out of
  /// step with what the server actually supports. Falls back to the constants
  /// above when offline.
  Future<List<Map<String, String>>> loadFeatures() async {
    try {
      final resp = await _api.get('/search/features');
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = (resp.data['features'] as List?) ?? [];
        if (list.isNotEmpty) {
          return list
              .map((e) => {
                    'key': (e['key'] ?? '').toString(),
                    'label': (e['label'] ?? '').toString(),
                  })
              .toList();
        }
      }
    } catch (e) {
      debugPrint('ClaimitSearchService.loadFeatures error: $e');
    }
    return defaultFeatures;
  }
}

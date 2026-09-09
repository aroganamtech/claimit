// ─────────────────────────────────────────────────────────────────────────────
// Claimit Select — "who is here?" coverage for a city.
//
// Answers the question the category grid can't: is it worth looking here at
// all? Rather than tapping twelve categories to find eleven empty, the user
// sees the counts up front, plus the nearby cities that do have people.
//
// Every field is parsed defensively (`as num?`, `?? 0`) so a missing or
// differently-typed key from an older backend can never crash the screen.
// ─────────────────────────────────────────────────────────────────────────────

/// One category and how many professionals are listed in the city.
class SelectCategoryCount {
  final String id;
  final String label;
  final int count;

  const SelectCategoryCount({
    required this.id,
    required this.label,
    required this.count,
  });

  factory SelectCategoryCount.fromJson(Map<String, dynamic> j) =>
      SelectCategoryCount(
        id: (j['id'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// A city near the one being viewed, and how many professionals it has.
class SelectNearbyCity {
  final String city;
  final int count;
  final double distanceKm;

  const SelectNearbyCity({
    required this.city,
    required this.count,
    required this.distanceKm,
  });

  factory SelectNearbyCity.fromJson(Map<String, dynamic> j) => SelectNearbyCity(
        city: (j['city'] ?? '').toString(),
        count: (j['count'] as num?)?.toInt() ?? 0,
        distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
      );
}

/// The whole coverage answer for one city.
class SelectCoverage {
  final String city;
  final int total;
  final List<SelectCategoryCount> categories;
  final List<SelectNearbyCity> nearby;
  final int nearbyTotal;
  final double radiusKm;

  /// False when the backend had no point to measure from. The screen then says
  /// it couldn't check nearby, rather than implying there is nothing around.
  final bool located;

  const SelectCoverage({
    required this.city,
    required this.total,
    required this.categories,
    required this.nearby,
    required this.nearbyTotal,
    required this.radiusKm,
    required this.located,
  });

  static const empty = SelectCoverage(
    city: '',
    total: 0,
    categories: [],
    nearby: [],
    nearbyTotal: 0,
    radiusKm: 50,
    located: false,
  );

  factory SelectCoverage.fromJson(Map<String, dynamic> j) => SelectCoverage(
        city: (j['city'] ?? '').toString(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        categories: ((j['categories'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SelectCategoryCount.fromJson)
            .toList(),
        nearby: ((j['nearby'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SelectNearbyCity.fromJson)
            .toList(),
        nearbyTotal: (j['nearby_total'] as num?)?.toInt() ?? 0,
        radiusKm: (j['radius_km'] as num?)?.toDouble() ?? 50,
        located: j['located'] == true,
      );
}

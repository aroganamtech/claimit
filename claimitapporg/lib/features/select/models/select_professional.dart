/// A professional listed in Claimit Select (doctor, lawyer, interior designer…).
///
/// Mirrors the payload from GET /select/professionals — every field is parsed
/// defensively so a missing or null value from the server can never crash a
/// screen.
class SelectProfessional {
  final String id;
  final String name;
  final String category;        // stable key, e.g. "interior"
  final String categoryLabel;   // e.g. "Interior Designers"
  final String role;            // shown under the name, e.g. "Interior Designer"
  final String about;
  final int experienceYears;
  final double consultationFee;
  final String photoUrl;
  final List<String> portfolioUrls;
  final List<String> services;
  final List<String> tags;      // e.g. ["Modern", "Minimal", "Luxury"]
  final String phone;
  final String email;
  final String area;
  final String city;
  final String address;
  final String plan;            // premium | standard | custom
  final bool isPremium;
  final bool isVerified;
  final double rating;
  final int reviewCount;
  final String offerText;
  final int offerPercent;
  final String offerValidTill;
  final String distance;        // e.g. "1.2 km" — empty when GPS wasn't sent

  const SelectProfessional({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryLabel,
    required this.role,
    required this.about,
    required this.experienceYears,
    required this.consultationFee,
    required this.photoUrl,
    required this.portfolioUrls,
    required this.services,
    required this.tags,
    required this.phone,
    required this.email,
    required this.area,
    required this.city,
    required this.address,
    required this.plan,
    required this.isPremium,
    required this.isVerified,
    required this.rating,
    required this.reviewCount,
    required this.offerText,
    required this.offerPercent,
    required this.offerValidTill,
    required this.distance,
  });

  /// "Anna Nagar, Chennai" — whichever parts are present.
  String get locationLabel {
    final parts = [area, city].where((s) => s.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  bool get hasOffer => offerText.trim().isNotEmpty || offerPercent > 0;

  static List<String> _stringList(dynamic v) {
    if (v is List) {
      return v.map((e) => (e ?? '').toString()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  factory SelectProfessional.fromJson(Map<String, dynamic> j) {
    return SelectProfessional(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      category: (j['category'] ?? '').toString(),
      categoryLabel: (j['category_label'] ?? '').toString(),
      role: (j['role'] ?? '').toString(),
      about: (j['about'] ?? '').toString(),
      experienceYears: (j['experience_years'] as num?)?.toInt() ?? 0,
      consultationFee: (j['consultation_fee'] as num?)?.toDouble() ?? 0,
      photoUrl: (j['photo_url'] ?? '').toString(),
      portfolioUrls: _stringList(j['portfolio_urls']),
      services: _stringList(j['services']),
      tags: _stringList(j['tags']),
      phone: (j['phone'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      area: (j['area'] ?? '').toString(),
      city: (j['city'] ?? '').toString(),
      address: (j['address'] ?? '').toString(),
      plan: (j['plan'] ?? 'custom').toString(),
      isPremium: j['is_premium'] == true,
      isVerified: j['is_verified'] == true,
      rating: (j['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (j['review_count'] as num?)?.toInt() ?? 0,
      offerText: (j['offer_text'] ?? '').toString(),
      offerPercent: (j['offer_percent'] as num?)?.toInt() ?? 0,
      offerValidTill: (j['offer_valid_till'] ?? '').toString(),
      distance: (j['distance'] ?? '').toString(),
    );
  }
}

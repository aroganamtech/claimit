import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Claimit Privilege — models.
//
// Every field is parsed defensively (`as num?`, `?? ''`) so a missing or
// differently-typed key from an older backend can never crash a screen.
// ─────────────────────────────────────────────────────────────────────────────

/// One of the nine fixed categories on the home grid.
class PrivilegeCategory {
  final String id;
  final String label;

  /// Illustration supplied by the client, as .jpg.
  ///
  /// JPEG has no alpha channel, so each file carries its own near-white
  /// background rather than being cut out. The tiles are white, so that
  /// background is almost invisible — but if these are ever re-exported as
  /// PNG with transparency they will sit cleanly on any colour, and only the
  /// extension here needs to change.
  ///
  /// Every use pairs this with [icon] as an errorBuilder fallback, so a
  /// missing file shows a sensible glyph rather than a broken-image box.
  final String iconAsset;
  final IconData icon;
  final Color color;

  const PrivilegeCategory({
    required this.id,
    required this.label,
    required this.iconAsset,
    required this.icon,
    required this.color,
  });
}

/// The nine categories, in the order the 3x3 home grid draws them.
/// Ids match PRIVILEGE_CATEGORIES in the backend's routes/privilege.py.
const List<PrivilegeCategory> kPrivilegeCategories = [
  PrivilegeCategory(
    id: 'hotels', label: 'Hotels & Resorts',
    iconAsset: 'assets/images/priv_hotels.jpeg',
    icon: Icons.apartment_rounded, color: Color(0xFFF59E0B),
  ),
  PrivilegeCategory(
    id: 'travel', label: 'Tours, Travel & Packages',
    iconAsset: 'assets/images/priv_travel.jpeg',
    icon: Icons.flight_takeoff_rounded, color: Color(0xFF3B82F6),
  ),
  PrivilegeCategory(
    id: 'events', label: 'Wedding & Events',
    iconAsset: 'assets/images/priv_events.jpeg',
    icon: Icons.celebration_rounded, color: Color(0xFFEC4899),
  ),
  PrivilegeCategory(
    id: 'interiors', label: 'Interiors & Furniture',
    iconAsset: 'assets/images/priv_interiors.jpeg',
    icon: Icons.chair_rounded, color: Color(0xFFEF4444),
  ),
  PrivilegeCategory(
    id: 'health', label: 'Healthcare, Dental & Wellness',
    iconAsset: 'assets/images/priv_health.jpeg',
    icon: Icons.medical_services_rounded, color: Color(0xFF10B981),
  ),
  PrivilegeCategory(
    id: 'auto', label: 'Cars, Bikes & Auto Services',
    iconAsset: 'assets/images/priv_auto.jpeg',
    icon: Icons.directions_car_rounded, color: Color(0xFF06B6D4),
  ),
  PrivilegeCategory(
    id: 'education', label: 'Education & Overseas Studies',
    iconAsset: 'assets/images/priv_education.jpeg',
    icon: Icons.school_rounded, color: Color(0xFFEAB308),
  ),
  PrivilegeCategory(
    id: 'property', label: 'Real Estate & Property',
    iconAsset: 'assets/images/priv_property.jpeg',
    icon: Icons.home_work_rounded, color: Color(0xFFA16207),
  ),
  PrivilegeCategory(
    id: 'jewellery', label: 'Jewellery & Premium Retail',
    iconAsset: 'assets/images/priv_jewellery.jpeg',
    icon: Icons.diamond_rounded, color: Color(0xFFD946EF),
  ),
];

/// Looks a category up by id, falling back to the first so a screen can never
/// be handed a null category.
PrivilegeCategory privilegeCategoryById(String id) {
  for (final c in kPrivilegeCategories) {
    if (c.id == id) return c;
  }
  return kPrivilegeCategories.first;
}

/// A partner business offering a privilege discount.
class PrivilegePartner {
  final String id;
  final String name;
  final String category;
  final String categoryLabel;
  final String area;
  final String city;
  final String address;
  final String phone;
  final double discountPercent;
  final String discountLabel;
  final String about;
  final String privilegeDetails;
  final String terms;
  final String photoUrl;
  final List<String> photoUrls;
  final String distance;

  const PrivilegePartner({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryLabel,
    required this.area,
    required this.city,
    required this.address,
    required this.phone,
    required this.discountPercent,
    required this.discountLabel,
    required this.about,
    required this.privilegeDetails,
    required this.terms,
    required this.photoUrl,
    required this.photoUrls,
    required this.distance,
  });

  /// "Up to 15% off" on the list card. Whole numbers render without a
  /// trailing ".0" so the chip reads naturally.
  String get offerChip {
    final p = discountPercent;
    if (p <= 0) return discountLabel.isNotEmpty ? discountLabel : 'Privilege';
    final n = p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(1);
    return 'Up to $n% off';
  }

  String get percentBadge {
    final p = discountPercent;
    final n = p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(1);
    return '$n% OFF';
  }

  factory PrivilegePartner.fromJson(Map<String, dynamic> j) => PrivilegePartner(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        categoryLabel: (j['category_label'] ?? '').toString(),
        area: (j['area'] ?? '').toString(),
        city: (j['city'] ?? '').toString(),
        address: (j['address'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        discountPercent: (j['discount_percent'] as num?)?.toDouble() ?? 0,
        discountLabel: (j['discount_label'] ?? '').toString(),
        about: (j['about'] ?? '').toString(),
        privilegeDetails: (j['privilege_details'] ?? '').toString(),
        terms: (j['terms'] ?? '').toString(),
        photoUrl: (j['photo_url'] ?? '').toString(),
        photoUrls: ((j['photo_urls'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList(),
        distance: (j['distance'] ?? '').toString(),
      );
}

/// A 10-minute eligibility pass, shown at the billing counter.
class PrivilegePass {
  final String reference;
  final String status;          // pending | approved | expired
  final String userName;
  final String userPhone;
  final String userPhotoUrl;
  final String partnerId;
  final String partnerName;
  final String partnerArea;
  final String partnerCity;
  final double discountPercent;
  final String discountLabel;
  final int validMinutes;
  final int secondsLeft;
  final String issuedAt;
  final String approvedAt;

  const PrivilegePass({
    required this.reference,
    required this.status,
    required this.userName,
    required this.userPhone,
    required this.userPhotoUrl,
    required this.partnerId,
    required this.partnerName,
    required this.partnerArea,
    required this.partnerCity,
    required this.discountPercent,
    required this.discountLabel,
    required this.validMinutes,
    required this.secondsLeft,
    required this.issuedAt,
    required this.approvedAt,
  });

  bool get isApproved => status == 'approved';

  String get percentText {
    final p = discountPercent;
    return p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(1);
  }

  factory PrivilegePass.fromJson(Map<String, dynamic> j) => PrivilegePass(
        reference: (j['reference'] ?? '').toString(),
        status: (j['status'] ?? 'pending').toString(),
        userName: (j['user_name'] ?? '').toString(),
        userPhone: (j['user_phone'] ?? '').toString(),
        userPhotoUrl: (j['user_photo_url'] ?? '').toString(),
        partnerId: (j['partner_id'] ?? '').toString(),
        partnerName: (j['partner_name'] ?? '').toString(),
        partnerArea: (j['partner_area'] ?? '').toString(),
        partnerCity: (j['partner_city'] ?? '').toString(),
        discountPercent: (j['discount_percent'] as num?)?.toDouble() ?? 0,
        discountLabel: (j['discount_label'] ?? '').toString(),
        validMinutes: (j['valid_minutes'] as num?)?.toInt() ?? 10,
        secondsLeft: (j['seconds_left'] as num?)?.toInt() ?? 0,
        issuedAt: (j['issued_at'] ?? '').toString(),
        approvedAt: (j['approved_at'] ?? '').toString(),
      );
}

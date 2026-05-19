// ─────────────────────────────────────────────────────────────────────────────
// ShopService
//
// ARCHITECTURE NOTE
// ─────────────────
// All data is currently served from in-memory dummy maps below.
// When the real backend is ready:
//   1. Replace _fetchShopsFromApi() with actual http / dio calls.
//   2. Keep the same public API (Future<List<ShopItem>>), so screens
//      and providers don't change at all.
//
// Each dummy entry mirrors the JSON shape the backend will return:
//   { id, name, location, category_ids, discount, rating,
//     added_days_ago, image_url, has_rewards, has_redeem,
//     address, timing, phone }
//
// Color / IconData are resolved on the client from a category map
// so they never need to travel over the wire.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/shop_list_screen.dart'; // ShopItem lives here for now

class ShopService {
  // Singleton
  ShopService._();
  static final ShopService instance = ShopService._();

  // ── Simulated network delay (remove / reduce for production) ──────────────
  static const _delay = Duration(milliseconds: 400);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns all shops (equivalent to GET /api/shops)
  Future<List<ShopItem>> fetchAllShops() async {
    await Future.delayed(_delay);
    return _fetchShopsFromApi();
  }

  /// Returns shops belonging to a given category
  /// (equivalent to GET /api/shops?category_id=X)
  Future<List<ShopItem>> fetchShopsByCategory(int categoryId) async {
    await Future.delayed(_delay);
    return _fetchShopsFromApi()
        .where((s) => s.categoryIds.contains(categoryId))
        .toList();
  }

  /// Returns a single shop by ID (equivalent to GET /api/shops/:id)
  Future<ShopItem?> fetchShopById(int id) async {
    await Future.delayed(_delay);
    try {
      return _fetchShopsFromApi().firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Full-text search across name / location / address
  /// (equivalent to GET /api/shops/search?q=X)
  Future<List<ShopItem>> searchShops(String query) async {
    await Future.delayed(_delay);
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    return _fetchShopsFromApi()
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.location.toLowerCase().contains(q) ||
            s.address.toLowerCase().contains(q))
        .toList();
  }

  // ── Private: dummy data source ─────────────────────────────────────────────
  // Replace _fetchShopsFromApi() with a real HTTP call when backend is live.
  // The raw map list mirrors the JSON the API will return.

  List<ShopItem> _fetchShopsFromApi() {
    return _shopJsonDummy.map(_fromJson).toList();
  }

  static ShopItem _fromJson(Map<String, dynamic> j) {
    final catEntry = _categoryMeta[j['category_ids'][0]] ??
        _categoryMeta[2]!;
    return ShopItem(
      id: j['id'] as int,
      name: j['name'] as String,
      location: j['location'] as String,
      categoryIds: List<int>.from(j['category_ids'] as List),
      discount: j['discount'] as int,
      rating: (j['rating'] as num).toDouble(),
      addedDaysAgo: j['added_days_ago'] as int,
      imageUrl: j['image_url'] as String,
      fallbackColor: catEntry['color'] as Color,
      fallbackIcon: catEntry['icon'] as IconData,
      hasRewards: j['has_rewards'] as bool? ?? true,
      hasRedeem: j['has_redeem'] as bool? ?? true,
      address: j['address'] as String? ?? '',
      timing: j['timing'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
    );
  }

  // ── Category meta (color + icon lookup) ───────────────────────────────────
  static const Map<int, Map<String, dynamic>> _categoryMeta = {
    1:  {'color': Color(0xFFFFF3E0), 'icon': Icons.local_offer_rounded},
    2:  {'color': Color(0xFFE8F5E9), 'icon': Icons.store_mall_directory_rounded},
    3:  {'color': Color(0xFFFFF3E0), 'icon': Icons.shopping_basket_rounded},
    4:  {'color': Color(0xFFE3F2FD), 'icon': Icons.medical_services_rounded},
    5:  {'color': Color(0xFFFCE4EC), 'icon': Icons.content_cut_rounded},
    6:  {'color': Color(0xFFE8F5E9), 'icon': Icons.fitness_center_rounded},
    7:  {'color': Color(0xFFFFF3E0), 'icon': Icons.restaurant_rounded},
    8:  {'color': Color(0xFFFFF8E1), 'icon': Icons.local_cafe_rounded},
    9:  {'color': Color(0xFFF3E5F5), 'icon': Icons.checkroom_rounded},
    10: {'color': Color(0xFFE8EAF6), 'icon': Icons.apartment_rounded},
    11: {'color': Color(0xFFE3F2FD), 'icon': Icons.devices_rounded},
    12: {'color': Color(0xFFE8F5E9), 'icon': Icons.menu_book_rounded},
    13: {'color': Color(0xFFFFF3E0), 'icon': Icons.toys_rounded},
    14: {'color': Color(0xFFFCE4EC), 'icon': Icons.child_care_rounded},
    15: {'color': Color(0xFFE8EAF6), 'icon': Icons.weekend_rounded},
    16: {'color': Color(0xFFF3E5F5), 'icon': Icons.chair_rounded},
    17: {'color': Color(0xFFFCE4EC), 'icon': Icons.spa_rounded},
    18: {'color': Color(0xFFE3F2FD), 'icon': Icons.school_rounded},
    19: {'color': Color(0xFFE8F5E9), 'icon': Icons.account_balance_rounded},
    20: {'color': Color(0xFFFFF3E0), 'icon': Icons.cast_for_education_rounded},
    21: {'color': Color(0xFFE3F2FD), 'icon': Icons.local_hospital_rounded},
    22: {'color': Color(0xFFFCE4EC), 'icon': Icons.local_hospital_rounded},
    23: {'color': Color(0xFFE8F5E9), 'icon': Icons.pets_rounded},
    24: {'color': Color(0xFFE3F2FD), 'icon': Icons.sports_soccer_rounded},
    25: {'color': Color(0xFFFFF3E0), 'icon': Icons.flight_rounded},
    26: {'color': Color(0xFFE3F2FD), 'icon': Icons.phone_android_rounded},
    27: {'color': Color(0xFFE8EAF6), 'icon': Icons.computer_rounded},
    28: {'color': Color(0xFFFCE4EC), 'icon': Icons.card_giftcard_rounded},
    29: {'color': Color(0xFFFFF8E1), 'icon': Icons.diamond_rounded},
    30: {'color': Color(0xFFE3F2FD), 'icon': Icons.directions_run_rounded},
  };

  // ── Dummy JSON data (mirrors real API response shape) ─────────────────────
  static const List<Map<String, dynamic>> _shopJsonDummy = [
    {
      'id': 1, 'name': 'Indian mart', 'location': 'Padi, Chennai',
      'category_ids': [1, 2, 3], 'discount': 30, 'rating': 4.2,
      'added_days_ago': 2,
      'image_url': 'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=400&q=80',
      'has_rewards': true, 'has_redeem': true,
      'address': '89, Industrial Estate, Padi, Chennai - 600050',
      'timing': 'Daily: 8am – 9pm', 'phone': '+91 44 2651 1234',
    },
    {
      'id': 2, 'name': 'Annachi supermarket', 'location': 'Padi, Chennai',
      'category_ids': [2, 3], 'discount': 20, 'rating': 3.8,
      'added_days_ago': 5,
      'image_url': 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400&q=80',
      'has_rewards': true, 'has_redeem': true,
      'address': '12, 3rd Street, Padi, Chennai - 600050',
      'timing': 'Daily: 7am – 10pm', 'phone': '+91 98765 43210',
    },
    {
      'id': 3, 'name': 'Rathan super store', 'location': 'Padi, Chennai',
      'category_ids': [2, 3], 'discount': 55, 'rating': 4.5,
      'added_days_ago': 1,
      'image_url': 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=400&q=80',
      'has_rewards': true, 'has_redeem': false,
      'address': '45, 2nd Avenue, Padi, Chennai - 600050',
      'timing': 'Mon–Sat: 8am – 9pm', 'phone': '+91 98400 55555',
    },
    {
      'id': 4, 'name': 'Grace supermarket', 'location': 'Padi, Chennai',
      'category_ids': [2, 3], 'discount': 10, 'rating': 3.5,
      'added_days_ago': 10,
      'image_url': 'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=400&q=80',
      'has_rewards': false, 'has_redeem': true,
      'address': '78, Main Road, Padi, Chennai - 600050',
      'timing': 'Daily: 9am – 9pm', 'phone': '+91 44 2651 5678',
    },
    {
      'id': 5, 'name': 'Big bazar', 'location': 'Padi, Chennai',
      'category_ids': [2, 3, 9, 10], 'discount': 30, 'rating': 4.0,
      'added_days_ago': 3,
      'image_url': 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=400&q=80',
      'has_rewards': true, 'has_redeem': true,
      'address': '100, High Road, Padi, Chennai - 600050',
      'timing': 'Daily: 10am – 10pm', 'phone': '+91 44 2651 9999',
    },
    {
      'id': 6, 'name': 'Reliance mart', 'location': 'Padi, Chennai',
      'category_ids': [2, 3, 10], 'discount': 20, 'rating': 4.3,
      'added_days_ago': 7,
      'image_url': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400&q=80',
      'has_rewards': true, 'has_redeem': true,
      'address': '5, 5th Avenue, Anna Nagar, Chennai - 600040',
      'timing': 'Daily: 9am – 9pm', 'phone': '+91 1800 102 0000',
    },
    {
      'id': 7, 'name': 'Kandha super store', 'location': 'Padi, Chennai',
      'category_ids': [1, 2], 'discount': 50, 'rating': 4.8,
      'added_days_ago': 0,
      'image_url': 'https://images.unsplash.com/photo-1518843875459-f738682238a6?w=400&q=80',
      'has_rewards': true, 'has_redeem': true,
      'address': '22, North Street, Padi, Chennai - 600050',
      'timing': 'Daily: 7am – 9pm', 'phone': '+91 98765 11111',
    },
    {
      'id': 8, 'name': 'Daily Fresh', 'location': 'Anna Nagar, Chennai',
      'category_ids': [1, 2], 'discount': 60, 'rating': 4.9,
      'added_days_ago': 0,
      'image_url': 'https://images.unsplash.com/photo-1567306226416-28f0efdc88ce?w=400&q=80',
      'has_rewards': true, 'has_redeem': true,
      'address': '15, 1st Main Road, Anna Nagar, Chennai - 600040',
      'timing': 'Daily: 6am – 10pm', 'phone': '+91 98765 22222',
    },
    {
      'id': 9, 'name': 'Sathya agencies', 'location': 'Padi, Chennai',
      'category_ids': [11, 26, 27], 'discount': 15, 'rating': 4.6,
      'added_days_ago': 4,
      'image_url': 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=400&q=80',
      'has_rewards': true, 'has_redeem': false,
      'address': '101, Padi Main Road, Chennai - 600050',
      'timing': 'Mon–Sat: 9am – 8pm', 'phone': '+91 44 2651 3333',
    },
    {
      'id': 10, 'name': 'Vasanth & Co', 'location': 'Padi, Chennai',
      'category_ids': [11, 26], 'discount': 12, 'rating': 4.1,
      'added_days_ago': 6,
      'image_url': 'https://images.unsplash.com/photo-1550009158-9ebf69173e03?w=400&q=80',
      'has_rewards': true, 'has_redeem': true,
      'address': '55, G.N.T. Road, Padi, Chennai - 600050',
      'timing': 'Daily: 10am – 9pm', 'phone': '+91 44 2651 4444',
    },
    {
      'id': 11, 'name': 'Lakme salon', 'location': 'Anna Nagar, Chennai',
      'category_ids': [5, 17], 'discount': 30, 'rating': 4.7,
      'added_days_ago': 2,
      'image_url': 'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=400&q=80',
      'has_rewards': true, 'has_redeem': true,
      'address': '2nd Avenue, Anna Nagar, Chennai - 600040',
      'timing': 'Daily: 10am – 8pm', 'phone': '+91 98400 77777',
    },
    {
      'id': 12, 'name': 'Green Trends', 'location': 'Padi, Chennai',
      'category_ids': [5], 'discount': 20, 'rating': 4.3,
      'added_days_ago': 9,
      'image_url': 'https://images.unsplash.com/photo-1521590832167-7bcbfaa6381f?w=400&q=80',
      'has_rewards': true, 'has_redeem': false,
      'address': '14, Padi Main Road, Chennai - 600050',
      'timing': 'Tue–Sun: 9am – 8pm', 'phone': '+91 98765 33333',
    },
    {
      'id': 13, 'name': 'Apollo pharmacy', 'location': 'Padi, Chennai',
      'category_ids': [4], 'discount': 10, 'rating': 4.4,
      'added_days_ago': 12,
      'image_url': 'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=400&q=80',
      'has_rewards': false, 'has_redeem': true,
      'address': '33, Padi Main Road, Chennai - 600050',
      'timing': 'Daily: 8am – 10pm', 'phone': '+91 1860 500 0101',
    },
    {
      'id': 14, 'name': 'MedPlus', 'location': 'Padi, Chennai',
      'category_ids': [4], 'discount': 15, 'rating': 4.0,
      'added_days_ago': 8,
      'image_url': 'https://images.unsplash.com/photo-1576602976047-174e57a47881?w=400&q=80',
      'has_rewards': true, 'has_redeem': true,
      'address': '67, Padi 1st Street, Chennai - 600050',
      'timing': 'Daily: 8am – 10pm', 'phone': '+91 40 4444 2424',
    },
    {
      'id': 15, 'name': 'Anytime Fitness', 'location': 'Anna Nagar, Chennai',
      'category_ids': [6], 'discount': 25, 'rating': 4.5,
      'added_days_ago': 3,
      'image_url': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400&q=80',
      'has_rewards': true, 'has_redeem': false,
      'address': '4th Avenue, Anna Nagar, Chennai - 600040',
      'timing': 'Daily: 5am – 11pm', 'phone': '+91 98400 44444',
    },
    {
      'id': 16, 'name': 'Cult.fit', 'location': 'Padi, Chennai',
      'category_ids': [6], 'discount': 20, 'rating': 4.6,
      'added_days_ago': 5,
      'image_url': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&q=80',
      'has_rewards': true, 'has_redeem': true,
      'address': '88, 2nd Main Road, Padi, Chennai - 600050',
      'timing': 'Daily: 6am – 10pm', 'phone': '+91 98765 44444',
    },
    {
      'id': 17, 'name': 'Saravana Bhavan', 'location': 'Padi, Chennai',
      'category_ids': [7], 'discount': 15, 'rating': 4.8,
      'added_days_ago': 1,
      'image_url': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=400&q=80',
      'has_rewards': true, 'has_redeem': true,
      'address': '77, G.N.T. Road, Padi, Chennai - 600050',
      'timing': 'Daily: 6am – 11pm', 'phone': '+91 44 2651 8888',
    },
    {
      'id': 18, 'name': 'Starbucks', 'location': 'Anna Nagar, Chennai',
      'category_ids': [8], 'discount': 20, 'rating': 4.3,
      'added_days_ago': 14,
      'image_url': 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=400&q=80',
      'has_rewards': true, 'has_redeem': false,
      'address': 'Anna Nagar Tower, Chennai - 600040',
      'timing': 'Daily: 8am – 10pm', 'phone': '+91 1800 208 1800',
    },
    {
      'id': 19, 'name': 'Reliance Trends', 'location': 'Padi, Chennai',
      'category_ids': [9, 10], 'discount': 50, 'rating': 4.2,
      'added_days_ago': 0,
      'image_url': 'https://images.unsplash.com/photo-1567401893414-76b7b1e5a7a5?w=400&q=80',
      'has_rewards': true, 'has_redeem': true,
      'address': '200, Padi High Road, Chennai - 600050',
      'timing': 'Daily: 10am – 10pm', 'phone': '+91 1800 102 0000',
    },
    {
      'id': 20, 'name': 'Crossword Books', 'location': 'Anna Nagar, Chennai',
      'category_ids': [12], 'discount': 25, 'rating': 4.4,
      'added_days_ago': 11,
      'image_url': 'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=400&q=80',
      'has_rewards': true, 'has_redeem': false,
      'address': '3rd Avenue, Anna Nagar, Chennai - 600040',
      'timing': 'Daily: 10am – 8pm', 'phone': '+91 98765 55555',
    },
    {
      'id': 21, 'name': 'Tanishq Jewellery', 'location': 'Anna Nagar, Chennai',
      'category_ids': [29], 'discount': 5, 'rating': 4.9,
      'added_days_ago': 20,
      'image_url': 'https://images.unsplash.com/photo-1573408301185-9519f94bf9a2?w=400&q=80',
      'has_rewards': false, 'has_redeem': true,
      'address': 'Anna Nagar Main Road, Chennai - 600040',
      'timing': 'Daily: 10am – 8pm', 'phone': '+91 1800 266 0123',
    },
    {
      'id': 22, 'name': 'Bata Shoes', 'location': 'Padi, Chennai',
      'category_ids': [30], 'discount': 35, 'rating': 4.1,
      'added_days_ago': 7,
      'image_url': 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400&q=80',
      'has_rewards': true, 'has_redeem': true,
      'address': '44, Padi Main Road, Chennai - 600050',
      'timing': 'Daily: 9am – 9pm', 'phone': '+91 33 4400 3333',
    },
    {
      'id': 23, 'name': 'Decathlon Sports', 'location': 'Anna Nagar, Chennai',
      'category_ids': [24, 30], 'discount': 20, 'rating': 4.7,
      'added_days_ago': 15,
      'image_url': 'https://images.unsplash.com/photo-1461897104016-0b3b00cc81ee?w=400&q=80',
      'has_rewards': true, 'has_redeem': false,
      'address': 'Anna Nagar Tower Block, Chennai - 600040',
      'timing': 'Daily: 9am – 9pm', 'phone': '+91 98400 66666',
    },
    {
      'id': 24, 'name': 'Thomas Cook Travel', 'location': 'Anna Nagar, Chennai',
      'category_ids': [25], 'discount': 10, 'rating': 4.2,
      'added_days_ago': 30,
      'image_url': 'https://images.unsplash.com/photo-1488085061387-422e29b40080?w=400&q=80',
      'has_rewards': false, 'has_redeem': true,
      'address': '6th Avenue, Anna Nagar, Chennai - 600040',
      'timing': 'Mon–Sat: 9am – 6pm', 'phone': '+91 98765 66666',
    },
    {
      'id': 25, 'name': 'Archies Gifts', 'location': 'Padi, Chennai',
      'category_ids': [28], 'discount': 30, 'rating': 4.0,
      'added_days_ago': 18,
      'image_url': 'https://images.unsplash.com/photo-1513201099705-a9746e1e201f?w=400&q=80',
      'has_rewards': true, 'has_redeem': true,
      'address': '11, Padi Main Road, Chennai - 600050',
      'timing': 'Daily: 10am – 8pm', 'phone': '+91 98765 77777',
    },
  ];
}

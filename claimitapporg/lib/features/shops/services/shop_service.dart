// ─────────────────────────────────────────────────────────────────────────────
// ShopService — all shop-related API calls
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../screens/shop_list_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Review model
// ─────────────────────────────────────────────────────────────────────────────
class ShopReview {
  final String id;
  final String userName;
  final String? userAvatar; // URL or null
  final double rating;
  final String comment;
  final DateTime date;

  const ShopReview({
    required this.id,
    required this.userName,
    this.userAvatar,
    required this.rating,
    required this.comment,
    required this.date,
  });

  factory ShopReview.fromJson(Map<String, dynamic> j) => ShopReview(
        id: j['id'] ?? j['_id'] ?? '',
        userName: j['user_name'] ?? j['username'] ?? 'User',
        userAvatar: j['user_avatar'],
        rating: ((j['rating'] ?? 0) as num).toDouble(),
        comment: j['comment'] ?? j['review'] ?? '',
        date: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ShopService (singleton)
// ─────────────────────────────────────────────────────────────────────────────
class ShopService {
  ShopService._();
  static final ShopService instance = ShopService._();

  final _api = ApiClient();

  // ── Category fallback metadata ─────────────────────────────────────────────
  static const Map<int, _CatMeta> _catMeta = {
    1:  _CatMeta(Color(0xFFE8F5E9), Icons.local_offer_rounded),
    2:  _CatMeta(Color(0xFFE8F5E9), Icons.shopping_basket_rounded),
    3:  _CatMeta(Color(0xFFFFF3E0), Icons.store_mall_directory_rounded),
    4:  _CatMeta(Color(0xFFE3F2FD), Icons.medical_services_rounded),
    5:  _CatMeta(Color(0xFFFCE4EC), Icons.content_cut_rounded),
    6:  _CatMeta(Color(0xFFE8EAF6), Icons.fitness_center_rounded),
    7:  _CatMeta(Color(0xFFFFF8E1), Icons.restaurant_rounded),
    8:  _CatMeta(Color(0xFFFBE9E7), Icons.local_cafe_rounded),
    9:  _CatMeta(Color(0xFFF3E5F5), Icons.checkroom_rounded),
    10: _CatMeta(Color(0xFFE0F2F1), Icons.shopping_bag_rounded),
    11: _CatMeta(Color(0xFFE8EAF6), Icons.devices_rounded),
    12: _CatMeta(Color(0xFFF9FBE7), Icons.menu_book_rounded),
    13: _CatMeta(Color(0xFFFFF3E0), Icons.toys_rounded),
    14: _CatMeta(Color(0xFFE1F5FE), Icons.child_care_rounded),
    15: _CatMeta(Color(0xFFF3E5F5), Icons.home_rounded),
    16: _CatMeta(Color(0xFFFBE9E7), Icons.chair_rounded),
    17: _CatMeta(Color(0xFFFCE4EC), Icons.spa_rounded),
    18: _CatMeta(Color(0xFFE3F2FD), Icons.school_rounded),
    19: _CatMeta(Color(0xFFE8F5E9), Icons.account_balance_rounded),
    20: _CatMeta(Color(0xFFFFF8E1), Icons.cast_for_education_rounded),
    21: _CatMeta(Color(0xFFE3F2FD), Icons.local_hospital_rounded),
    22: _CatMeta(Color(0xFFE8EAF6), Icons.health_and_safety_rounded),
    23: _CatMeta(Color(0xFFF1F8E9), Icons.pets_rounded),
    24: _CatMeta(Color(0xFFE8EAF6), Icons.sports_rounded),
    25: _CatMeta(Color(0xFFE0F7FA), Icons.flight_rounded),
    26: _CatMeta(Color(0xFFE8EAF6), Icons.phone_android_rounded),
    27: _CatMeta(Color(0xFFE8EAF6), Icons.laptop_rounded),
    28: _CatMeta(Color(0xFFFCE4EC), Icons.card_giftcard_rounded),
    29: _CatMeta(Color(0xFFFFF8E1), Icons.diamond_rounded),
    30: _CatMeta(Color(0xFFF3E5F5), Icons.directions_walk_rounded),
  };

  static _CatMeta _metaFor(List<int> ids) {
    if (ids.isEmpty) return const _CatMeta(Color(0xFFEEEEEE), Icons.store_rounded);
    return _catMeta[ids.first] ?? const _CatMeta(Color(0xFFEEEEEE), Icons.store_rounded);
  }

  // ── Fetch all shops ────────────────────────────────────────────────────────
  Future<List<ShopItem>> fetchAllShops() async {
    try {
      final resp = await _api.get(AppConstants.shops);
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['shops'] as List? ?? [];
        return list.map((j) => _fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('ShopService.fetchAllShops error: $e');
    }
    return [];
  }

  // ── Fetch by category ──────────────────────────────────────────────────────
  Future<List<ShopItem>> fetchShopsByCategory(int categoryId) async {
    try {
      final resp = await _api.get(
        AppConstants.shops,
        queryParams: {'category_id': categoryId},
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['shops'] as List? ?? [];
        return list.map((j) => _fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('ShopService.fetchShopsByCategory error: $e');
    }
    return [];
  }

  // ── Fetch nearby shops by GPS ──────────────────────────────────────────────
  /// [lat], [lng] — user's current coordinates
  /// [radiusKm]   — search radius in km (default 4)
  /// Backend: GET /shops/nearby?lat=X&lng=Y&radius_km=4
  Future<List<ShopItem>> fetchNearbyShops({
    required double lat,
    required double lng,
    double radiusKm = 4.0,
    String? excludeId,
  }) async {
    try {
      final resp = await _api.get(
        AppConstants.shopsNearby,
        queryParams: {
          'lat': lat,
          'lng': lng,
          'radius_km': radiusKm,
          if (excludeId != null) 'exclude_id': excludeId,
        },
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['shops'] as List? ?? [];
        return list.map((j) => _fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('ShopService.fetchNearbyShops error: $e');
    }
    return [];
  }

  // ── Fetch shops near a given location string (area-based) ─────────────────
  /// Used in shop detail to fetch "Stores Nearby" in the same area.
  /// Backend: GET /shops?area=Padi&exclude_id=xxx
  Future<List<ShopItem>> fetchShopsNearArea({
    required String area,
    String? excludeId,
    int limit = 5,
  }) async {
    try {
      final resp = await _api.get(
        AppConstants.shops,
        queryParams: {
          'area': area,
          if (excludeId != null) 'exclude_id': excludeId,
          'limit': limit,
        },
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['shops'] as List? ?? [];
        return list.map((j) => _fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('ShopService.fetchShopsNearArea error: $e');
    }
    return [];
  }

  // ── Single shop by ID ──────────────────────────────────────────────────────
  Future<ShopItem?> fetchShopById(String id) async {
    try {
      final path = AppConstants.shopDetail.replaceFirst('{id}', id);
      final resp = await _api.get(path);
      if (resp.statusCode == 200 && resp.data is Map) {
        final shopJson = resp.data['shop'] as Map<String, dynamic>?;
        if (shopJson != null) return _fromJson(shopJson);
      }
    } catch (e) {
      debugPrint('ShopService.fetchShopById error: $e');
    }
    return null;
  }

  // ── Search shops ───────────────────────────────────────────────────────────
  Future<List<ShopItem>> searchShops(String query) async {
    try {
      final resp = await _api.get(
        AppConstants.shopSearch,
        queryParams: {'q': query},
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['shops'] as List? ?? [];
        return list.map((j) => _fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('ShopService.searchShops error: $e');
    }
    return [];
  }

  // ── Fetch reviews for a shop ───────────────────────────────────────────────
  /// GET /shops/{id}/reviews
  /// Response: { reviews: [...], avg_rating: 4.5, total: 120 }
  Future<({List<ShopReview> reviews, double avgRating, int total})>
      fetchShopReviews(String shopId) async {
    try {
      final path = AppConstants.shopReviews.replaceFirst('{id}', shopId);
      final resp = await _api.get(path);
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = (resp.data['reviews'] as List? ?? [])
            .map((j) => ShopReview.fromJson(Map<String, dynamic>.from(j as Map)))
            .toList();
        final avg = ((resp.data['avg_rating'] ?? 0) as num).toDouble();
        final total = (resp.data['total'] ?? list.length) as int;
        return (reviews: list, avgRating: avg, total: total);
      }
    } catch (e) {
      debugPrint('ShopService.fetchShopReviews error: $e');
    }
    return (reviews: <ShopReview>[], avgRating: 0.0, total: 0);
  }

  // ── Submit a review ────────────────────────────────────────────────────────
  /// POST /shops/{id}/reviews   body: { rating, comment }
  Future<bool> submitReview({
    required String shopId,
    required double rating,
    required String comment,
  }) async {
    try {
      final path = AppConstants.shopReviews.replaceFirst('{id}', shopId);
      final resp = await _api.post(
        path,
        data: {'rating': rating, 'comment': comment},
      );
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      debugPrint('ShopService.submitReview error: $e');
      return false;
    }
  }

  // ── Check redeem eligibility ───────────────────────────────────────────────
  /// POST /redeem/eligibility   body: { shop_id, lat, lng }
  /// Response: { eligible: bool, discount: int, message: str }
  Future<({bool eligible, int discount, String message})>
      checkRedeemEligibility({
    required String shopId,
    double? lat,
    double? lng,
  }) async {
    try {
      final resp = await _api.post(
        AppConstants.redeemEligibility,
        data: {
          'shop_id': shopId,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final eligible = resp.data['eligible'] as bool? ?? false;
        final discount = (resp.data['discount'] ?? 0) as int;
        final message  = resp.data['message'] as String? ?? '';
        return (eligible: eligible, discount: discount, message: message);
      }
    } catch (e) {
      debugPrint('ShopService.checkRedeemEligibility error: $e');
    }
    return (eligible: false, discount: 0, message: 'Could not check eligibility');
  }

  // ── JSON → ShopItem ────────────────────────────────────────────────────────
  ShopItem _fromJson(Map<String, dynamic> j) {
    final categoryIds = (j['category_ids'] as List? ?? [])
        .map((e) => (e as num).toInt())
        .toList();
    final meta = _metaFor(categoryIds);

    final shopType = j['shop_type'] as String?;
    final bool hasRewards;
    final bool hasRedeem;
    if (shopType != null && shopType.isNotEmpty) {
      hasRewards = shopType == 'reward' || shopType == 'both';
      hasRedeem  = shopType == 'redeem' || shopType == 'both';
    } else {
      hasRewards = j['has_rewards'] as bool? ?? true;
      hasRedeem  = j['has_redeem']  as bool? ?? true;
    }

    final rawDist = j['distance'];
    final distance = rawDist != null ? rawDist.toString() : '';

    // Parse carousel image list
    final rawImageList = j['image_data_list'];
    final imageDataList = rawImageList is List
        ? rawImageList.whereType<String>().where((s) => s.isNotEmpty).toList()
        : <String>[];

    return ShopItem(
      id:           j['id']            as String? ?? '',
      name:         j['name']          as String? ?? '',
      location:     j['location']      as String? ?? '',
      categoryIds:  categoryIds,
      discount:     (j['discount']     as num?)?.toInt()    ?? 0,
      rating:       (j['rating']       as num?)?.toDouble() ?? 0.0,
      reviewCount:  (j['review_count'] as num?)?.toInt()    ?? 0,
      addedDaysAgo: (j['added_days_ago'] as num?)?.toInt()  ?? 0,
      imageData:    j['image_data']    as String?,
      imageDataList: imageDataList,
      imageName:    j['image_name']    as String? ?? '',
      fallbackColor: meta.color,
      fallbackIcon:  meta.icon,
      hasRewards:    hasRewards,
      hasRedeem:     hasRedeem,
      about:         j['about']   as String? ?? '',
      address:       j['address'] as String? ?? '',
      timing:        j['timing']  as String? ?? '',
      phone:         j['phone']   as String? ?? '',
      email:         j['email']   as String? ?? '',
      distance:      distance,
      lat:           (j['lat']  as num?)?.toDouble(),
      lng:           (j['lng']  as num?)?.toDouble(),
    );
  }
}

class _CatMeta {
  final Color color;
  final IconData icon;
  const _CatMeta(this.color, this.icon);
}

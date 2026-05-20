// ─────────────────────────────────────────────────────────────────────────────
// ShopService
//
// Fetches shop data from the real FastAPI backend.
// Images are returned as base64 strings from the DB and decoded on the client.
//
// API endpoints used:
//   GET /shops                        → all shops
//   GET /shops?category_id=X          → filtered by category
//   GET /shops/{id}                   → single shop
//   GET /shops/search?q=term          → search
//
// In widgets, render the image with:
//   shop.imageData != null
//     ? Image.memory(base64Decode(shop.imageData!))
//     : Icon(shop.fallbackIcon)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../screens/shop_list_screen.dart'; // ShopItem lives here

class ShopService {
  // Singleton
  ShopService._();
  static final ShopService instance = ShopService._();

  final _api = ApiClient();

  // ── Category fallback map (resolved client-side from category_ids) ─────────
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

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns all shops from the backend (GET /shops).
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

  /// Returns shops filtered by category ID (GET /shops?category_id=X).
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

  /// Returns a single shop by ID (GET /shops/{id}).
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

  /// Search shops by name or location (GET /shops/search?q=term).
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

  // ── JSON → ShopItem ────────────────────────────────────────────────────────

  ShopItem _fromJson(Map<String, dynamic> j) {
    final categoryIds = (j['category_ids'] as List? ?? [])
        .map((e) => (e as num).toInt())
        .toList();
    final meta = _metaFor(categoryIds);

    // Support both explicit booleans (has_rewards / has_redeem) and the
    // shop_type string that the website registration uses:
    //   "reward"  → hasRewards=true,  hasRedeem=false
    //   "redeem"  → hasRewards=false, hasRedeem=true
    //   "both"    → hasRewards=true,  hasRedeem=true
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

    // Distance string from backend, e.g. "6 km" — empty if not provided
    final rawDist = j['distance'];
    final distance = rawDist != null ? rawDist.toString() : '';

    return ShopItem(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      location: j['location'] as String? ?? '',
      categoryIds: categoryIds,
      discount: (j['discount'] as num?)?.toInt() ?? 0,
      rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
      addedDaysAgo: (j['added_days_ago'] as num?)?.toInt() ?? 0,
      imageData: j['image_data'] as String?,   // base64 bytes from MongoDB
      imageName: j['image_name'] as String? ?? '',
      fallbackColor: meta.color,
      fallbackIcon: meta.icon,
      hasRewards: hasRewards,
      hasRedeem: hasRedeem,
      address: j['address'] as String? ?? '',
      timing: j['timing'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      distance: distance,
    );
  }
}

// Helper: category UI metadata (color + icon) resolved client-side
class _CatMeta {
  final Color color;
  final IconData icon;
  const _CatMeta(this.color, this.icon);
}

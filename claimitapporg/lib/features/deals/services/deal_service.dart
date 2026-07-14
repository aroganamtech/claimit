// ─────────────────────────────────────────────────────────────────────────────
// DealService — fetches deal data from the real FastAPI backend.
//
// API endpoints:
//   GET /deals/nearby              → nearby deal group
//   GET /deals/brand               → brand deal group
//   GET /deals/{id}                → single deal detail
//
// Deals use Unsplash image_url (network URLs), not base64 bytes.
// Only shop images are stored as bytes in MongoDB.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';

class DealDto {
  final String id;
  final String name;
  final String location;
  final String offer;
  final String cashback;
  final String distance;
  final String type;
  final String imageUrl;
  final String imageData;
  final String description;
  final String address;
  final String phone;
  final String timing;
  final double rating;
  final int reviews;
  final String dealGroup; // 'nearby' | 'brand'
  final List<String> tags;
  final String tier; // 'premium' | 'standard'
  bool get isPremium => tier == 'premium';

  const DealDto({
    required this.id,
    required this.name,
    required this.location,
    required this.offer,
    required this.cashback,
    required this.distance,
    required this.type,
    required this.imageUrl,
    this.imageData = '',
    required this.description,
    required this.address,
    required this.phone,
    required this.timing,
    required this.rating,
    required this.reviews,
    required this.dealGroup,
    this.tags = const [],
    this.tier = 'standard',
  });

  factory DealDto.fromJson(Map<String, dynamic> j) => DealDto(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        location: j['location'] as String? ?? '',
        offer: j['offer'] as String? ?? '',
        cashback: j['cashback'] as String? ?? '1% Cashback',
        distance: j['distance'] as String? ?? '',
        type: j['type'] as String? ?? '',
        imageUrl: j['image_url'] as String? ?? '',
        imageData: j['image_data'] as String? ?? '',
        description: j['description'] as String? ?? '',
        address: j['address'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        timing: j['timing'] as String? ?? '',
        rating: (j['rating'] as num?)?.toDouble() ?? 4.0,
        reviews: (j['reviews'] as num?)?.toInt() ?? 0,
        dealGroup: j['deal_group'] as String? ?? 'nearby',
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        tier: (j['tier'] as String? ?? 'standard').trim().toLowerCase(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'offer': offer,
        'cashback': cashback,
        'distance': distance,
        'type': type,
        'image_url': imageUrl,
        'description': description,
        'address': address,
        'phone': phone,
        'timing': timing,
        'rating': rating,
        'reviews': reviews,
        'deal_group': dealGroup,
        'tags': tags,
      };
}

class DealService {
  DealService._();
  static final DealService instance = DealService._();

  final _api = ApiClient();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Adds the user's detected area/pincode so the backend can float
  /// local deals to the top of the list (no-op when location unknown).
  void _addLocationParams(Map<String, dynamic> params) {
    if (LocationService.lastArea.isNotEmpty) {
      params['area'] = LocationService.lastArea;
    }
    if (LocationService.lastPincode.isNotEmpty) {
      params['pincode'] = LocationService.lastPincode;
    }
  }

  /// GET /deals/nearby
  Future<List<DealDto>> fetchNearbyDeals({String? category}) async {
    try {
      final params = <String, dynamic>{};
      if (category != null && category.isNotEmpty) params['category'] = category;
      _addLocationParams(params);
      final resp = await _api.get(AppConstants.nearbyDeals, queryParams: params);
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['deals'] as List? ?? [];
        return list.map((j) => DealDto.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('DealService.fetchNearbyDeals error: $e');
    }
    return [];
  }

  /// GET /deals/brand
  Future<List<DealDto>> fetchBrandDeals({String? category}) async {
    try {
      final params = <String, dynamic>{};
      if (category != null && category.isNotEmpty) params['category'] = category;
      _addLocationParams(params);
      final resp = await _api.get(AppConstants.brandDeals, queryParams: params);
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['deals'] as List? ?? [];
        return list.map((j) => DealDto.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('DealService.fetchBrandDeals error: $e');
    }
    return [];
  }

  /// GET /deals  (both groups combined)
  Future<List<DealDto>> fetchAllDeals() async {
    final nearby = await fetchNearbyDeals();
    final brand = await fetchBrandDeals();
    return [...nearby, ...brand];
  }

  /// GET /deals/{id}
  Future<DealDto?> fetchDealById(String id) async {
    try {
      final path = AppConstants.dealDetail.replaceFirst('{id}', id);
      final resp = await _api.get(path);
      if (resp.statusCode == 200 && resp.data is Map) {
        final dealJson = resp.data['deal'] as Map<String, dynamic>?;
        if (dealJson != null) return DealDto.fromJson(dealJson);
      }
    } catch (e) {
      debugPrint('DealService.fetchDealById error: $e');
    }
    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class FavouriteShop {
  final String id;
  final String name;
  final String location;
  final String? imageData; // base64
  final int discount;
  final double rating;

  const FavouriteShop({
    required this.id,
    required this.name,
    required this.location,
    this.imageData,
    required this.discount,
    required this.rating,
  });

  factory FavouriteShop.fromJson(Map<String, dynamic> j) => FavouriteShop(
        id: j['id'] ?? j['_id'] ?? '',
        name: j['name'] ?? '',
        location: j['location'] ?? '',
        imageData: j['image_data'],
        discount: (j['discount'] ?? 0) as int,
        rating: ((j['rating'] ?? 0) as num).toDouble(),
      );
}

class FavouriteDeal {
  final String id;
  final String name;
  final String location;
  final String imageUrl;
  final String offer;

  const FavouriteDeal({
    required this.id,
    required this.name,
    required this.location,
    required this.imageUrl,
    required this.offer,
  });

  factory FavouriteDeal.fromJson(Map<String, dynamic> j) => FavouriteDeal(
        id: j['id'] ?? j['_id'] ?? '',
        name: j['name'] ?? '',
        location: j['location'] ?? '',
        imageUrl: j['image_url'] ?? '',
        offer: j['offer'] ?? '',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ProfileProvider
// ─────────────────────────────────────────────────────────────────────────────
class ProfileProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  // ── Profile update ─────────────────────────────────────────────────────────
  bool _isUpdating = false;
  String? _error;
  bool get isUpdating => _isUpdating;
  String? get error => _error;

  // ── Shop Favourites ────────────────────────────────────────────────────────
  List<FavouriteShop> _favourites = [];
  Set<String> _likedIds = {};
  bool _loadingFavourites = false;

  List<FavouriteShop> get favourites => List.unmodifiable(_favourites);
  Set<String> get likedIds => _likedIds;
  bool get loadingFavourites => _loadingFavourites;
  bool isLiked(String shopId) => _likedIds.contains(shopId);

  // ── Deal Favourites ────────────────────────────────────────────────────────
  List<FavouriteDeal> _dealFavourites = [];
  Set<String> _likedDealIds = {};
  bool _loadingDealFavourites = false;

  List<FavouriteDeal> get dealFavourites => List.unmodifiable(_dealFavourites);
  Set<String> get likedDealIds => _likedDealIds;
  bool get loadingDealFavourites => _loadingDealFavourites;
  bool isLikedDeal(String dealId) => _likedDealIds.contains(dealId);

  // ── Boot-up: load everything ───────────────────────────────────────────────
  Future<void> fetchAll() async {
    await Future.wait([
      fetchLikedIds(),
      fetchLikedDealIds(),
      fetchFavourites(),
      fetchDealFavourites(),
    ]);
  }

  // ── Shop IDs (fast seed) ───────────────────────────────────────────────────
  Future<void> fetchLikedIds() async {
    try {
      final res = await _api.get(AppConstants.getLikedIds);
      if (res.statusCode == 200 && res.data is Map) {
        _likedIds = (res.data['liked_shop_ids'] as List? ?? [])
            .map((e) => e.toString())
            .toSet();
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── Deal IDs (fast seed) ───────────────────────────────────────────────────
  Future<void> fetchLikedDealIds() async {
    try {
      final res = await _api.get(AppConstants.getLikedDealIds);
      if (res.statusCode == 200 && res.data is Map) {
        _likedDealIds = (res.data['liked_deal_ids'] as List? ?? [])
            .map((e) => e.toString())
            .toSet();
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── Full shop details ──────────────────────────────────────────────────────
  Future<void> fetchFavourites() async {
    _loadingFavourites = true;
    notifyListeners();
    try {
      final res = await _api.get(AppConstants.getFavourites);
      if (res.statusCode == 200 && res.data is Map) {
        final list = res.data['shops'] as List? ?? [];
        _favourites = list
            .map((e) => FavouriteShop.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _likedIds = _favourites.map((s) => s.id).toSet();
      }
    } catch (_) {}
    _loadingFavourites = false;
    notifyListeners();
  }

  // ── Full deal details ──────────────────────────────────────────────────────
  Future<void> fetchDealFavourites() async {
    _loadingDealFavourites = true;
    notifyListeners();
    try {
      final res = await _api.get(AppConstants.getDealFavourites);
      if (res.statusCode == 200 && res.data is Map) {
        final list = res.data['deals'] as List? ?? [];
        _dealFavourites = list
            .map((e) => FavouriteDeal.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _likedDealIds = _dealFavourites.map((d) => d.id).toSet();
      }
    } catch (_) {}
    _loadingDealFavourites = false;
    notifyListeners();
  }

  // ── Toggle shop like (optimistic) ──────────────────────────────────────────
  Future<bool> toggleFavourite(
    String shopId, {
    String name = '',
    String location = '',
    String? imageData,
    int discount = 0,
    double rating = 0,
  }) async {
    final wasLiked = _likedIds.contains(shopId);

    // Optimistic update
    if (wasLiked) {
      _likedIds.remove(shopId);
      _favourites.removeWhere((s) => s.id == shopId);
    } else {
      _likedIds.add(shopId);
      _favourites.insert(
        0,
        FavouriteShop(
          id: shopId,
          name: name,
          location: location,
          imageData: imageData,
          discount: discount,
          rating: rating,
        ),
      );
    }
    notifyListeners();

    try {
      final url = AppConstants.toggleFavourite.replaceFirst('{shop_id}', shopId);
      final res = await _api.post(url);
      if (res.statusCode == 200 && res.data is Map) {
        final liked = res.data['liked'] as bool? ?? !wasLiked;
        if (liked != !wasLiked) {
          if (liked) {
            _likedIds.add(shopId);
          } else {
            _likedIds.remove(shopId);
            _favourites.removeWhere((s) => s.id == shopId);
          }
          notifyListeners();
        }
        return liked;
      }
    } catch (_) {
      // Rollback
      if (wasLiked) {
        _likedIds.add(shopId);
        _favourites.insert(
          0,
          FavouriteShop(
            id: shopId,
            name: name,
            location: location,
            imageData: imageData,
            discount: discount,
            rating: rating,
          ),
        );
      } else {
        _likedIds.remove(shopId);
        _favourites.removeWhere((s) => s.id == shopId);
      }
      notifyListeners();
    }
    return !wasLiked;
  }

  // ── Toggle deal like (optimistic) ──────────────────────────────────────────
  Future<bool> toggleDealFavourite(
    String dealId, {
    String name = '',
    String location = '',
    String imageUrl = '',
    String offer = '',
  }) async {
    final wasLiked = _likedDealIds.contains(dealId);

    // Optimistic update
    if (wasLiked) {
      _likedDealIds.remove(dealId);
      _dealFavourites.removeWhere((d) => d.id == dealId);
    } else {
      _likedDealIds.add(dealId);
      _dealFavourites.insert(
        0,
        FavouriteDeal(
          id: dealId,
          name: name,
          location: location,
          imageUrl: imageUrl,
          offer: offer,
        ),
      );
    }
    notifyListeners();

    try {
      final url = AppConstants.toggleDealFavourite.replaceFirst('{deal_id}', dealId);
      final res = await _api.post(url);
      if (res.statusCode == 200 && res.data is Map) {
        final liked = res.data['liked'] as bool? ?? !wasLiked;
        if (liked != !wasLiked) {
          if (liked) {
            _likedDealIds.add(dealId);
          } else {
            _likedDealIds.remove(dealId);
            _dealFavourites.removeWhere((d) => d.id == dealId);
          }
          notifyListeners();
        }
        return liked;
      }
    } catch (_) {
      // Rollback
      if (wasLiked) {
        _likedDealIds.add(dealId);
        _dealFavourites.insert(
          0,
          FavouriteDeal(
            id: dealId,
            name: name,
            location: location,
            imageUrl: imageUrl,
            offer: offer,
          ),
        );
      } else {
        _likedDealIds.remove(dealId);
        _dealFavourites.removeWhere((d) => d.id == dealId);
      }
      notifyListeners();
    }
    return !wasLiked;
  }

  // ── Profile update ─────────────────────────────────────────────────────────
  Future<bool> updateProfile({
    required String fullName,
    String? email,
    String? phone,
    String? dateOfBirth,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? aadharNumber,
    String? panNumber,
  }) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _api.put(
        AppConstants.updateProfile,
        data: {
          'full_name': fullName,
          if (email != null && email.isNotEmpty) 'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (dateOfBirth != null && dateOfBirth.isNotEmpty) 'date_of_birth': dateOfBirth,
          if (address != null && address.isNotEmpty) 'address': address,
          if (city != null && city.isNotEmpty) 'city': city,
          if (state != null && state.isNotEmpty) 'state': state,
          if (pincode != null && pincode.isNotEmpty) 'pincode': pincode,
          if (aadharNumber != null && aadharNumber.isNotEmpty) 'aadhar_number': aadharNumber,
          if (panNumber != null && panNumber.isNotEmpty) 'pan_number': panNumber,
        },
      );
      _isUpdating = false;
      notifyListeners();
      return response.statusCode == 200;
    } catch (e) {
      _error = e.toString();
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadAvatar(String filePath) async {
    _isUpdating = true;
    notifyListeners();
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      });
      final response = await _api.uploadFile(AppConstants.uploadAvatar, formData);
      _isUpdating = false;
      notifyListeners();
      return response.statusCode == 200;
    } catch (e) {
      _error = e.toString();
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }
}

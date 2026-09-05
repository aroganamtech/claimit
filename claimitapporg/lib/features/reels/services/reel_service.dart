import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../models/reel_model.dart';

/// Returned by [ReelService.likeReel] — server-confirmed state.
typedef LikeResult = ({int likeCount, bool likedByMe});

class ReelService {
  ReelService._();
  static final ReelService instance = ReelService._();

  final _api = ApiClient();

  /// GET /reels — includes liked_by_me per authenticated user.
  Future<List<ReelItem>> fetchReels() async {
    try {
      // Send the user's detected area/pincode so local promo reels come first
      final params = <String, dynamic>{};
      if (LocationService.lastArea.isNotEmpty) {
        params['area'] = LocationService.lastArea;
      }
      if (LocationService.lastPincode.isNotEmpty) {
        params['pincode'] = LocationService.lastPincode;
      }
      // Limit to the selected radius, so Promo Reelz matches what the search
      // screen shows. Empty until a location is chosen, and the backend then
      // returns the full list exactly as before.
      params.addAll(LocationService.geoParams);
      final resp = await _api.get(AppConstants.reels, queryParams: params);
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['reels'] as List? ?? [];
        return list
            .map((j) => ReelItem.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('ReelService.fetchReels error: $e');
    }
    return [];
  }

  /// POST /reels/{id}/like
  /// [liked] = true to like, false to unlike.
  /// Returns server-confirmed {likeCount, likedByMe}, or null on failure.
  Future<LikeResult?> likeReel(String id, {required bool liked}) async {
    try {
      final resp = await _api.post(
        '${AppConstants.reels}/$id/like',
        data: {'liked': liked},
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        return (
          likeCount: (resp.data['like_count'] as num?)?.toInt() ?? 0,
          likedByMe: resp.data['liked_by_me'] as bool? ?? liked,
        );
      }
    } catch (e) {
      debugPrint('ReelService.likeReel error: $e');
    }
    return null;
  }

  /// POST /reels/{id}/view — increments view_count.
  /// Returns updated view_count, or null on failure.
  Future<int?> viewReel(String id) async {
    try {
      final resp = await _api.post('${AppConstants.reels}/$id/view');
      if (resp.statusCode == 200 && resp.data is Map) {
        return (resp.data['view_count'] as num?)?.toInt();
      }
    } catch (e) {
      debugPrint('ReelService.viewReel error: $e');
    }
    return null;
  }
}

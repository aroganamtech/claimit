import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../models/reel_model.dart';

/// Returned by [ReelService.likeReel] — server-confirmed state.
typedef LikeResult = ({int likeCount, bool likedByMe});

/// One page of the reel feed. [hasMore] is the server's word for whether
/// another page exists, so the app stops asking instead of guessing from a
/// short page — a page can be short simply because expired reels were
/// filtered out of it.
typedef ReelPage = ({List<ReelItem> reels, bool hasMore});

class ReelService {
  ReelService._();
  static final ReelService instance = ReelService._();

  final _api = ApiClient();

  /// How many reels are fetched per page. Matches the shop list, which has
  /// been running at 10 in production.
  static const int pageSize = 10;

  /// GET /reels — one page, nearest first. [skip] is how many are already
  /// loaded; the server continues the same distance-ordered sequence, so
  /// pages never repeat or skip a reel.
  Future<ReelPage> fetchReelsPage({int skip = 0, int limit = pageSize}) async {
    try {
      // Send the user's detected area/pincode so local promo reels come first
      final params = <String, dynamic>{'skip': skip, 'limit': limit};
      if (LocationService.lastArea.isNotEmpty) {
        params['area'] = LocationService.lastArea;
      }
      if (LocationService.lastPincode.isNotEmpty) {
        params['pincode'] = LocationService.lastPincode;
      }
      // The selected point. Reels are RANKED by distance rather than cut off
      // by the radius, so the feed keeps going — nearest first.
      params.addAll(LocationService.geoParams);
      final resp = await _api.get(AppConstants.reels, queryParams: params);
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['reels'] as List? ?? [];
        return (
          reels: list
              .map((j) => ReelItem.fromJson(j as Map<String, dynamic>))
              .toList(),
          hasMore: resp.data['has_more'] as bool? ?? false,
        );
      }
    } catch (e) {
      debugPrint('ReelService.fetchReelsPage error: $e');
    }
    return (reels: <ReelItem>[], hasMore: false);
  }

  /// First page only. Kept so any existing caller compiles unchanged.
  Future<List<ReelItem>> fetchReels() async =>
      (await fetchReelsPage()).reels;

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

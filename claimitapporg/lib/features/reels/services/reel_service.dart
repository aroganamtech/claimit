import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
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
      final resp = await _api.get(AppConstants.reels);
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

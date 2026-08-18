import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../models/learn_item.dart';

/// Returned by [LearnService.likeItem] — server-confirmed state.
typedef LearnLikeResult = ({int likeCount, bool likedByMe});

class LearnService {
  LearnService._();
  static final LearnService instance = LearnService._();

  final _api = ApiClient();

  /// GET /learn — the list of "Learn Claimit" question+video lessons.
  Future<List<LearnItem>> fetchItems() async {
    try {
      final resp = await _api.get(AppConstants.learn);
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['items'] as List? ?? [];
        return list
            .map((j) => LearnItem.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('LearnService.fetchItems error: $e');
    }
    return [];
  }

  /// POST /learn/{id}/like — [liked] = true to like, false to unlike.
  /// Returns server-confirmed {likeCount, likedByMe}, or null on failure.
  Future<LearnLikeResult?> likeItem(String id, {required bool liked}) async {
    try {
      final resp = await _api.post(
        '${AppConstants.learn}/$id/like',
        data: {'liked': liked},
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        return (
          likeCount: (resp.data['like_count'] as num?)?.toInt() ?? 0,
          likedByMe: resp.data['liked_by_me'] as bool? ?? liked,
        );
      }
    } catch (e) {
      debugPrint('LearnService.likeItem error: $e');
    }
    return null;
  }
}

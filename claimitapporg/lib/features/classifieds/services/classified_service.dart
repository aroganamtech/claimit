import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../models/classified_post.dart';

class ClassifiedService {
  ClassifiedService._();
  static final ClassifiedService instance = ClassifiedService._();

  final _api = ApiClient();

  /// GET /classifieds?category=&subcategory=&search=
  Future<List<ClassifiedPost>> fetchClassifieds({
    String? category,
    String? subcategory,
    String? search,
    String? listingType,   // "local_find" to fetch only Local Finds businesses
  }) async {
    try {
      final params = <String, dynamic>{};
      if (category != null && category.isNotEmpty) params['category'] = category;
      if (subcategory != null && subcategory.isNotEmpty) params['subcategory'] = subcategory;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (listingType != null && listingType.isNotEmpty) params['listing_type'] = listingType;

      final resp = await _api.get(AppConstants.classifieds, queryParams: params);
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['classifieds'] as List? ?? [];
        return list
            .map((j) => ClassifiedPost.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('ClassifiedService.fetchClassifieds error: $e');
    }
    return [];
  }

  /// POST /classifieds — publish a new post
  Future<ClassifiedPost?> createPost(ClassifiedPost post) async {
    try {
      final resp = await _api.post(
        AppConstants.classifieds,
        data: post.toJson(),
      );
      if ((resp.statusCode == 200 || resp.statusCode == 201) && resp.data is Map) {
        final json = resp.data['classified'] as Map<String, dynamic>?;
        if (json != null) return ClassifiedPost.fromJson(json);
      }
    } catch (e) {
      debugPrint('ClassifiedService.createPost error: $e');
    }
    return null;
  }

  /// GET /classifieds/mine — the current user's own posts (for My Listings)
  Future<List<ClassifiedPost>> fetchMyPosts() async {
    try {
      final resp = await _api.get('${AppConstants.classifieds}/mine');
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['classifieds'] as List? ?? [];
        return list
            .map((j) => ClassifiedPost.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('ClassifiedService.fetchMyPosts error: $e');
    }
    return [];
  }

  /// PATCH /classifieds/{id} — edit an existing post (owner only).
  /// Pass only the fields that changed; everything else on the server is
  /// left untouched.
  Future<ClassifiedPost?> updatePost(String id, Map<String, dynamic> fields) async {
    try {
      final resp = await _api.patch(
        '${AppConstants.classifieds}/$id',
        data: fields,
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final json = resp.data['classified'] as Map<String, dynamic>?;
        if (json != null) return ClassifiedPost.fromJson(json);
      }
    } catch (e) {
      debugPrint('ClassifiedService.updatePost error: $e');
    }
    return null;
  }

  /// DELETE /classifieds/{id} — remove a post (owner only)
  Future<bool> deletePost(String id) async {
    try {
      final resp = await _api.delete('${AppConstants.classifieds}/$id');
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('ClassifiedService.deletePost error: $e');
      return false;
    }
  }

  /// PATCH /classifieds/{id}/toggle — flip availability (owner only)
  Future<bool?> toggleAvailability(String id) async {
    try {
      final resp = await _api.patch('${AppConstants.classifieds}/$id/toggle');
      if (resp.statusCode == 200 && resp.data is Map) {
        return resp.data['is_available'] as bool?;
      }
    } catch (e) {
      debugPrint('ClassifiedService.toggleAvailability error: $e');
    }
    return null;
  }
}

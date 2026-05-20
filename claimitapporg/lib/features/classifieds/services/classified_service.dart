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
  }) async {
    try {
      final params = <String, dynamic>{};
      if (category != null && category.isNotEmpty) params['category'] = category;
      if (subcategory != null && subcategory.isNotEmpty) params['subcategory'] = subcategory;
      if (search != null && search.isNotEmpty) params['search'] = search;

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
}

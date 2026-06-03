import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get(AppConstants.notifications);
      if (response.statusCode == 200) {
        final data = response.data as List<dynamic>;
        _notifications = data.map((e) => NotificationModel.fromJson(e)).toList();
        _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _apiClient.patch('/notifications/$notificationId/read');
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final n = _notifications[index];
        _notifications[index] = NotificationModel(
          id: n.id, userId: n.userId, title: n.title,
          message: n.message, type: n.type, isRead: true,
          claimId: n.claimId, reviewId: n.reviewId, createdAt: n.createdAt,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiClient.patch(AppConstants.markAllRead);
      _notifications = _notifications.map((n) => NotificationModel(
        id: n.id, userId: n.userId, title: n.title,
        message: n.message, type: n.type, isRead: true,
        claimId: n.claimId, reviewId: n.reviewId, createdAt: n.createdAt,
      )).toList();
      notifyListeners();
    } catch (_) {}
  }
}

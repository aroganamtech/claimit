// ─────────────────────────────────────────────────────────────────────────────
// NotificationService
//
// ARCHITECTURE NOTE
// ─────────────────
// Data is served from in-memory dummy maps below.
// When the real backend is ready:
//   1. Replace _fetchFromApi() with actual http / dio calls.
//   2. Keep the same public API (Future<List<NotificationDto>>).
//
// Each entry mirrors the JSON shape the backend will return:
//   { id, user_id, type, title, message, is_read, created_at }
//
// 'type' values: 'alert' | 'offer' | 'reminder'
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

class NotificationDto {
  final String id;
  final String userId;
  final String type; // alert | offer | reminder
  final String title;
  final String message;
  final bool isRead;
  final String createdAt; // ISO-8601 or relative string

  const NotificationDto({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationDto.fromJson(Map<String, dynamic> j) {
    return NotificationDto(
      id: j['id'] as String,
      userId: j['user_id'] as String? ?? '',
      type: j['type'] as String? ?? 'alert',
      title: j['title'] as String,
      message: j['message'] as String,
      isRead: j['is_read'] as bool? ?? false,
      createdAt: j['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'title': title,
        'message': message,
        'is_read': isRead,
        'created_at': createdAt,
      };
}

class NotificationService {
  // Singleton
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _delay = Duration(milliseconds: 350);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// GET /api/notifications?user_id=X
  Future<List<NotificationDto>> fetchNotifications(String userId) async {
    await Future.delayed(_delay);
    return _fetchFromApi()
        .where((n) => n.userId == userId || n.userId.isEmpty)
        .toList();
  }

  /// PATCH /api/notifications/:id/read
  Future<void> markAsRead(String notificationId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    // Real backend: PATCH request
  }

  /// PATCH /api/notifications/mark-all-read?user_id=X
  Future<void> markAllAsRead(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Real backend: PATCH request
  }

  /// DELETE /api/notifications/:id
  Future<void> deleteNotification(String notificationId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    // Real backend: DELETE request
  }

  // ── Private: dummy data source ─────────────────────────────────────────────

  List<NotificationDto> _fetchFromApi() {
    return _notifJsonDummy.map(NotificationDto.fromJson).toList();
  }

  static const List<Map<String, dynamic>> _notifJsonDummy = [
    {
      'id': 'n1',
      'user_id': '',
      'type': 'offer',
      'title': 'Flash Sale Alert 🔥',
      'message': 'Reliance Trends is offering 50% OFF today only. Hurry — ends at midnight!',
      'is_read': false,
      'created_at': '2 min ago',
    },
    {
      'id': 'n2',
      'user_id': '',
      'type': 'offer',
      'title': 'Reward Points Added',
      'message': 'You earned 120 points from your last bill scan at Big Bazaar. Keep scanning!',
      'is_read': false,
      'created_at': '18 min ago',
    },
    {
      'id': 'n3',
      'user_id': '',
      'type': 'reminder',
      'title': 'Scan Bill Reminder',
      'message': 'Did you shop recently? Don\'t forget to scan your bill to earn reward points.',
      'is_read': false,
      'created_at': '1 hr ago',
    },
    {
      'id': 'n4',
      'user_id': '',
      'type': 'alert',
      'title': 'New Shop Nearby',
      'message': 'Sathya Agencies just joined claimit. Visit and earn rewards on every purchase!',
      'is_read': false,
      'created_at': '3 hrs ago',
    },
    {
      'id': 'n5',
      'user_id': '',
      'type': 'offer',
      'title': 'Exclusive Offer for You',
      'message': 'Lakme Salon is offering an exclusive 30% discount for claimit members this week.',
      'is_read': true,
      'created_at': '5 hrs ago',
    },
    {
      'id': 'n6',
      'user_id': '',
      'type': 'reminder',
      'title': 'Points Expiring Soon',
      'message': '200 reward points will expire in 3 days. Redeem them before they\'re gone!',
      'is_read': false,
      'created_at': 'Yesterday',
    },
    {
      'id': 'n7',
      'user_id': '',
      'type': 'reminder',
      'title': 'Friend Joined claimit',
      'message': 'Your friend Priya joined claimit using your referral. You both earned 50 bonus points!',
      'is_read': true,
      'created_at': 'Yesterday',
    },
    {
      'id': 'n8',
      'user_id': '',
      'type': 'alert',
      'title': 'App Update Available',
      'message': 'A new version of claimit (v2.1) is available. Update now for the best experience.',
      'is_read': true,
      'created_at': '2 days ago',
    },
    {
      'id': 'n9',
      'user_id': '',
      'type': 'alert',
      'title': 'Delivery Update',
      'message': 'Your redeemed item has been dispatched. Expected delivery: 2–3 business days.',
      'is_read': true,
      'created_at': '3 days ago',
    },
    {
      'id': 'n10',
      'user_id': '',
      'type': 'offer',
      'title': 'Weekly Rewards Summary',
      'message': 'This week you earned 340 points across 5 stores. You\'re on a great streak!',
      'is_read': true,
      'created_at': '5 days ago',
    },
  ];
}

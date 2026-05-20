// ─────────────────────────────────────────────────────────────────────────────
// api_config.dart  —  Central API configuration
//
// SWITCH FROM DUMMY → REAL BACKEND
// ──────────────────────────────────
// 1. Set USE_DUMMY_DATA = false
// 2. Set BASE_URL to your production/staging server
// 3. Each service class reads kUseDummyData and calls the real endpoint
//    when it's false.  The public Future<T> API stays the same, so
//    widgets and providers don't need to change.
//
// Services to update when backend is ready:
//   • lib/features/shops/services/shop_service.dart
//       → GET /api/shops
//       → GET /api/shops?category_id=X
//       → GET /api/shops/:id
//       → GET /api/shops/search?q=X
//
//   • lib/features/notifications/services/notification_service.dart
//       → GET  /api/notifications?user_id=X
//       → PATCH /api/notifications/:id/read
//       → PATCH /api/notifications/mark-all-read?user_id=X
//       → DELETE /api/notifications/:id
//
//   • lib/features/deals/services/deal_service.dart
//       → GET /api/deals
//       → GET /api/deals?group=nearby
//       → GET /api/deals?group=brand
//       → GET /api/deals/:id
// ─────────────────────────────────────────────────────────────────────────────

class ApiConfig {
  ApiConfig._();

  /// Toggle: true = serve dummy in-memory data
  ///         false = call real HTTP endpoints (backend is now ready with seed data)
  static const bool kUseDummyData = false;

  /// Base URL — set this to your real server when ready
  static const String kBaseUrl = 'https://api.claimit.in/v1';

  /// Simulated network delay for dummy mode (makes the UI behave realistically)
  static const Duration kDummyDelay = Duration(milliseconds: 400);

  /// HTTP timeout for real API calls
  static const Duration kRequestTimeout = Duration(seconds: 15);

  /// Auth token header name
  static const String kAuthHeader = 'Authorization';
}

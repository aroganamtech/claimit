class AppConstants {
  // API Base URL — pick the line that matches how you run the app:
  // static const String baseUrl = 'http://10.0.2.2:8001';   // Android emulator
  // static const String baseUrl = 'http://localhost:8001';   // iOS simulator
  static const String baseUrl = 'http://10.103.197.67:8001'; // ← update your IP

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String sendOtp        = '/auth/send-otp';
  static const String verifyOtp      = '/auth/verify-otp';
  static const String register       = '/auth/register';
  static const String login          = '/auth/login';
  static const String logout         = '/auth/logout';
  static const String refreshToken   = '/auth/refresh';

  // ── Users / Profile ───────────────────────────────────────────────────────
  static const String profile        = '/users/profile';
  static const String updateProfile  = '/users/profile/update';
  static const String uploadAvatar   = '/users/avatar';
  static const String updateLocation = '/users/location';

  // ── Locations ─────────────────────────────────────────────────────────────
  static const String popularLocations = '/locations/popular';

  // ── Deals ─────────────────────────────────────────────────────────────────
  static const String nearbyDeals = '/deals/nearby';
  static const String brandDeals  = '/deals/brand';
  static const String dealDetail  = '/deals/{id}';

  // ── Claims ────────────────────────────────────────────────────────────────
  static const String claims          = '/claims';
  static const String createClaim     = '/claims/create';
  static const String claimDetail     = '/claims/{id}';
  static const String uploadDocument  = '/claims/{id}/documents';
  static const String claimTimeline   = '/claims/{id}/timeline';

  // ── Notifications ─────────────────────────────────────────────────────────
  static const String notifications       = '/notifications';
  static const String markNotificationRead = '/notifications/{id}/read';
  static const String markAllRead         = '/notifications/read-all';

  // ── Dashboard / Policies ──────────────────────────────────────────────────
  static const String dashboard = '/dashboard';
  static const String policies  = '/policies';

  // ── Shops ─────────────────────────────────────────────────────────────────
  static const String shops        = '/shops';
  static const String shopDetail   = '/shops/{id}';
  static const String shopImage    = '/shops/{id}/image';
  static const String shopSearch   = '/shops/search';
  /// GET /shops/nearby?lat=X&lng=Y&radius_km=4  → { shops: [...] }
  static const String shopsNearby  = '/shops/nearby';

  // ── Shop Reviews ──────────────────────────────────────────────────────────
  /// GET  /shops/{id}/reviews              → { reviews: [...], avg_rating, total }
  /// POST /shops/{id}/reviews              → { review: {...} }
  static const String shopReviews  = '/shops/{id}/reviews';

  // ── Rewards ───────────────────────────────────────────────────────────────
  static const String rewards       = '/rewards';
  static const String rewardsByShop = '/rewards/shop/{shop_id}';
  static const String rewardDetail  = '/rewards/{id}';

  // ── Redeem ────────────────────────────────────────────────────────────────
  static const String redeemReward  = '/redeem';
  static const String myRedeems     = '/redeem/my';
  static const String markRedeemUsed = '/redeem/{id}/use';
  /// POST /redeem/eligibility  body: { shop_id, lat, lng }
  /// → { eligible: bool, discount: int, message: str, shop: {...} }
  static const String redeemEligibility = '/redeem/eligibility';

  // ── Shop Favourites ───────────────────────────────────────────────────────
  static const String toggleFavourite = '/users/favourites/{shop_id}';
  static const String getFavourites   = '/users/favourites';
  static const String getLikedIds     = '/users/liked-ids';

  // ── Deal Favourites ───────────────────────────────────────────────────────
  static const String toggleDealFavourite = '/users/deal-favourites/{deal_id}';
  static const String getDealFavourites   = '/users/deal-favourites';
  static const String getLikedDealIds     = '/users/liked-deal-ids';

  // ── Reels ─────────────────────────────────────────────────────────────────
  static const String reels = '/reels';

  // ── Classifieds ───────────────────────────────────────────────────────────
  static const String classifieds    = '/classifieds';
  static const String classifiedDetail = '/classifieds/{id}';

  // Bill scan
  static const String billScan = '/bill/scan';

  // ── Storage Keys ──────────────────────────────────────────────────────────
  static const String tokenKey        = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey       = 'user_id';
  static const String userDataKey     = 'user_data';

  // ── Claim Types ───────────────────────────────────────────────────────────
  static const List<String> claimTypes = [
    'Health Insurance',
    'Motor Insurance',
    'Home Insurance',
    'Life Insurance',
    'Travel Insurance',
    'Property Insurance',
  ];

  // ── Claim Status ──────────────────────────────────────────────────────────
  static const String statusPending    = 'pending';
  static const String statusUnderReview = 'under_review';
  static const String statusApproved   = 'approved';
  static const String statusRejected   = 'rejected';
  static const String statusSettled    = 'settled';

  // ── Dev only ──────────────────────────────────────────────────────────────
  static const String staticOtp = '123456';
}

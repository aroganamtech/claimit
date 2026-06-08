class AppConstants {
  // ── API Base URL ───────────────────────────────────────────────────────────
  // Comment/uncomment the line you need:

  // 🌐 Production (Vercel) — use this when testing on a real device / LTE
  static const String baseUrl = 'https://claimitorgbackend.vercel.app';
//    static const String baseUrl = 'http://13.63.176.113:8001';

  // 💻 Local dev — only works when phone is on the SAME WiFi as your PC
  // static const String baseUrl = 'http://10.204.99.28:8001';
  // static const String baseUrl = 'http://10.0.2.2:8001';   // Android emulator
  // static const String baseUrl = 'http://localhost:8001';   // iOS simulator

  // ── Legal & Support (public pages — also required for Play Store listing) ──
  static const String privacyPolicyUrl = 'https://www.claimitapp.in/privacy-policy';
  static const String termsUrl         = 'https://www.claimitapp.in/terms';
  static const String supportUrl       = 'https://www.claimitapp.in/support';
  static const String refundPolicyUrl  = 'https://www.claimitapp.in/refund-policy';
  static const String supportEmail     = 'support@claimitapp.in';

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String sendOtp        = '/auth/send-otp';
  static const String verifyOtp      = '/auth/verify-otp';
  static const String register       = '/auth/register';
  static const String login          = '/auth/login';
  static const String logout         = '/auth/logout';
  static const String refreshToken   = '/auth/refresh';
  /// POST { provider: 'google'|'facebook', name, email?, provider_id? }
  /// Returns { access_token, refresh_token, user }
  static const String socialLogin    = '/auth/social/login';
  /// POST { phone } — lets social-login users add a phone number
  static const String updatePhone    = '/users/profile/phone';

  // ── Social OAuth Keys ─────────────────────────────────────────────────────
  // Pass real values via dart-define:
  //   flutter run --dart-define=GOOGLE_CLIENT_ID=xxx --dart-define=FACEBOOK_APP_ID=yyy
  // or replace the defaultValue strings below before release.
  static const String googleClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID',
          defaultValue: '665581452240-239kicsrfucc5j2umem8h3fihhhgjv04.apps.googleusercontent.com');
  static const String googleClientIdIos =
      String.fromEnvironment('GOOGLE_CLIENT_ID_IOS',
          defaultValue: 'DUMMY_GOOGLE_IOS_CLIENT_ID.apps.googleusercontent.com');
  static const String facebookAppId =
      String.fromEnvironment('FACEBOOK_APP_ID', defaultValue: '000000000000000');
  static const String facebookClientToken =
      String.fromEnvironment('FACEBOOK_CLIENT_TOKEN',
          defaultValue: 'DUMMY_FACEBOOK_CLIENT_TOKEN');

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

  // ── Gemini AI Vision (for bill OCR) ──────────────────────────────────────
  // Replace with your Google AI Studio key from https://aistudio.google.com/
  static const String geminiApiKey =
      'YOUR_GEMINI_API_KEY_HERE'; // ← paste your key
  static const String geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

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

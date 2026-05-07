class AppConstants {
  // API Base URL - change to your server IP/domain
  static const String baseUrl = 'http://10.0.2.2:8001'; // Android emulator
  // static const String baseUrl = 'http://localhost:8001'; // iOS simulator
  // static const String baseUrl = 'http://YOUR_SERVER_IP:8001'; // Physical device

  // API Endpoints
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';

  static const String profile = '/users/profile';
  static const String updateProfile = '/users/profile/update';
  static const String uploadAvatar = '/users/avatar';

  static const String claims = '/claims';
  static const String createClaim = '/claims/create';
  static const String claimDetail = '/claims/{id}';
  static const String uploadDocument = '/claims/{id}/documents';
  static const String claimTimeline = '/claims/{id}/timeline';

  static const String notifications = '/notifications';
  static const String markNotificationRead = '/notifications/{id}/read';
  static const String markAllRead = '/notifications/read-all';

  static const String dashboard = '/dashboard';
  static const String policies = '/policies';

  // Storage Keys
  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String userDataKey = 'user_data';

  // Claim Types
  static const List<String> claimTypes = [
    'Health Insurance',
    'Motor Insurance',
    'Home Insurance',
    'Life Insurance',
    'Travel Insurance',
    'Property Insurance',
  ];

  // Claim Status
  static const String statusPending = 'pending';
  static const String statusUnderReview = 'under_review';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';
  static const String statusSettled = 'settled';

  // OTP
  static const int otpLength = 6;
  static const int otpResendSeconds = 60;

  // Pagination
  static const int pageSize = 10;
}

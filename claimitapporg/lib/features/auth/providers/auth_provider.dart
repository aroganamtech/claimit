import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  UserModel? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _error;

  /// The identifier (phone/email) the user typed at login — set by verifyOtp()
  String? _loginIdentifier;
  /// Becomes true right after a successful login; reset once popup is shown
  bool _accountLinkPopupPending = false;
  /// 'phone' | 'email' | 'google' | 'facebook'
  String? _loginMethod;

  UserModel? get user => _user;
  /// Exposed so screens needing direct API calls (e.g. social complete-profile)
  /// can reuse the authenticated ApiClient without duplicating interceptors.
  ApiClient get apiClientForSocial => _apiClient;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get error => _error;
  String? get loginMethod => _loginMethod;

  /// True after Facebook login when the user still hasn't provided phone or email.
  /// The router forces them to /auth/complete-profile until both are set.
  bool get needsProfileCompletion {
    if (_loginMethod != 'facebook') return false;
    if (_user == null) return false;
    final noPhone = _user!.phone.isEmpty;
    final noEmail = _user!.email == null || _user!.email!.isEmpty;
    return noPhone || noEmail;
  }

  /// True if the most recent login was via email address
  bool get loggedInViaEmail =>
      _loginIdentifier != null && _loginIdentifier!.contains('@');

  /// True if the most recent login was via phone number
  bool get loggedInViaPhone =>
      _loginIdentifier != null && !_loginIdentifier!.contains('@');

  /// Whether the account-linking nudge popup should be shown.
  /// Phone login but no email → nudge to add email.
  /// Email login but no phone → nudge to add phone.
  bool get shouldShowAccountLinkPopup {
    if (!_accountLinkPopupPending || _user == null) return false;
    if (loggedInViaPhone && (_user!.email == null || _user!.email!.isEmpty)) {
      return true;
    }
    if (loggedInViaEmail && _user!.phone.isEmpty) {
      return true;
    }
    return false;
  }

  /// Call this once the popup has been displayed so it isn't shown again
  /// in the same session.
  void markAccountLinkPopupShown() {
    _accountLinkPopupPending = false;
    // no notifyListeners() needed — the popup reads this synchronously
  }

  /// Used as GoRouter's refreshListenable.
  /// ONLY fires when _isAuthenticated actually changes — never on loading/error
  /// state changes — so the router never re-evaluates redirects mid-request.
  final ValueNotifier<bool> authStateNotifier = ValueNotifier<bool>(false);

  /// Sets _isAuthenticated and notifies the router notifier only when the
  /// value actually changes.
  void _setAuth(bool value) {
    if (_isAuthenticated == value) return;
    _isAuthenticated = value;
    authStateNotifier.value = value;
  }

  AuthProvider() {
    _checkAuthStatus();
  }

  @override
  void dispose() {
    authStateNotifier.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final token = await _apiClient.getToken();
      if (token != null && token.isNotEmpty) {
        await fetchUserProfile();
      }
    } catch (_) {
      // Ignore — user just won't be authenticated.
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  String _extractError(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) return data['detail'].toString();
      return e.message ?? fallback;
    }
    return e.toString();
  }

  String? _readDetail(dynamic data) {
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return null;
  }

  /// [isLogin] true  → login mode  (fails if account not found)
  /// [isLogin] false → register mode (fails if account already exists)
  Future<bool> sendOtp(String phone, {bool isLogin = true}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        AppConstants.sendOtp,
        data: {'phone': phone, 'mode': isLogin ? 'login' : 'register'},
      );
      final ok = response.statusCode == 200 || response.statusCode == 201;
      if (!ok) {
        _error = _readDetail(response.data) ?? 'Failed to send OTP';
      }
      _isLoading = false;
      notifyListeners();
      return ok;
    } catch (e) {
      _error = _extractError(e, 'Failed to send OTP');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp, {bool isLogin = true}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        AppConstants.verifyOtp,
        data: {'phone': phone, 'otp': otp, 'mode': isLogin ? 'login' : 'register'},
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final userJson =
            Map<String, dynamic>.from(data['user'] as Map<dynamic, dynamic>);
        await _apiClient.saveTokens(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String,
          userId: (userJson['id'] ?? userJson['_id'] ?? '').toString(),
        );
        _user = UserModel.fromJson(userJson);
        _loginIdentifier = phone;
        _loginMethod = phone.contains('@') ? 'email' : 'phone';
        _accountLinkPopupPending = true;   // show nudge popup once on next screen
        _setAuth(true);   // ← notifies router notifier
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = _readDetail(response.data) ?? 'Invalid OTP';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _extractError(e, 'Invalid OTP');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String phone,
    required String email,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        AppConstants.register,
        data: {
          'full_name': fullName,
          'phone': phone,
          if (email.isNotEmpty) 'email': email,
        },
      );

      final ok = response.statusCode == 201 || response.statusCode == 200;
      if (!ok) {
        _error = _readDetail(response.data) ?? 'Registration failed';
      }
      _isLoading = false;
      notifyListeners();
      return ok;
    } catch (e) {
      _error = _extractError(e, 'Registration failed');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String phone) => sendOtp(phone);

  /// Save the selected location to backend and update local user object
  /// so the dashboard header reflects the change instantly.
  Future<void> updateLocation(String location) async {
    try {
      await _apiClient.post(
        AppConstants.updateLocation,
        data: {'location': location},
      );
      // Update local model without a full refetch
      if (_user != null) {
        _user = _user!.copyWith(location: location);
        notifyListeners();
      }
    } catch (_) {
      // Non-critical — silently ignore
    }
  }

  Future<void> fetchUserProfile() async {
    try {
      final response = await _apiClient.get(AppConstants.profile);
      if (response.statusCode == 200 && response.data is Map) {
        _user = UserModel.fromJson(
            Map<String, dynamic>.from(response.data as Map));
        _setAuth(true);
      } else {
        _setAuth(false);
      }
    } catch (_) {
      _setAuth(false);
    }
    notifyListeners();
  }

  // ── Social Login ─────────────────────────────────────────────────────────

  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // serverClientId is required on Android for backend token verification.
    // Replace DUMMY value with the Web client ID from Google Cloud Console.
    serverClientId: AppConstants.googleClientId,
  );

  /// Signs in with Google, sends name+email to the backend, and stores tokens.
  /// Returns true on success. No OTP needed — email is the identifier.
  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Sign out first so the account picker always appears.
      await _googleSignIn.signOut();
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        // User cancelled the picker
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final response = await _apiClient.post(
        AppConstants.socialLogin,
        data: {
          'provider': 'google',
          'name': account.displayName ?? '',
          'email': account.email,
          'provider_id': account.id,
        },
      );

      if (response.statusCode == 200 && response.data is Map) {
        return _handleSocialSuccess(response.data as Map, loginMethod: 'google');
      }

      _error = _readDetail(response.data) ?? 'Google login failed';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _extractError(e, 'Google login failed');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Signs in with Facebook and sends name+email (if available) to the backend.
  /// Facebook may not return an email — in that case the user is sent to
  /// /auth/complete-profile to add their phone + email manually.
  Future<bool> loginWithFacebook() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Log out first to always show account picker
      await FacebookAuth.instance.logOut();
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.cancelled) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (result.status != LoginStatus.success) {
        _error = result.message ?? 'Facebook login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final userData = await FacebookAuth.instance.getUserData(
        fields: 'id,name,email',
      );

      final name     = userData['name'] as String? ?? '';
      final email    = userData['email'] as String?; // may be null
      final fbId     = userData['id'] as String? ?? '';

      final response = await _apiClient.post(
        AppConstants.socialLogin,
        data: {
          'provider': 'facebook',
          'name': name,
          if (email != null && email.isNotEmpty) 'email': email,
          'provider_id': fbId,
        },
      );

      if (response.statusCode == 200 && response.data is Map) {
        return _handleSocialSuccess(response.data as Map, loginMethod: 'facebook');
      }

      _error = _readDetail(response.data) ?? 'Facebook login failed';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _extractError(e, 'Facebook login failed');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Shared helper to parse a social login backend response and persist tokens.
  Future<bool> _handleSocialSuccess(Map raw, {required String loginMethod}) async {
    try {
      final data = Map<String, dynamic>.from(raw);
      final userJson =
          Map<String, dynamic>.from(data['user'] as Map<dynamic, dynamic>);
      await _apiClient.saveTokens(
        accessToken:  data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
        userId: (userJson['id'] ?? userJson['_id'] ?? '').toString(),
      );
      _user = UserModel.fromJson(userJson);
      _loginMethod = loginMethod;
      _loginIdentifier = _user!.email ?? _user!.phone;
      // For Google: use existing account-link nudge logic.
      // For Facebook: needsProfileCompletion drives the mandatory flow instead.
      _accountLinkPopupPending = loginMethod == 'google';
      _setAuth(true);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'Failed to process login response';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Call after the social complete-profile screen saves phone + email so the
  /// router stops redirecting to /auth/complete-profile.
  void markProfileCompleted({required String phone, String? email}) {
    if (_user != null) {
      _user = UserModel(
        id: _user!.id,
        fullName: _user!.fullName,
        phone: phone,
        email: email ?? _user!.email,
        avatarUrl: _user!.avatarUrl,
        location: _user!.location,
        dateOfBirth: _user!.dateOfBirth,
        address: _user!.address,
        city: _user!.city,
        state: _user!.state,
        pincode: _user!.pincode,
        aadharNumber: _user!.aadharNumber,
        panNumber: _user!.panNumber,
        isVerified: _user!.isVerified,
        createdAt: _user!.createdAt,
      );
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.post(AppConstants.logout);
    } catch (_) {}
    await _apiClient.clearTokens();
    _user = null;
    _setAuth(false);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

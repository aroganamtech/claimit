import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

  UserModel? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get error => _error;

  AuthProvider() {
    _checkAuthStatus();
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

  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        AppConstants.sendOtp,
        data: {'phone': phone},
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

  Future<bool> verifyOtp(String phone, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        AppConstants.verifyOtp,
        data: {'phone': phone, 'otp': otp},
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
        _isAuthenticated = true;
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

  Future<void> fetchUserProfile() async {
    try {
      final response = await _apiClient.get(AppConstants.profile);
      if (response.statusCode == 200 && response.data is Map) {
        _user = UserModel.fromJson(
            Map<String, dynamic>.from(response.data as Map));
        _isAuthenticated = true;
      } else {
        _isAuthenticated = false;
      }
    } catch (_) {
      _isAuthenticated = false;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _apiClient.post(AppConstants.logout);
    } catch (_) {}
    await _apiClient.clearTokens();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

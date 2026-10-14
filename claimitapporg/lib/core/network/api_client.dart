import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio _dio;

  // Use Android EncryptedSharedPreferences and iOS keychain by default
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Dio get dio => _dio;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      // Don't throw for any 4xx/5xx — let provider layer decide.
      validateStatus: (status) => status != null && status < 500,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Skip auth header for /auth/refresh, /auth/send-otp, /auth/verify-otp,
        // /auth/register
        final isAuthPath = options.path.startsWith('/auth/');
        if (!isAuthPath) {
          final token = await _storage.read(key: AppConstants.tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
      // ── Token refresh happens HERE, in onResponse — not in onError ──────
      //
      // THIS IS WHY USERS WERE LOGGED OUT AFTER A DAY.
      //
      // `validateStatus` above accepts every status below 500, which means
      // Dio treats a 401 as a perfectly good response and NEVER raises a
      // DioException for it. The refresh logic used to live in `onError`,
      // so it simply never ran. The access token expires after 24 hours,
      // every call started coming back 401, nothing refreshed, and the app
      // behaved as though the user had been signed out — even though the
      // refresh token was valid for weeks.
      //
      // Moving the check to onResponse fixes it without touching
      // validateStatus, which has to keep passing 4xx through: callers rely
      // on reading 409 and 422 as ordinary responses (duplicate bill,
      // insufficient points), and making those throw would break them.
      onResponse: (response, handler) async {
        final reqPath = response.requestOptions.path;
        final alreadyRetried = response.requestOptions.extra['_retried'] == true;

        if (response.statusCode == 401 &&
            !reqPath.startsWith('/auth/refresh') &&
            !reqPath.startsWith('/auth/') &&
            !alreadyRetried) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _storage.read(key: AppConstants.tokenKey);
            response.requestOptions.headers['Authorization'] = 'Bearer $token';
            response.requestOptions.extra['_retried'] = true;
            try {
              final retried = await _dio.fetch(response.requestOptions);
              return handler.resolve(retried);
            } catch (_) {
              // Fall through and hand back the original 401.
            }
          }
          // Refresh genuinely failed (no refresh token, or the server
          // rejected it). Tokens are NOT wiped here: a network blip or a
          // server restart must not sign a user out. The session is only
          // cleared when they tap Logout.
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        // Kept for transport-level failures that do surface as exceptions,
        // e.g. a 5xx or a timeout on a request whose token had just expired.
        final reqPath = error.requestOptions.path;
        final alreadyRetried = error.requestOptions.extra['_retried'] == true;

        if (error.response?.statusCode == 401 &&
            !reqPath.startsWith('/auth/refresh') &&
            !alreadyRetried) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _storage.read(key: AppConstants.tokenKey);
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            error.requestOptions.extra['_retried'] = true;
            try {
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (_) {
              // fall through
            }
          }
          // Deliberately NOT clearing tokens here either — see above.
        }
        return handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken =
          await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) return false;

      final response = await _dio.post(
        AppConstants.refreshToken,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data is Map) {
        final newToken = response.data['access_token'];
        if (newToken is String) {
          await _storage.write(key: AppConstants.tokenKey, value: newToken);

          // The server now rotates the refresh token on every refresh, so
          // store the new one when it sends one. This is what keeps an
          // active user signed in indefinitely: each refresh pushes the
          // expiry further out. Older builds of the server return only an
          // access token, so this stays optional.
          final rotated = response.data['refresh_token'];
          if (rotated is String && rotated.isNotEmpty) {
            await _storage.write(
                key: AppConstants.refreshTokenKey, value: rotated);
          }
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) {
    return _dio.get(path, queryParameters: queryParams);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }

  Future<Response> uploadFile(
    String path,
    FormData formData, {
    void Function(int, int)? onSendProgress,
  }) {
    return _dio.post(
      path,
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await _storage.write(key: AppConstants.tokenKey, value: accessToken);
    await _storage.write(
        key: AppConstants.refreshTokenKey, value: refreshToken);
    await _storage.write(key: AppConstants.userIdKey, value: userId);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.userIdKey);
    await _storage.delete(key: AppConstants.userDataKey);
  }

  Future<String?> getToken() => _storage.read(key: AppConstants.tokenKey);

  Future<String?> getUserId() => _storage.read(key: AppConstants.userIdKey);

  /// Build absolute URL for a relative file path returned by the backend
  /// (e.g. `/uploads/avatars/abc.png`). Useful for `Image.network`.
  String absoluteUrl(String relativePath) {
    if (relativePath.startsWith('http')) return relativePath;
    final base = AppConstants.baseUrl.endsWith('/')
        ? AppConstants.baseUrl.substring(0, AppConstants.baseUrl.length - 1)
        : AppConstants.baseUrl;
    final p = relativePath.startsWith('/') ? relativePath : '/$relativePath';
    return '$base$p';
  }
}

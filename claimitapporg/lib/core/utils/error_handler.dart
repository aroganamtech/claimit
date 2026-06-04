import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Converts any caught exception into a user-friendly message while printing
/// the full technical detail to the terminal for developers.
///
/// Usage:
///   ```dart
///   } catch (e, st) {
///     _error = AppError.friendly(e, 'Login failed', stackTrace: st);
///   }
///   ```
class AppError {
  /// Returns a short, friendly string safe to display in UI.
  /// Prints the original [error] + optional [stackTrace] via [debugPrint].
  static String friendly(
    Object error,
    String fallback, {
    StackTrace? stackTrace,
    String? context,
  }) {
    // Log original error for developers (only visible in debug console)
    final tag = context != null ? '[$context] ' : '';
    debugPrint('${tag}ERROR: $error');
    if (stackTrace != null) debugPrint('$tag$stackTrace');

    return _toFriendly(error, fallback);
  }

  static String _toFriendly(Object error, String fallback) {
    // ── Dio / HTTP errors ─────────────────────────────────────────────────────
    if (error is DioException) {
      // Server returned a detail message — show it (it's already friendly)
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        final detail = data['detail'].toString();
        // Only show if it looks human-readable (not a stack trace / path)
        if (detail.length < 200 && !detail.contains('\n')) return detail;
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Request timed out. Check your internet connection and try again.';

        case DioExceptionType.connectionError:
          return 'Unable to connect. Check your internet connection and try again.';

        case DioExceptionType.badResponse:
          final status = error.response?.statusCode ?? 0;
          if (status == 401) return 'Session expired. Please log in again.';
          if (status == 403) return 'You don\'t have permission to do this.';
          if (status == 404) return 'The requested resource was not found.';
          if (status == 409) return 'This action conflicts with existing data.';
          if (status >= 500) return 'Server error. Please try again in a moment.';
          return fallback;

        case DioExceptionType.cancel:
          return 'Request was cancelled.';

        default:
          return 'Something went wrong. Check your connection and try again.';
      }
    }

    // ── Socket / network errors ───────────────────────────────────────────────
    if (error is SocketException) {
      return 'No internet connection. Check your network and try again.';
    }

    // ── Timeout ───────────────────────────────────────────────────────────────
    if (error is TimeoutException) {
      return 'Request timed out. Check your internet connection and try again.';
    }

    // ── Format / parse errors ─────────────────────────────────────────────────
    if (error is FormatException) {
      return 'Received an unexpected response. Please try again.';
    }

    // ── Anything else — use fallback, never show raw toString() ──────────────
    return fallback;
  }
}

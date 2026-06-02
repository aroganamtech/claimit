import 'dart:convert';
import 'dart:io';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BillService — talks to POST /bill/scan, GET /bill/wallet, GET /bill/history
// ─────────────────────────────────────────────────────────────────────────────

class BillService {
  BillService._();
  static final instance = BillService._();

  final _client  = ApiClient();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Submit bill scan ───────────────────────────────────────────────────────
  // Returns the server response which always contains the latest wallet totals:
  //   { ok, earned_cashback, earned_points, reward_points,
  //     cashback_wallet, lifetime_cashback, is_new_user_bonus, bonus_points }
  Future<Map<String, dynamic>> submitBillScan({
    required double totalAmount,
    String? imagePath,
    String? shopName,
    String? billNumber,
    DateTime? billDate,
    String? billTime,   // "HH:MM" from receipt OCR
  }) async {
    // Encode image only when small enough to avoid timeout
    String? imageBase64;
    if (imagePath != null) {
      try {
        final bytes = await File(imagePath).readAsBytes();
        if (bytes.length < 2 * 1024 * 1024) {   // skip if > 2 MB
          imageBase64 = base64Encode(bytes);
        }
      } catch (_) {}
    }

    // user_id fallback so the server can identify the user even if the JWT
    // decode fails (e.g. clock skew or different secret on staging).
    final uid = await _storage.read(key: AppConstants.userIdKey);

    final body = <String, dynamic>{
      'total_amount': totalAmount,
      if (shopName?.isNotEmpty   == true) 'shop_name':   shopName,
      if (billNumber?.isNotEmpty == true) 'bill_number': billNumber,
      if (billTime?.isNotEmpty   == true) 'bill_time':   billTime,
      if (billDate != null)
        'bill_date':
            '${billDate.year}-${billDate.month.toString().padLeft(2, '0')}'
            '-${billDate.day.toString().padLeft(2, '0')}',
      if (imageBase64 != null) 'image_base64': imageBase64,
      if (uid != null) 'user_id': uid,
    };

    final response = await _client.post(AppConstants.billScan, data: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.data as Map<String, dynamic>;
    }
    if (response.statusCode == 409) {
      throw const BillAlreadyScannedException();
    }
    throw Exception('Bill scan API error: ${response.statusCode}');
  }

  // ── Fetch current wallet ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchWallet() async {
    final response = await _client.get('/bill/wallet');
    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Wallet API error: ${response.statusCode}');
  }

  // ── Fetch scan history ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchHistory() async {
    final response = await _client.get('/bill/history');
    if (response.statusCode == 200) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    throw Exception('History API error: ${response.statusCode}');
  }

  // ── Submit for manual review (missing fields or wrong OCR data) ─────────────
  Future<Map<String, dynamic>> submitManualReview({
    required double totalAmount,
    required String imagePath,
    String? shopName,
    String? billNumber,
    DateTime? billDate,
    String? billTime,
    String manualReason = 'missing_fields',
  }) async {
    String imageBase64 = '';
    try {
      final bytes = await File(imagePath).readAsBytes();
      imageBase64 = base64Encode(bytes);
    } catch (_) {
      throw Exception('Could not read bill image. Please retake the photo.');
    }
    if (imageBase64.isEmpty) throw Exception('Bill image is required.');

    final uid = await _storage.read(key: AppConstants.userIdKey);
    final body = <String, dynamic>{
      'total_amount':  totalAmount,
      'image_base64':  imageBase64,
      'manual_reason': manualReason,
      if (shopName?.isNotEmpty   == true) 'shop_name':   shopName,
      if (billNumber?.isNotEmpty == true) 'bill_number': billNumber,
      if (billTime?.isNotEmpty   == true) 'bill_time':   billTime,
      if (billDate != null)
        'bill_date': '${billDate.year}-${billDate.month.toString().padLeft(2,'0')}'
                     '-${billDate.day.toString().padLeft(2,'0')}',
      if (uid != null) 'user_id': uid,
    };

    final response = await _client.post('/bill/manual-review', data: body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Manual review error: ${response.statusCode}');
  }

  // ── Fetch my manual reviews ─────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchMyReviews() async {
    final response = await _client.get('/bill/my-reviews');
    if (response.statusCode == 200) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ── Fetch bill-related notifications ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchBillNotifications() async {
    final response = await _client.get('/bill/notifications');
    if (response.statusCode == 200) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }
}

// Thrown when the server returns 409 (duplicate bill)
class BillAlreadyScannedException implements Exception {
  const BillAlreadyScannedException();
  @override
  String toString() => 'BillAlreadyScannedException';
}

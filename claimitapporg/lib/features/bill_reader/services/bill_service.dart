import 'dart:convert';
import 'dart:io';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_handler.dart';
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
    String? shopId,      // Redeem/Reward shop id — enables server-side calc
    String? scanType,    // 'redeem' | 'reward' — which flow this scan belongs to
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
      if (shopId?.isNotEmpty     == true) 'shop_id':     shopId,
      if (scanType?.isNotEmpty   == true) 'scan_type':   scanType,
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
    AppError.friendly(Exception('Bill scan HTTP ${response.statusCode}'), '', context: 'BillScan');
    throw Exception('Unable to submit bill. Please try again.');
  }

  // ── Fetch current wallet ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchWallet() async {
    final response = await _client.get('/bill/wallet');
    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    }
    AppError.friendly(Exception('Wallet HTTP ${response.statusCode}'), '', context: 'BillWallet');
    throw Exception('Unable to load wallet. Please try again.');
  }

  // ── Live reward rates ──────────────────────────────────────────────────────
  // The percentages an admin has set for cashback and reward points, held as
  // statics so ANY screen can render the right number synchronously.
  //
  // These are printed all over the app — shop cards ("Free Reward + 1%
  // Cashback"), the shop detail chips, the redeem screen, the bill preview.
  // Every one of those used to be a hard-coded string, so changing the offer
  // to 2% left the whole app advertising a number it no longer paid. One
  // fetch, one cached value, every label agrees.
  //
  // Seeded with the launch rates so the first frame is sensible before the
  // fetch returns, and never throws — a failure just keeps the last value,
  // which is exactly what the server falls back to as well.
  static double cashbackPercent = 1.0;
  static double pointsPercent   = 10.0;
  static bool   _ratesLoaded    = false;

  /// "1" not "1.0", but "1.5" stays "1.5" — reads naturally whether the admin
  /// sets a whole number or a fraction.
  static String fmtPct(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  /// Ready-made labels, so no screen has to build the string itself and get
  /// it subtly different from its neighbour.
  static String get cashbackLabel => '${fmtPct(cashbackPercent)}% Cashback';
  static String get pointsLabel   => '${fmtPct(pointsPercent)}% Reward Points';

  /// Fetch the rates once per app run and cache them. Safe to call from any
  /// screen's initState — after the first call it is a no-op, so a screen that
  /// needs the number can just ask without worrying about duplicate requests.
  ///
  /// Pass force: true to re-read (e.g. pull-to-refresh) if an admin has
  /// changed the offer while the app was open.
  Future<void> ensureRates({bool force = false}) async {
    if (_ratesLoaded && !force) return;
    try {
      final response = await _client.get('/bill/rates');
      if (response.statusCode == 200 && response.data is Map) {
        final d = response.data as Map;
        cashbackPercent = (d['cashback_percent'] as num?)?.toDouble() ?? cashbackPercent;
        pointsPercent   = (d['points_percent']   as num?)?.toDouble() ?? pointsPercent;
        _ratesLoaded = true;
      }
    } catch (_) {
      // Offline or a blip — labels stay on the last known rates.
    }
  }

  /// Same fetch, but returns the values for a caller that wants them directly.
  Future<({double cashbackPercent, double pointsPercent})> fetchRates() async {
    await ensureRates(force: true);
    return (cashbackPercent: cashbackPercent, pointsPercent: pointsPercent);
  }

  // ── Fetch scan history ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchHistory() async {
    final response = await _client.get('/bill/history');
    if (response.statusCode == 200) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    AppError.friendly(Exception('History HTTP ${response.statusCode}'), '', context: 'BillHistory');
    throw Exception('Unable to load history. Please try again.');
  }

  // ── Submit for manual review (missing fields or wrong OCR data) ─────────────
  Future<Map<String, dynamic>> submitManualReview({
    required double totalAmount,
    required String imagePath,
    String? shopName,
    String? shopId,      // Redeem/Reward shop id — enables admin-side calc
    String? scanType,    // 'redeem' | 'reward' — which flow this scan belongs to
    String? billNumber,
    DateTime? billDate,
    String? billTime,
    String manualReason = 'missing_fields',
  }) async {
    String imageBase64 = '';
    try {
      final bytes = await File(imagePath).readAsBytes();
      imageBase64 = base64Encode(bytes);
    } catch (e) {
      AppError.friendly(e, '', context: 'BillImageRead');
      throw Exception('Could not read bill image. Please retake the photo.');
    }
    if (imageBase64.isEmpty) throw Exception('Bill image is required.');

    final uid = await _storage.read(key: AppConstants.userIdKey);
    final body = <String, dynamic>{
      'total_amount':  totalAmount,
      'image_base64':  imageBase64,
      'manual_reason': manualReason,
      if (shopName?.isNotEmpty   == true) 'shop_name':   shopName,
      if (shopId?.isNotEmpty     == true) 'shop_id':     shopId,
      if (scanType?.isNotEmpty   == true) 'scan_type':   scanType,
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
    if (response.statusCode == 409) {
      // Server found this exact bill already scanned, already approved, or
      // already sitting in the review queue — surface its friendly message
      // instead of "please try again" (which just invites another rescan).
      final detail = (response.data is Map)
          ? (response.data as Map)['detail']?.toString()
          : null;
      throw Exception(detail ?? 'This bill has already been submitted.');
    }
    AppError.friendly(Exception('ManualReview HTTP ${response.statusCode}'), '', context: 'BillManualReview');
    throw Exception('Could not submit for review. Please try again.');
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

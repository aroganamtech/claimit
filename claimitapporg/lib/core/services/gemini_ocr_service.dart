import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../network/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GeminiOcrResult — structured data extracted from a bill image
// ─────────────────────────────────────────────────────────────────────────────

class GeminiOcrResult {
  final String?   shopName;
  final double?   totalAmount;
  final DateTime? billDate;
  final String?   billNumber;
  final String?   rawJson; // the full JSON string the AI returned

  const GeminiOcrResult({
    this.shopName,
    this.totalAmount,
    this.billDate,
    this.billNumber,
    this.rawJson,
  });

  bool get hasAnyData =>
      shopName != null || totalAmount != null ||
      billDate != null || billNumber != null;

  @override
  String toString() =>
      'GeminiOcrResult(shop=$shopName, total=$totalAmount, '
      'date=$billDate, bill=$billNumber)';
}

// ─────────────────────────────────────────────────────────────────────────────
// GeminiOcrService — AI bill extraction via the Claimit backend.
//
// The Gemini API call now lives server-side (POST /bill/ocr on the FastAPI
// backend) so the API key never ships inside the APK and the prompt/model can
// be changed without an app release. This class keeps the exact same public
// API as before, so the scanning flow (bill_scanning_progress_screen.dart)
// is unchanged — including its on-device ML Kit fallback when this returns
// null (backend down, AI quota exhausted, unreadable image…).
// ─────────────────────────────────────────────────────────────────────────────

class GeminiOcrService {
  GeminiOcrService._();
  static final instance = GeminiOcrService._();

  /// Extract bill data from [imagePath] via the backend AI OCR endpoint.
  /// Returns null if the backend is unreachable or the AI found nothing —
  /// callers then fall back to on-device ML Kit OCR.
  Future<GeminiOcrResult?> extractFromImage(String imagePath) async {
    try {
      // Read and base64-encode the image
      final bytes    = await File(imagePath).readAsBytes();
      final b64Image = base64Encode(bytes);
      final mimeType = imagePath.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      final response = await ApiClient().post(
        AppConstants.billOcr,
        data: {
          'image_base64': b64Image,
          'mime_type':    mimeType,
        },
      );

      if (response.statusCode != 200 || response.data is! Map) {
        debugPrint('Backend OCR error: HTTP ${response.statusCode}');
        return null;
      }

      final json = Map<String, dynamic>.from(response.data as Map);
      if (json['success'] != true) {
        debugPrint('Backend OCR unavailable: ${json['detail']}');
        return null;
      }

      return GeminiOcrResult(
        shopName:    _str(json['shop_name']),
        totalAmount: _num(json['total_amount']),
        billDate:    _date(json['bill_date']),
        billNumber:  _str(json['bill_number']),
        rawJson:     json['raw'] as String?,
      );
    } catch (e) {
      debugPrint('GeminiOcrService error: $e');
      return null;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String? _str(dynamic v) {
    if (v == null || v == 'null') return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final cleaned = v.toString().replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned);
  }

  DateTime? _date(dynamic v) {
    if (v == null) return null;
    final raw = v.toString();

    DateTime? tryBuild(int y, int mo, int d) {
      final year = y < 100 ? 2000 + y : y;
      if (year < 2000 || year > 2100) return null;
      if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
      try { return DateTime(year, mo, d); } catch (_) { return null; }
    }

    // Pattern 1: DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
    final m1 = RegExp(r'(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})').firstMatch(raw);
    if (m1 != null) {
      final d  = int.tryParse(m1.group(1)!);
      final mo = int.tryParse(m1.group(2)!);
      final y  = int.tryParse(m1.group(3)!);
      if (d != null && mo != null && y != null) {
        final dt = tryBuild(y, mo, d);
        if (dt != null) return dt;
      }
    }

    // Pattern 2: "May 23, 2026" or "May 23 2026" (American: MMM DD YYYY)
    const monthNames = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final m2 = RegExp(
      r'([a-zA-Z]{3,9})\s+(\d{1,2}),?\s+(\d{2,4})',
    ).firstMatch(raw);
    if (m2 != null) {
      final monthStr = m2.group(1)!.toLowerCase().substring(0, 3);
      final d  = int.tryParse(m2.group(2)!);
      final y  = int.tryParse(m2.group(3)!);
      final mo = monthNames[monthStr];
      if (d != null && mo != null && y != null) {
        final dt = tryBuild(y, mo, d);
        if (dt != null) return dt;
      }
    }

    // Pattern 3: "23 May 2026" (DD MMM YYYY)
    final m3 = RegExp(
      r'(\d{1,2})\s+([a-zA-Z]{3,9})\s+(\d{2,4})',
    ).firstMatch(raw);
    if (m3 != null) {
      final d  = int.tryParse(m3.group(1)!);
      final monthStr = m3.group(2)!.toLowerCase().substring(0, 3);
      final y  = int.tryParse(m3.group(3)!);
      final mo = monthNames[monthStr];
      if (d != null && mo != null && y != null) {
        final dt = tryBuild(y, mo, d);
        if (dt != null) return dt;
      }
    }

    return null;
  }
}

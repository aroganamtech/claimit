import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GeminiOcrResult — structured data extracted from a bill image
// ─────────────────────────────────────────────────────────────────────────────

class GeminiOcrResult {
  final String?   shopName;
  final double?   totalAmount;
  final DateTime? billDate;
  final String?   billNumber;
  final String?   rawJson; // the full JSON string Gemini returned

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
// GeminiOcrService — calls Gemini 2.0 Flash Vision to extract bill fields
// ─────────────────────────────────────────────────────────────────────────────

class GeminiOcrService {
  GeminiOcrService._();
  static final instance = GeminiOcrService._();

  static const _prompt = '''
You are a bill/receipt OCR assistant. Carefully analyze the receipt image and extract:
1. shop_name: The business name at the very top of the receipt (e.g., "DMart", "Big Bazaar")
2. total_amount: The FINAL grand total amount the customer paid — look for labels like "Grand Total", "Net Total", "Total Amount", "Amount Payable", "Total". Return only the number (no ₹ sign or commas).
3. bill_date: The date printed on the receipt in DD/MM/YYYY format
4. bill_number: The invoice/bill/receipt number (e.g., "INV-001", "45871")

Return ONLY a single valid JSON object. No markdown, no explanation. Example:
{"shop_name":"DMart","total_amount":1250.50,"bill_date":"25/05/2026","bill_number":"INV001234"}

If a field cannot be confidently read, set it to null.
''';

  /// Extract bill data from [imagePath] using Gemini Vision.
  /// Returns null if the API key is not configured or the call fails.
  Future<GeminiOcrResult?> extractFromImage(String imagePath) async {
    final key = AppConstants.geminiApiKey;
    if (key == 'AIzaSyCOkuVpM_RgP3Bj5oryK1xzgU77PWInDr4' || key.isEmpty) {
      debugPrint('GeminiOcrService: API key not configured — skipping Gemini');
      return null;
    }

    try {
      // Read and base64-encode the image
      final bytes      = await File(imagePath).readAsBytes();
      final b64Image   = base64Encode(bytes);
      // Detect mime type
      final mimeType   = imagePath.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      final uri = Uri.parse('${AppConstants.geminiUrl}?key=$key');
      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'inlineData': {
                  'mimeType': mimeType,
                  'data':     b64Image,
                },
              },
              {'text': _prompt},
            ],
          }
        ],
        'generationConfig': {
          'temperature':     0,
          'topP':            1,
          'topK':            1,
          'maxOutputTokens': 256,
          'responseMimeType': 'application/json',
        },
      });

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        debugPrint('Gemini API error ${response.statusCode}: ${response.body}');
        return null;
      }

      final data       = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = (candidates[0] as Map)['content'];
      final parts   = (content as Map)['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;

      final text = ((parts[0] as Map)['text'] as String? ?? '').trim();
      debugPrint('Gemini raw response: $text');

      // Strip markdown fences if Gemini wraps with ```json ... ```
      final cleaned = text
          .replaceAll(RegExp(r'^```json\s*', multiLine: false), '')
          .replaceAll(RegExp(r'\s*```$',     multiLine: false), '')
          .trim();

      // Find the first {...} block
      final jsonMatch = RegExp(r'\{.*?\}', dotAll: true).firstMatch(cleaned);
      if (jsonMatch == null) {
        debugPrint('Gemini: no JSON block in response');
        return null;
      }

      final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;

      return GeminiOcrResult(
        shopName:    _str(json['shop_name']),
        totalAmount: _num(json['total_amount']),
        billDate:    _date(json['bill_date']),
        billNumber:  _str(json['bill_number']),
        rawJson:     jsonMatch.group(0),
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
    // DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
    final m = RegExp(r'(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})')
        .firstMatch(raw);
    if (m == null) return null;
    final d  = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    var   y  = int.tryParse(m.group(3)!) ?? 0;
    if (d == null || mo == null) return null;
    if (y < 100) y += 2000;
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    try { return DateTime(y, mo, d); } catch (_) { return null; }
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'gemini_ocr_service.dart' show GeminiOcrResult;

// ─────────────────────────────────────────────────────────────────────────────
// GroqOcrService — second-opinion Vision AI for bill OCR, using Groq's
// free-tier Llama 4 Scout vision model. Called ONLY when Gemini fails to
// return a usable result (down / rate-limited / transient error), so a
// single AI provider hiccup no longer forces a correctly-readable bill into
// manual review. Reuses GeminiOcrResult — it's just a generic
// (shopName, totalAmount, billDate, billNumber) holder, not Gemini-specific.
// Returns null on any failure — callers then fall back to on-device ML Kit
// OCR (see bill_scanning_progress_screen.dart).
// ─────────────────────────────────────────────────────────────────────────────

class GroqOcrService {
  GroqOcrService._();
  static final instance = GroqOcrService._();

  static const _prompt = '''
You are a bill/receipt OCR assistant. Carefully analyze the receipt image and extract:

1. shop_name: The business/store name — usually the largest, bold, or logo text at the top of the receipt (before address, phone, GSTIN, or date). Example: "The Daily Grind Cafe", "DMart".
   - NEVER return generic header words like "TAX INVOICE", "RETAIL INVOICE", "CASH MEMO", "RECEIPT", "BILL", "WELCOME", "CUSTOMER COPY", "THANK YOU" — the shop name is always an actual business name.
   - If the top line is a header word like "TAX INVOICE", the real shop name is usually just above or below it.

2. total_amount: The FINAL amount the customer actually PAID, after ALL discounts and taxes.
   - Receipts often show Subtotal, Discount/Savings, Tax/GST/CGST/SGST lines, and then a final total. Always pick the final payable figure.
   - The label may be "TOTAL", "TOTAL AMOUNT", "GRAND TOTAL", "NET TOTAL", "NET PAYABLE", "AMOUNT PAYABLE", "FINAL AMOUNT", "AMOUNT PAID", "BILL AMOUNT" — or there may be NO label at all, just a bold/large printed number. On some bills this final amount is printed at the TOP of the receipt, not the bottom.
   - NEVER return: the discount value, savings amount, subtotal (pre-discount), a tax amount, cash tendered, change/balance returned, loyalty points, or an individual item price.
   - Sanity check: when subtotal, discount and tax lines are visible, the total should equal subtotal - discount + tax.
   - Return only the numeric value (no ₹/Rs sign or commas).

3. bill_date: The date on the receipt. Always return in DD/MM/YYYY format. For example, if the receipt shows "May 23, 2026" return "23/05/2026".

4. bill_number: The receipt/invoice/bill number (e.g., "98432", "INV-001"). Strip any leading # symbol.

Return ONLY a single valid JSON object with no markdown or explanation. Example:
{"shop_name":"The Daily Grind Cafe","total_amount":2008.80,"bill_date":"23/05/2026","bill_number":"98432"}

If a field cannot be confidently read, set it to null.
''';

  /// Extract bill data from [imagePath] using Groq's Llama 4 Scout vision
  /// model. Returns null if the API key is not configured or the call fails.
  Future<GeminiOcrResult?> extractFromImage(String imagePath) async {
    final key = AppConstants.groqApiKey;
    if (key.isEmpty || key.startsWith('YOUR_')) {
      debugPrint('GroqOcrService: API key not configured — skipping Groq');
      return null;
    }

    try {
      final bytes    = await File(imagePath).readAsBytes();
      final b64Image = base64Encode(bytes);
      final mimeType = imagePath.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      final uri = Uri.parse(AppConstants.groqUrl);
      final body = jsonEncode({
        'model': AppConstants.groqModel,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': _prompt},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:$mimeType;base64,$b64Image'},
              },
            ],
          },
        ],
        'temperature': 0,
        'max_completion_tokens': 512,
        'response_format': {'type': 'json_object'},
      });

      // Up to 2 attempts — same pattern as Gemini.
      for (var attempt = 1; attempt <= 2; attempt++) {
        if (attempt == 2) {
          await Future.delayed(const Duration(seconds: 2));
        }
        try {
          final response = await http.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: body,
          ).timeout(const Duration(seconds: 20));

          if (response.statusCode == 429) {
            // Daily/rate quota exceeded — retrying immediately is pointless.
            debugPrint('Groq quota exceeded (429) — falling back');
            return null;
          }
          if (response.statusCode != 200) {
            debugPrint(
                'Groq API error ${response.statusCode} (attempt $attempt): '
                '${response.body}');
            continue;
          }

          final data    = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = data['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;

          final message = (choices[0] as Map)['message'] as Map?;
          final text = (message?['content'] as String? ?? '').trim();
          debugPrint('Groq raw response: $text');

          // Strip markdown fences, just in case the model wraps with ```json.
          final cleaned = text
              .replaceAll(RegExp(r'^```json\s*', multiLine: false), '')
              .replaceAll(RegExp(r'\s*```$', multiLine: false), '')
              .trim();

          final jsonMatch = RegExp(r'\{.*?\}', dotAll: true).firstMatch(cleaned);
          if (jsonMatch == null) {
            debugPrint('Groq: no JSON block in response (attempt $attempt)');
            continue;
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
          debugPrint('Groq attempt $attempt failed: $e');
        }
      }
      return null;
    } catch (e) {
      debugPrint('GroqOcrService error: $e');
      return null;
    }
  }

  // ── Helpers (identical to GeminiOcrService) ─────────────────────────────

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

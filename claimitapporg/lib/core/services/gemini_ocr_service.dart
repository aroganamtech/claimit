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
// GeminiOcrService — calls Gemini 2.5 Flash Vision directly to extract
// bill fields. Direct (phone → Google) is the fastest path for users in
// India. Returns null on any failure — callers then fall back to on-device
// ML Kit OCR (see bill_scanning_progress_screen.dart).
// ─────────────────────────────────────────────────────────────────────────────

class GeminiOcrService {
  GeminiOcrService._();
  static final instance = GeminiOcrService._();

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

  /// Extract bill data from [imagePath] using Gemini Vision.
  /// Returns null if the API key is not configured or the call fails.
  Future<GeminiOcrResult?> extractFromImage(String imagePath) async {
    final key = AppConstants.geminiApiKey;
    if (key.isEmpty || key.startsWith('YOUR_')) {
      debugPrint('GeminiOcrService: API key not configured — skipping Gemini');
      return null;
    }

    try {
      // Read and base64-encode the image
      final bytes      = await File(imagePath).readAsBytes();
      final b64Image   = base64Encode(bytes);
      final mimeType   = imagePath.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      // Auth keys (AQ.…) must go in the x-goog-api-key header — the old
      // ?key= query param only supports legacy AIza keys.
      final uri = Uri.parse(AppConstants.geminiUrl);
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
          'maxOutputTokens': 512,
          'responseMimeType': 'application/json',
          // 2.5-flash is a thinking model — disable thinking so reasoning
          // tokens don't eat the output budget (faster + cheaper).
          'thinkingConfig': {'thinkingBudget': 0},
        },
      });

      // Up to 2 attempts — transient 503 "model overloaded" errors usually
      // clear within a second or two, so pause briefly before the retry.
      for (var attempt = 1; attempt <= 2; attempt++) {
        if (attempt == 2) {
          await Future.delayed(const Duration(seconds: 2));
        }
        try {
          final response = await http.post(
            uri,
            headers: {
              'Content-Type':   'application/json',
              'x-goog-api-key': key,
            },
            body: body,
          ).timeout(const Duration(seconds: 20));

          if (response.statusCode == 429) {
            // Quota/rate limit — retrying immediately is pointless
            debugPrint('Gemini quota exceeded (429) — falling back');
            return null;
          }
          if (response.statusCode != 200) {
            debugPrint(
                'Gemini API error ${response.statusCode} (attempt $attempt)');
            continue;
          }

          final data       = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) continue;

          final content = (candidates[0] as Map)['content'];
          final parts   = (content as Map)['parts'] as List?;
          if (parts == null || parts.isEmpty) continue;

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
            debugPrint('Gemini: no JSON block in response (attempt $attempt)');
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
          debugPrint('Gemini attempt $attempt failed: $e');
        }
      }
      return null;
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

    // Pattern 2: "May 23, 2026" (MMM DD YYYY)
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

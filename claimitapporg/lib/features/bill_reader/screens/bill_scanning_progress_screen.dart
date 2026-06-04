import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../providers/bill_reward_provider.dart';
import '../../../core/services/gemini_ocr_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BillScanningProgressScreen
// Runs real OCR on the captured bill image, extracts:
//   • Total amount
//   • Shop name  (first non-address lines at top of receipt)
//   • Bill date  (date printed on the bill)
// Then validates that the bill date == today before proceeding.
// ─────────────────────────────────────────────────────────────────────────────

class BillScanningProgressScreen extends StatefulWidget {
  final String imagePath;
  const BillScanningProgressScreen({super.key, required this.imagePath});

  @override
  State<BillScanningProgressScreen> createState() =>
      _BillScanningProgressScreenState();
}

class _BillScanningProgressScreenState
    extends State<BillScanningProgressScreen>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF1565C0);

  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  int _visibleSteps = 0;
  late Timer _stepTimer;

  final List<String> _steps = [
    'Reading bill image…',
    'Running AI vision analysis…',
    'Extracting shop name…',
    'Extracting bill date…',
    'Verifying total amount…',
  ];

  double?   _extractedTotal;
  String?   _extractedShop;
  DateTime? _extractedBillDate;
  String?   _extractedBillNumber;
  bool      _ocrDone = false;

  @override
  void initState() {
    super.initState();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _progressAnim = CurvedAnimation(
        parent: _progressCtrl, curve: Curves.easeInOut);
    _progressCtrl.forward();

    int step = 0;
    _stepTimer = Timer.periodic(const Duration(milliseconds: 700), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (step < _steps.length) {
          _visibleSteps = step + 1;
          step++;
        } else {
          t.cancel();
        }
      });
    });

    _runOcr();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _stepTimer.cancel();
    super.dispose();
  }

  // ── OCR ────────────────────────────────────────────────────────────────────

  Future<void> _runOcr() async {
    double?   total;
    String?   shopName;
    DateTime? billDate;
    String?   billTime;
    String    rawText = '';
    String?   billNumber;

    // ── Step 1: Try Gemini Vision AI (most accurate) ─────────────────────────
    bool geminiSucceeded = false;
    try {
      final gemini = await GeminiOcrService.instance
          .extractFromImage(widget.imagePath);
      if (gemini != null && gemini.hasAnyData) {
        total      = gemini.totalAmount;
        shopName   = gemini.shopName;
        billDate   = gemini.billDate;
        billNumber = gemini.billNumber;
        rawText    = gemini.rawJson ?? '';
        geminiSucceeded = true;
        debugPrint('Gemini OCR succeeded: $gemini');
      }
    } catch (e) {
      debugPrint('Gemini OCR error: $e');
    }

    // ── Step 2: ML Kit fallback (if Gemini unavailable or returned nulls) ────
    if (!geminiSucceeded || total == null) {
      try {
        final inputImage = InputImage.fromFilePath(widget.imagePath);
        final recognizer =
            TextRecognizer(script: TextRecognitionScript.latin);
        final result = await recognizer.processImage(inputImage);
        await recognizer.close();
        rawText = result.text;

        // Only fill fields that Gemini didn't find
        total      ??= _extractTotal(rawText);
        shopName   ??= _extractShopName(rawText);
        billDate   ??= _extractBillDate(rawText);
        billNumber ??= _extractBillNumber(rawText);
        debugPrint('ML Kit fallback: total=$total shop=$shopName');
      } catch (e) {
        debugPrint('ML Kit OCR error: $e');
      }
    }

    // ── Extract bill time from OCR text (both Gemini & ML Kit path) ──────────
    billTime = _extractBillTime(rawText);

    // Minimum animation time so progress steps are visible
    await Future.delayed(const Duration(milliseconds: 3800));
    if (!mounted) return;

    // ── Date validation ──────────────────────────────────────────────────────
    // Bill date must match today's date.
    if (billDate != null) {
      final today = DateTime.now();
      final isSameDay = billDate.year  == today.year &&
                        billDate.month == today.month &&
                        billDate.day   == today.day;

      if (!isSameDay) {
        // Go back to scanner and show error
        if (!mounted) return;
        context.pop(); // back to scanner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFB71C1C),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.event_busy_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bill date (${_fmtDate(billDate)}) must be today\'s date. '
                    'Only today\'s bills can be scanned.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _extractedTotal      = total;
      _extractedShop       = shopName;
      _extractedBillDate   = billDate;
      _extractedBillNumber = billNumber;
      _ocrDone = true;
    });

    // Populate provider
    final provider = context.read<BillRewardProvider>();
    provider.setScanResult(
      totalAmount: total,
      imagePath:   widget.imagePath,
      ocrText:     rawText,
      shopName:    shopName,
      billDate:    billDate,
      billNumber:  billNumber,
      billTime:    billTime,
    );

    // ── Early duplicate check ─────────────────────────────────────────────────
    // Only check when OCR extracted enough data (shop + amount + date).
    // This blocks both normal scan AND manual review before the user wastes time.
    if (total != null && shopName != null && shopName.isNotEmpty && billDate != null) {
      final alreadyScanned = provider.isDuplicate(
        shopName:  shopName,
        amount:    total,
        billDate:  billDate,
        billTime:  billTime,
      );
      if (alreadyScanned && mounted) {
        // Go back to scanner and show already-scanned message
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFB71C1C),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This bill from "$shopName" has already been scanned. '
                    'Each bill can only be claimed once.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }
    }

    context.pushReplacement('/bill-reader/confirm');
  }

  // ── Extract: Total amount ───────────────────────────────────────────────────

  double? _extractTotal(String rawText) {
    debugPrint('═══ OCR RAW TEXT ═══\n$rawText\n════════════════════');

    String text = rawText
        .replaceAll(RegExp(r'(?<=[0-9])[oO](?=[0-9])'), '0')
        .replaceAll(RegExp(r'(?<=[0-9])[lIi|](?=[0-9])'), '1')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n+'), '\n');

    // ── Normalise ₹ OCR misreads ─────────────────────────────────────────────
    // ML Kit commonly misreads the ₹ (Rupee) symbol as Z, F, or R when it
    // appears before a 3–7 digit amount (e.g. Z1860.00 → ₹1860.00).
    // We handle this BEFORE any pattern matching so keyword patterns can find
    // the correct amounts even when ₹ is garbled.
    text = text.replaceAllMapped(
      // At start-of-line: Z/F/R immediately followed by 3-7 digits + decimal
      RegExp(r'^([ZFRzfr])(\d{3,7}(?:\.\d{1,2})?)', multiLine: true),
      (m) => '₹${m.group(2)}',
    );
    text = text.replaceAllMapped(
      // After whitespace: same pattern
      RegExp(r'([ \t])([ZFRzfr])(\d{3,7}(?:\.\d{1,2})?)'),
      (m) => '${m.group(1)}₹${m.group(3)}',
    );

    double? parseNum(String? raw) {
      if (raw == null) return null;
      final cleaned = raw.replaceAll(RegExp(r'[,\s₹]'), '');
      final val = double.tryParse(cleaned);
      return (val != null && val >= 10 && val <= 500000) ? val : null;
    }

    // Two delimiter variants:
    // • delim        — allows newlines; used only for Stage 1 where label and
    //                  value may span lines (e.g. "TOTAL AMOUNT:\n₹2008.80")
    // • delimStrict  — NO newlines; used for lower-priority standalone keywords
    //                  so "TOTAL\n360.00" doesn't capture the wrong number.
    const delim       = r'[ \t:=\-₹]*(?:rs\.?|Rs\.?)?[ \t\n]*';
    const delimStrict = r'[ \t:=\-₹]*(?:rs\.?|Rs\.?)?[ \t]*';

    // ── Stage 1: High-confidence grand total keywords ─────────────────────────
    // Uses delim (allows newlines) so the value found on the next line is caught.
    final highConfidencePatterns = [
      '(?:grand\\s*total|net\\s*total|net\\s*amount|total\\s*amount|'
          'total\\s*bill|bill\\s*total|amount\\s*due|amount\\s*payable|'
          'payable\\s*amount)'
          '$delim'
          r'([0-9][0-9,]{0,8}(?:\.[0-9]{1,2})?)',
    ];

    for (final pattern in highConfidencePatterns) {
      final matches =
          RegExp(pattern, caseSensitive: false, multiLine: true).allMatches(text);
      double? best;
      for (final m in matches) {
        final val = parseNum(m.group(1));
        if (val != null && (best == null || val > best)) best = val;
      }
      if (best != null) {
        debugPrint('OCR total found via high-confidence keyword: $best');
        return best;
      }
    }

    // ── Stage 2: Lower-priority keyword patterns ──────────────────────────────
    // Uses delimStrict (no newlines) to prevent "TOTAL\n360.00" from matching
    // the column header "TOTAL" and stealing the first item's line-price (₹360).
    final lowerPatterns = [
      '(?:sub\\s*total|subtotal)$delimStrict'
          r'([0-9][0-9,]{0,8}(?:\.[0-9]{1,2})?)',
      '(?:^|[ \\t])total$delimStrict'
          r'([0-9][0-9,]{0,8}(?:\.[0-9]{1,2})?)',
      '(?:^|[ \\t])amount$delimStrict'
          r'([0-9][0-9,]{0,8}(?:\.[0-9]{1,2})?)',
      '(?:^|[ \\t])amt$delimStrict'
          r'([0-9][0-9,]{0,8}(?:\.[0-9]{1,2})?)',
      r'₹\s*([0-9][0-9,]{0,8}(?:\.[0-9]{1,2})?)',
    ];

    for (final pattern in lowerPatterns) {
      final matches =
          RegExp(pattern, caseSensitive: false, multiLine: true).allMatches(text);
      double? best;
      for (final m in matches) {
        final val = parseNum(m.group(1));
        if (val != null && (best == null || val > best)) best = val;
      }
      if (best != null) {
        debugPrint('OCR total found via lower-priority keyword: $best');
        return best;
      }
    }

    // ── Stage 3: Line scan — collect ALL keyword lines, return LARGEST ────────
    // Bug fix: the old code returned on the FIRST matching line (which could be
    // "SUBTOTAL" or the column header "TOTAL" next to item ₹360). We now scan
    // ALL matching lines and return the largest valid amount found.
    double? lineScanBest;
    for (final line in text.split('\n')) {
      // Skip lines that are only the column header (no digits on the line)
      if (!RegExp(r'\d').hasMatch(line)) continue;
      if (RegExp(r'total|amount|amt|bill|payable|due',
              caseSensitive: false).hasMatch(line)) {
        final numMatches =
            RegExp(r'([0-9][0-9,\s]{0,8}(?:\.[0-9]{1,2})?)').allMatches(line);
        for (final nm in numMatches) {
          final val = parseNum(nm.group(1));
          if (val != null &&
              (lineScanBest == null || val > lineScanBest)) {
            lineScanBest = val;
          }
        }
      }
    }
    if (lineScanBest != null) {
      debugPrint('OCR total found via line scan (largest): $lineScanBest');
      return lineScanBest;
    }

    // ── Stage 4: Absolute fallback — largest number in the whole text ─────────
    final allNums = RegExp(
            r'(?<!\d)([0-9]{2,}(?:[,\s][0-9]{3})*(?:\.[0-9]{1,2})?)(?!\d)')
        .allMatches(text)
        .map((m) => parseNum(m.group(1)))
        .whereType<double>()
        .toList();

    if (allNums.isNotEmpty) {
      allNums.sort();
      final largest = allNums.last;
      debugPrint('OCR total fallback (largest number): $largest');
      return largest;
    }

    debugPrint('OCR: no total found');
    return null;
  }

  // ── Extract: Shop name ──────────────────────────────────────────────────────
  // Primary pass  : first clean lines before any stop keyword (works when the
  //                 shop name is at the very top of the OCR output).
  // Secondary pass: scans ALL lines and skips any that look like dates, times,
  //                 addresses, or receipt metadata — then returns the first
  //                 ALL-CAPS candidate.  This handles receipts where ML Kit
  //                 reads the date block before the business name block.

  String? _extractShopName(String rawText) {
    // Lines that signal receipt metadata (stop primary, skip secondary)
    final stopPattern = RegExp(
      r'gstin|gst\s*no|gst\s*number|gst\s*reg|'
      r'invoice|bill\s*no|'
      r'address|addr|ph\s*:|phone|tel\s*:|mobile|'
      r'tax\s*invoice|vat\s*no|pan\s*no|'
      r'date\s*:|time\s*:|cashier|counter|'
      r'qty|unit\s*price|items\s*purchased',
      caseSensitive: false,
    );

    // Extra patterns to SKIP in the secondary pass (but not stop)
    // Covers date/time lines that slip through the primary stop pattern
    final skipPattern = RegExp(
      r'receipt\s*no|receipt\s*#|'
      r'\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\b|'
      r'\d{1,2}:\d{2}\s*(?:am|pm)|'                 // time like 12:34 PM
      r'subtotal|tax\s*\(|total|thank\s*you|enjoy|'
      r'payment|status|paid|cash|card|visa|master|upi|'
      r'way,|road|street|nagar|colony|sector|phase|'  // address words
      r'innovation|tech\s*city',                       // address keywords
      caseSensitive: false,
    );

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // ── Primary pass: first clean lines before any stop keyword ──────────────
    final shopLines = <String>[];
    for (final line in lines) {
      if (stopPattern.hasMatch(line)) break;
      final alphaCount = RegExp(r'[a-zA-Z]').allMatches(line).length;
      if (line.length > 3 && alphaCount < 2) break;
      if (shopLines.length >= 5) break;
      shopLines.add(line);
    }

    if (shopLines.isNotEmpty) {
      final primary = shopLines.first
          .replaceAll(RegExp(r"[^a-zA-Z0-9\s\-\&\.\,']"), '')
          .trim();
      if (primary.isNotEmpty) {
        debugPrint('OCR shop name (primary): $primary');
        return primary;
      }
    }

    // ── Secondary pass: scan ALL lines (not just top N) ───────────────────────
    // ML Kit sometimes reads date/receipt blocks before the shop name block.
    // We skip any line matching stop OR skip patterns, then look for the first
    // ALL-CAPS line that has ≥5 alpha chars and ≥60 % uppercase letters.
    for (final line in lines) {
      if (stopPattern.hasMatch(line)) continue;  // skip, not break
      if (skipPattern.hasMatch(line)) continue;

      final stripped = line.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim();
      if (stripped.length < 5) continue;

      // Must have at least 60 % uppercase — typical for receipt business names
      final upperCount = stripped.replaceAll(RegExp(r'[^A-Z]'), '').length;
      final totalAlpha = stripped.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
      if (totalAlpha == 0 || upperCount / totalAlpha < 0.6) continue;

      // Reject lines that start with a digit (likely address "123 Main St")
      if (RegExp(r'^\d').hasMatch(line)) continue;

      final clean = line
          .replaceAll(RegExp(r"[^a-zA-Z0-9\s\-\&\.\,']"), '')
          .trim();
      if (clean.isNotEmpty) {
        debugPrint('OCR shop name (secondary all-lines): $clean');
        return clean;
      }
    }

    debugPrint('OCR: no shop name found');
    return null;
  }

  // ── Extract: Bill / Invoice / Receipt number ────────────────────────────────
  // Recognizes common Indian receipt bill-number patterns:
  //   "Bill No: 45871"   "Invoice No: 45871"   "Bill #45871"
  //   "Inv No: 45871"    "Receipt No: 45871"   "Voucher No: 45871"
  //   "Bill Number: 45871"   "Inv#: 45871"
  //   Also catches "No: 45871" when preceded by bill/invoice keywords.

  String? _extractBillNumber(String rawText) {
    final pattern = RegExp(
      r'(?:bill\s*(?:no|number|num|#)|'
      r'invoice\s*(?:no|number|num|#)|'
      r'inv\s*(?:no|num|#)|'
      r'receipt\s*(?:no|number|num|#)|'
      r'voucher\s*(?:no|number|num|#)|'
      r'rcpt\s*(?:no|num|#)|'
      r'txn\s*(?:no|id|number)|'
      r'order\s*(?:no|number|num|#))'
      r'\s*[:\-#]?\s*'
      r'([A-Za-z0-9][A-Za-z0-9\-\/]{1,20})',
      caseSensitive: false,
    );

    for (final m in pattern.allMatches(rawText)) {
      final raw = m.group(1)?.trim();
      if (raw != null && raw.isNotEmpty) {
        // Must contain at least one digit to be a real bill number
        if (RegExp(r'\d').hasMatch(raw)) {
          debugPrint('OCR bill number: $raw');
          return raw;
        }
      }
    }

    debugPrint('OCR: no bill number found');
    return null;
  }

  // ── Extract: Bill date ──────────────────────────────────────────────────────
  // Recognizes receipt date formats:
  //   DD/MM/YYYY  DD-MM-YYYY  DD.MM.YYYY  (and YY variants)
  //   YYYY-MM-DD  (ISO)
  //   DD MMM YYYY  (e.g. 23 May 2026)
  //   MMM DD, YYYY (e.g. May 23, 2026)  ← American format used by many POS

  DateTime? _extractBillDate(String rawText) {
    const monthNames = {
      'jan': 1,  'feb': 2,  'mar': 3,  'apr': 4,
      'may': 5,  'jun': 6,  'jul': 7,  'aug': 8,
      'sep': 9,  'oct': 10, 'nov': 11, 'dec': 12,
    };

    // Helper: validate and build DateTime
    DateTime? tryDate(int y, int m, int d) {
      if (m < 1 || m > 12) return null;
      if (d < 1 || d > 31) return null;
      final year = y < 100 ? 2000 + y : y;
      if (year < 2000 || year > 2100) return null;
      try { return DateTime(year, m, d); } catch (_) { return null; }
    }

    // ── Pattern 1: DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY ───────────────────
    final dmyPattern = RegExp(r'\b(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})\b');
    for (final m in dmyPattern.allMatches(rawText)) {
      final d  = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final y  = int.tryParse(m.group(3)!);
      if (d != null && mo != null && y != null) {
        final dt = tryDate(y, mo, d);
        if (dt != null) {
          debugPrint('OCR bill date (DMY): $dt');
          return dt;
        }
      }
    }

    // ── Pattern 2: ISO YYYY-MM-DD ────────────────────────────────────────────
    final isoPattern = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');
    for (final m in isoPattern.allMatches(rawText)) {
      final y  = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final d  = int.tryParse(m.group(3)!);
      if (y != null && mo != null && d != null) {
        final dt = tryDate(y, mo, d);
        if (dt != null) {
          debugPrint('OCR bill date (ISO): $dt');
          return dt;
        }
      }
    }

    // ── Pattern 3: MMM DD, YYYY  (e.g. May 23, 2026) — American POS format ──
    final americanPattern = RegExp(
      r'\b([a-zA-Z]{3,9})\s+(\d{1,2}),?\s+(\d{2,4})\b',
    );
    for (final m in americanPattern.allMatches(rawText)) {
      final monthStr = m.group(1)!.toLowerCase();
      final key = monthStr.length >= 3 ? monthStr.substring(0, 3) : monthStr;
      final mo = monthNames[key];
      final d  = int.tryParse(m.group(2)!);
      final y  = int.tryParse(m.group(3)!);
      if (mo != null && d != null && y != null) {
        final dt = tryDate(y, mo, d);
        if (dt != null) {
          debugPrint('OCR bill date (American MMM DD YYYY): $dt');
          return dt;
        }
      }
    }

    // ── Pattern 4: DD MMM YYYY  (e.g. 23 May 2026) ──────────────────────────
    final wordPattern = RegExp(r'\b(\d{1,2})\s+([a-zA-Z]{3,9})\s+(\d{2,4})\b');
    for (final m in wordPattern.allMatches(rawText)) {
      final d  = int.tryParse(m.group(1)!);
      final monthStr = m.group(2)!.toLowerCase();
      final key = monthStr.length >= 3 ? monthStr.substring(0, 3) : monthStr;
      final y  = int.tryParse(m.group(3)!);
      final mo = monthNames[key];
      if (d != null && mo != null && y != null) {
        final dt = tryDate(y, mo, d);
        if (dt != null) {
          debugPrint('OCR bill date (DD MMM YYYY): $dt');
          return dt;
        }
      }
    }

    debugPrint('OCR: no bill date found');
    return null;
  }

  // ── Extract: Bill time ──────────────────────────────────────────────────────
  // Returns "HH:MM" (24-h) string, or null if no time found.
  // Recognises:
  //   HH:MM:SS  / HH:MM  (24-h, e.g. 14:30, 09:05:22)
  //   H:MM AM/PM         (12-h, e.g. 2:30 PM, 9:05 am)
  // Preceded by optional label: TIME:, TIME., AT, @
  String? _extractBillTime(String rawText) {
    // ── Pattern A: 12-h with AM/PM (most unambiguous) ───────────────────────
    final amPmPattern = RegExp(
      r'\b(\d{1,2}):(\d{2})(?::\d{2})?\s*(am|pm|AM|PM)\b',
    );
    for (final m in amPmPattern.allMatches(rawText)) {
      int hour   = int.parse(m.group(1)!);
      final min  = int.parse(m.group(2)!);
      final period = m.group(3)!.toLowerCase();
      if (hour < 1 || hour > 12 || min > 59) continue;
      if (period == 'pm' && hour != 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;
      final t = '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
      debugPrint('OCR bill time (12-h): $t');
      return t;
    }

    // ── Pattern B: 24-h near time keyword ───────────────────────────────────
    final labeledPattern = RegExp(
      r'(?:time|TIME|Time)[:\.\s]+(\d{1,2}):(\d{2})(?::\d{2})?',
    );
    for (final m in labeledPattern.allMatches(rawText)) {
      final h = int.parse(m.group(1)!);
      final mi = int.parse(m.group(2)!);
      if (h > 23 || mi > 59) continue;
      final t = '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
      debugPrint('OCR bill time (labeled 24-h): $t');
      return t;
    }

    // ── Pattern C: bare HH:MM that looks like a time (08:00–23:59) ──────────
    // Avoid matching dates like "27/05" which don't appear with : separator.
    final barePattern = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)(?::\d{2})?\b');
    for (final m in barePattern.allMatches(rawText)) {
      final h  = int.parse(m.group(1)!);
      final mi = int.parse(m.group(2)!);
      if (h > 23 || mi > 59) continue;
      final t = '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
      debugPrint('OCR bill time (bare 24-h): $t');
      return t;
    }

    debugPrint('OCR: no bill time found');
    return null;
  }

  // ── Date formatter for error message ─────────────────────────────────────────
  String _fmtDate(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _blue, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Reading Bill',
          style: TextStyle(
              color: _blue, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scanning…',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 14),

            // Progress bar
            AnimatedBuilder(
              animation: _progressAnim,
              builder: (_, __) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _ocrDone ? 1.0 : _progressAnim.value,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE0E0E0),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(_blue),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Checklist steps
            ..._steps.asMap().entries.map((e) {
              final visible = e.key < _visibleSteps;
              final isDone  = _ocrDone || e.key < _visibleSteps;
              return AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDone
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDone
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: isDone
                            ? const Icon(Icons.check_rounded,
                                color: Color(0xFF4CAF50), size: 18)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.value,
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF333333)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Live OCR preview chips (shown while scanning)
            if (_ocrDone) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 6),
              _OcrPreviewChip(
                icon: Icons.storefront_rounded,
                label: 'Shop',
                value: _extractedShop ?? 'Not detected',
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(height: 6),
              _OcrPreviewChip(
                icon: Icons.calendar_today_rounded,
                label: 'Date',
                value: _extractedBillDate != null
                    ? _fmtDate(_extractedBillDate!)
                    : 'Not detected',
                color: const Color(0xFF7B1FA2),
              ),
              const SizedBox(height: 6),
              _OcrPreviewChip(
                icon: Icons.receipt_rounded,
                label: 'Amount',
                value: _extractedTotal != null
                    ? '₹${_extractedTotal!.toStringAsFixed(0)}'
                    : 'Not detected',
                color: const Color(0xFF2E7D32),
              ),
            ],

            const SizedBox(height: 16),

            // Bill image preview — fixed height avoids Expanded-in-Column issues
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF5F5F5),
                    child: const Center(
                      child: Icon(Icons.receipt_long_rounded,
                          size: 60, color: Color(0xFFBDBDBD)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Small chip to preview an OCR-extracted field ──────────────────────────────
class _OcrPreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _OcrPreviewChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF374151)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

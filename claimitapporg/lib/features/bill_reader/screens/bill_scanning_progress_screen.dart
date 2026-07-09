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

  // Confidence of the ML Kit regex fallback. Set by _extractTotal /
  // _extractShopName: true when the value came from a low-confidence stage
  // (blind number scan / secondary line scan) rather than an explicit label.
  bool _totalLowConfidence = false;
  bool _shopLowConfidence  = false;

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

    // ── Step 0: Quick internet check ──────────────────────────────────────────
    // A 3-second DNS lookup instead of waiting for Gemini's 20s timeout ×2.
    // Offline scans skip AI entirely and are always routed to manual review.
    final netOk = await _hasInternet();
    if (!netOk) debugPrint('No internet — skipping AI, using ML Kit only');

    // ── Step 1: Try Gemini Vision AI (most accurate) ─────────────────────────
    bool geminiSucceeded = false;
    if (netOk) {
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
    }

    // ── Step 2: ML Kit fallback (if Gemini unavailable or returned nulls) ────
    if (!geminiSucceeded || total == null) {
      try {
        final inputImage = InputImage.fromFilePath(widget.imagePath);
        final recognizer =
            TextRecognizer(script: TextRecognitionScript.latin);
        final result = await recognizer.processImage(inputImage);
        await recognizer.close();
        // Reconstruct reading order from word positions — ML Kit reads the
        // TEXT perfectly but returns receipt COLUMNS as separate blocks, so
        // "GRAND TOTAL:" and its amount end up 20 lines apart in result.text.
        // Re-joining lines by their y-position on the image puts label and
        // value back on the same line, which the keyword extraction needs.
        rawText = _reconstructReceiptText(result);
        debugPrint('ML Kit reconstructed layout:\n$rawText');

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

    // ── Duplicate check (hard stop — each bill can only be claimed once) ─────
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

    // ── Validation: bill date must be today ───────────────────────────────────
    // No longer a hard stop — flag it and let the confirm screen route the
    // user to manual (admin) review instead of bouncing back to the camera.
    String? issueCode;
    if (billDate != null) {
      final today = DateTime.now();
      final isSameDay = billDate.year  == today.year &&
                        billDate.month == today.month &&
                        billDate.day   == today.day;
      if (!isSameDay) issueCode = 'date_mismatch';
    }

    // ── Validation: scanned shop must match the Redeem Zone shop (if any) ─────
    // Only applies when this scan is tied to a specific Redeem Zone shop
    // (pendingShopId != null). The generic "Scan Bill" shortcut has no
    // target shop, so it's skipped entirely there.
    if (issueCode == null &&
        provider.pendingShopId != null &&
        shopName != null &&
        shopName.isNotEmpty &&
        !provider.matchesExpectedShop(shopName)) {
      issueCode = 'shop_mismatch';
    }

    // ── Validation: extracted result must be trustworthy ─────────────────────
    // If any field is missing, or came from a low-confidence ML Kit stage
    // (blind number guess / secondary shop-name scan), force manual review.
    // The low-confidence flags are only set when the regex extractors actually
    // ran — a fully successful Gemini scan never trips this. This prevents
    // showing a wrong amount/shop that the user might blindly confirm — the
    // confirm screen's default issue message handles this code.
    // Additionally: any scan done WITHOUT internet (AI never verified it)
    // always goes to manual review — the confirm screen shows the
    // "check internet & rescan" option for these.
    if (issueCode == null &&
        ((!netOk && !geminiSucceeded) ||
            total == null ||
            shopName == null ||
            shopName.isEmpty ||
            _totalLowConfidence ||
            _shopLowConfidence)) {
      issueCode = 'ocr_unverified';
      debugPrint('OCR low confidence — forcing manual review '
          '(totalLow=$_totalLowConfidence shopLow=$_shopLowConfidence)');
    }

    // ── Validation: high-value bills always go through admin review ──────────
    // Bills above ₹5,000 are routed to manual review as a fraud safeguard.
    // Shown to the user as a friendly "reward will be updated soon" note —
    // NOT as an error (see 'high_amount' handling in the confirm screen).
    if (issueCode == null && total != null && total > 5000) {
      issueCode = 'high_amount';
      debugPrint('High amount (₹$total > 5000) — routing to manual review');
    }

    if (!mounted) return;
    context.pushReplacement(
      '/bill-reader/confirm',
      extra: issueCode != null ? {'issueCode': issueCode} : null,
    );
  }

  // ── Internet check ──────────────────────────────────────────────────────────
  // Fast DNS lookup (3s cap) — much quicker feedback than waiting for the
  // Gemini HTTP call to time out on a dead/weak connection.
  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress
          .lookup('generativelanguage.googleapis.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── ML Kit layout reconstruction ────────────────────────────────────────────
  // ML Kit returns receipt columns as separate text blocks, scrambling the
  // reading order. This rebuilds visual lines: collect every recognized line
  // with its bounding box, sort top-to-bottom, group lines whose vertical
  // centers align (same printed row), then sort each row left-to-right.
  String _reconstructReceiptText(RecognizedText result) {
    final lines = <TextLine>[];
    for (final block in result.blocks) {
      lines.addAll(block.lines);
    }
    if (lines.isEmpty) return result.text;

    lines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    final rows = <List<TextLine>>[];
    for (final line in lines) {
      final cy = line.boundingBox.center.dy;
      var placed = false;
      for (final row in rows) {
        final rowCy = row.first.boundingBox.center.dy;
        final rowH  = row.first.boundingBox.height;
        // Same printed row if vertical centers are within ~60% of line height
        if ((cy - rowCy).abs() < rowH * 0.6) {
          row.add(line);
          placed = true;
          break;
        }
      }
      if (!placed) rows.add([line]);
    }

    final buf = StringBuffer();
    for (final row in rows) {
      row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      buf.writeln(row.map((l) => l.text).join(' '));
    }
    return buf.toString();
  }

  // ── Extract: Total amount ───────────────────────────────────────────────────

  double? _extractTotal(String rawText) {
    debugPrint('═══ OCR RAW TEXT ═══\n$rawText\n════════════════════');
    _totalLowConfidence = false;

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

    // ── Remove lines that commonly hold WRONG amounts ────────────────────────
    // Discount / savings rows, cash tendered, change returned, loyalty points
    // and phone/GST lines must never be picked as the bill total.
    final excludeLine = RegExp(
      r'discount|sav(?:e|ed|ing|ings)\b|off\b|'
      r'tender|cash\s*receiv|change|balance\s*ret|round\s*off|'
      r'points|loyalty|'
      r'phone|mobile|tel\s*:|ph\s*[:\.]|gstin|gst\s*no|'
      // Bill/invoice/receipt NUMBER lines — "BILL NO: ST-2026/0894" must
      // never donate "2026" as the total (real bug seen in testing)
      r'bill\s*no|invoice\s*no|receipt\s*no|order\s*no|'
      r'voucher\s*no|txn|ref\s*no',
      caseSensitive: false,
    );
    final safeText = text
        .split('\n')
        .where((l) => !excludeLine.hasMatch(l))
        .join('\n');

    // Two delimiter variants:
    // • delim        — allows newlines; used only for Stage 1 where label and
    //                  value may span lines (e.g. "TOTAL AMOUNT:\n₹2008.80")
    // • delimStrict  — NO newlines; used for lower-priority standalone keywords
    //                  so "TOTAL\n360.00" doesn't capture the wrong number.
    // ( ) and * included: ML Kit renders the ₹ symbol inside label brackets
    // as empty parens — "GRAND TOTAL (₹):" becomes "GRAND TOTAL ():".
    const delim       = r'[ \t:=\-₹()*]*(?:rs\.?|Rs\.?)?[ \t\n]*';
    const delimStrict = r'[ \t:=\-₹()*]*(?:rs\.?|Rs\.?)?[ \t]*';

    // ── Cross-check: what the total SHOULD be from the bill's own math ──────
    // subtotal + taxes − discounts. Lets us verify the extracted total and
    // repair the classic "₹ misread as leading 7" (₹920.40 → "7920.40").
    final expected = _expectedTotalFromParts(text);

    double finalize(double v) {
      if (expected == null) return v;
      if ((v - expected).abs() <= 1.0) {
        _totalLowConfidence = false; // corroborated by the bill's own math
        return v;
      }
      // If stripping a leading '7' makes the amount equal the bill's math,
      // the 7 was the rupee symbol — repair it.
      final s = v.toStringAsFixed(2);
      if (s.startsWith('7')) {
        final stripped = double.tryParse(s.substring(1));
        if (stripped != null && (stripped - expected).abs() <= 1.0) {
          debugPrint('OCR total repaired: ₹ read as 7 → $stripped (was $v)');
          _totalLowConfidence = false;
          return stripped;
        }
      }
      // Total disagrees with the bill's own arithmetic — don't trust it
      _totalLowConfidence = true;
      return v;
    }

    // ── Stage 1: High-confidence grand total keywords (priority tiers) ───────
    // Uses delim (allows newlines) so the value found on the next line is caught.
    // Tier order matters: "GRAND TOTAL / NET PAYABLE / FINAL AMOUNT" style
    // labels are the amount actually paid AFTER discount, so they must beat
    // "TOTAL AMOUNT", which on discounted bills can be the pre-discount figure.
    // Within a tier we take the LAST match (not the largest) — the final total
    // is printed after any earlier pre-discount totals on the bill.
    final highConfidenceTiers = [
      // Tier A — final payable amount (after discount)
      '(?:grand\\s*total|net\\s*total|net\\s*amount|net\\s*payable|'
          'final\\s*amount|amount\\s*paid|amount\\s*due|amount\\s*payable|'
          'payable\\s*amount|total\\s*payable)'
          '$delim'
          r'([0-9][0-9,]{0,8}(?:\.[0-9]{1,2})?)',
      // Tier B — generic total labels
      '(?:total\\s*amount|total\\s*bill|bill\\s*total|bill\\s*amount|'
          'invoice\\s*total|invoice\\s*value)'
          '$delim'
          r'([0-9][0-9,]{0,8}(?:\.[0-9]{1,2})?)',
    ];

    for (final pattern in highConfidenceTiers) {
      final matches = RegExp(pattern, caseSensitive: false, multiLine: true)
          .allMatches(safeText)
          .toList();
      for (final m in matches.reversed) {
        final val = parseNum(m.group(1));
        if (val != null) {
          debugPrint('OCR total found via high-confidence keyword: $val');
          return finalize(val);
        }
      }
    }

    // ── Stage 2: Lower-priority keyword patterns ──────────────────────────────
    // Uses delimStrict (no newlines) to prevent "TOTAL\n360.00" from matching
    // the column header "TOTAL" and stealing the first item's line-price (₹360).
    // FIX: plain "TOTAL" must be tried BEFORE "SUBTOTAL" — on discounted bills
    // the subtotal is the pre-discount figure and is the WRONG total. Within
    // "total" we take the LAST match (final total prints after subtotal).
    final lowerPatterns = [
      '(?:^|[ \\t])total$delimStrict'
          r'([0-9][0-9,]{0,8}(?:\.[0-9]{1,2})?)',
      '(?:^|[ \\t])amount$delimStrict'
          r'([0-9][0-9,]{0,8}(?:\.[0-9]{1,2})?)',
      '(?:^|[ \\t])amt$delimStrict'
          r'([0-9][0-9,]{0,8}(?:\.[0-9]{1,2})?)',
      '(?:sub\\s*total|subtotal)$delimStrict'
          r'([0-9][0-9,]{0,8}(?:\.[0-9]{1,2})?)',
      r'₹\s*([0-9][0-9,]{0,8}(?:\.[0-9]{1,2})?)',
    ];

    for (final pattern in lowerPatterns) {
      final matches = RegExp(pattern, caseSensitive: false, multiLine: true)
          .allMatches(safeText)
          .toList();
      for (final m in matches.reversed) {
        final val = parseNum(m.group(1));
        if (val != null) {
          debugPrint('OCR total found via lower-priority keyword: $val');
          return finalize(val);
        }
      }
    }

    // ── Stage 3: Line scan — collect ALL keyword lines, return LARGEST ────────
    // Bug fix: the old code returned on the FIRST matching line (which could be
    // "SUBTOTAL" or the column header "TOTAL" next to item ₹360). We now scan
    // ALL matching lines and return the largest valid amount found.
    // Amounts WITH decimals (450.00) are preferred over bare integers —
    // bare integers on keyword lines are often bill numbers, years or counts.
    double? lineScanDecimal;
    double? lineScanPlain;
    for (final line in safeText.split('\n')) {
      // Skip lines that are only the column header (no digits on the line)
      if (!RegExp(r'\d').hasMatch(line)) continue;
      // Skip subtotal rows — pre-discount figure, never the final total
      if (RegExp(r'sub\s*total|subtotal', caseSensitive: false)
          .hasMatch(line)) continue;
      if (RegExp(r'total|amount|amt|bill|payable|due',
              caseSensitive: false).hasMatch(line)) {
        final numMatches =
            RegExp(r'([0-9][0-9,\s]{0,8}(?:\.[0-9]{1,2})?)').allMatches(line);
        for (final nm in numMatches) {
          final raw = nm.group(1)!;
          final val = parseNum(raw);
          if (val == null) continue;
          if (raw.contains('.')) {
            if (lineScanDecimal == null || val > lineScanDecimal) {
              lineScanDecimal = val;
            }
          } else {
            if (lineScanPlain == null || val > lineScanPlain) {
              lineScanPlain = val;
            }
          }
        }
      }
    }
    final lineScanBest = lineScanDecimal ?? lineScanPlain;
    if (lineScanBest != null) {
      _totalLowConfidence = true; // no explicit label — needs user check
      debugPrint('OCR total found via line scan: $lineScanBest');
      return finalize(lineScanBest);
    }

    // ── Stage 4: Absolute fallback — largest number in the whole text ─────────
    // Prefer amounts WITH decimals (e.g. 450.00) — money values on receipts
    // are printed with paise, while phone numbers, PINs and quantities are not.
    final rawMatches = RegExp(
            r'(?<!\d)([0-9]{2,}(?:[,\s][0-9]{3})*(?:\.[0-9]{1,2})?)(?!\d)')
        .allMatches(safeText)
        .map((m) => m.group(1)!)
        .toList();

    final decimalNums = rawMatches
        .where((s) => s.contains('.'))
        .map(parseNum)
        .whereType<double>()
        .toList();
    if (decimalNums.isNotEmpty) {
      decimalNums.sort();
      _totalLowConfidence = true; // blind guess — needs user check
      debugPrint('OCR total fallback (largest decimal): ${decimalNums.last}');
      return finalize(decimalNums.last);
    }

    final allNums =
        rawMatches.map(parseNum).whereType<double>().toList();
    if (allNums.isNotEmpty) {
      allNums.sort();
      final largest = allNums.last;
      _totalLowConfidence = true; // blind guess — needs user check
      debugPrint('OCR total fallback (largest number): $largest');
      return finalize(largest);
    }

    debugPrint('OCR: no total found');
    return null;
  }

  // ── Expected total from the bill's own arithmetic ───────────────────────────
  // subtotal + taxes − discounts. Every part must be printed WITH paise
  // digits (".00") — that automatically skips percentages ("@ 9%") and
  // quantities. Returns null when the bill doesn't print a decimal subtotal.
  double? _expectedTotalFromParts(String text) {
    double? parseAmt(String? raw) {
      if (raw == null) return null;
      final v = double.tryParse(raw.replaceAll(RegExp(r'[,\s₹]'), ''));
      return (v != null && v > 0 && v <= 500000) ? v : null;
    }

    const amt = r'([0-9][0-9,]{0,8}\.[0-9]{2})';

    final subM =
        RegExp('sub[\\s\\-]*total[^0-9\\n]*$amt', caseSensitive: false)
            .firstMatch(text);
    final subtotal = parseAmt(subM?.group(1));
    if (subtotal == null) return null;

    double taxes = 0;
    for (final m in RegExp(
            '(?:[cis]gst(?!in)|\\bgst(?!in)\\b|tax(?!\\s*invoice)|vat|cess)'
            '[^0-9\\n]*(?:[0-9.]+\\s*%)?[^0-9\\n]*$amt',
            caseSensitive: false)
        .allMatches(text)) {
      taxes += parseAmt(m.group(1)) ?? 0;
    }

    double discounts = 0;
    for (final m in RegExp(
            '(?:discount|savings?)[^0-9\\n]*(?:[0-9.]+\\s*%)?[^0-9\\n]*$amt',
            caseSensitive: false)
        .allMatches(text)) {
      discounts += parseAmt(m.group(1)) ?? 0;
    }

    final expected = subtotal + taxes - discounts;
    if (expected <= 0) return null;
    debugPrint('OCR expected total from parts: '
        '$subtotal + $taxes − $discounts = $expected');
    return expected;
  }

  // ── Extract: Shop name ──────────────────────────────────────────────────────
  // Primary pass  : first clean lines before any stop keyword (works when the
  //                 shop name is at the very top of the OCR output).
  // Secondary pass: scans ALL lines and skips any that look like dates, times,
  //                 addresses, or receipt metadata — then returns the first
  //                 ALL-CAPS candidate.  This handles receipts where ML Kit
  //                 reads the date block before the business name block.

  String? _extractShopName(String rawText) {
    _shopLowConfidence = false;
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

    // Generic header words that are NOT the shop name — SKIP them (don't stop)
    // so a shop name printed below "TAX INVOICE" etc. is still found.
    final headerJunk = RegExp(
      r'^\s*(?:tax\s*invoice|retail\s*invoice|cash\s*memo|'
      r'bill\s*of\s*supply|customer\s*copy|duplicate|original|'
      r'estimate|welcome|receipt|invoice|bill|'
      // Item-table column headers — ML Kit reads these as standalone lines
      // and they must never be picked as the shop name ("ITEM DESCRIPTION")
      r'(?:item\s*)?description|item|rate\s*\(?[a-z]*\)?|qty|quantity|'
      r's\.?\s*no\.?|sl\.?\s*no\.?|hsn|mrp|'
      r'total\s*items.*|grand\s*total.*|mode\s*:.*)\s*$'
      r'|^[\*\-=_#\.]+$',                 // decorative separator lines
      caseSensitive: false,
    );

    // ── Primary pass: first clean lines before any stop keyword ──────────────
    final shopLines = <String>[];
    var scanned = 0;
    for (final line in lines) {
      if (scanned >= 8) break;
      scanned++;
      if (stopPattern.hasMatch(line)) break;
      if (headerJunk.hasMatch(line)) continue;   // skip junk, keep looking
      final alphaCount = RegExp(r'[a-zA-Z]').allMatches(line).length;
      if (line.length > 3 && alphaCount < 2) continue; // digits/symbols line
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
      if (headerJunk.hasMatch(line)) continue;   // "TAX INVOICE", "WELCOME"…

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
        // Secondary pass is a guess — item names are also ALL-CAPS, so
        // this may pick a product line. Flag for manual verification.
        _shopLowConfidence = true;
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
    final billProvider   = context.watch<BillRewardProvider>();
    final hasShopContext = billProvider.pendingShopId != null;
    final isRedeem       = billProvider.isPendingRedeem;
    final shopLabel      = billProvider.pendingExpectedShopName ??
        (isRedeem ? 'Redeem Shop' : 'Reward Shop');
    final redeemDiscount = billProvider.pendingDiscount ?? 0;

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
            if (hasShopContext) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBDEFB)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded,
                        color: _blue, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        shopLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _blue,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isRedeem && redeemDiscount > 0)
                      Text(
                        '$redeemDiscount% OFF',
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else if (!isRedeem)
                      const Text(
                        'CASHBACK + POINTS',
                        style: TextStyle(
                          color: Color(0xFF1565C0),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ],
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

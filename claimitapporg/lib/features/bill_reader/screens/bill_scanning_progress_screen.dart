import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../providers/bill_reward_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BillScanningProgressScreen
// Runs real OCR on the captured bill image, shows animated progress,
// then pushes to BillConfirmScreen with the extracted total.
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
    'Detecting text with OCR…',
    'Extracting total amount…',
  ];

  double? _extractedTotal;
  bool _ocrDone = false;

  @override
  void initState() {
    super.initState();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _progressAnim = CurvedAnimation(
        parent: _progressCtrl, curve: Curves.easeInOut);
    _progressCtrl.forward();

    // Show checklist steps
    int step = 0;
    _stepTimer = Timer.periodic(const Duration(milliseconds: 800), (t) {
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

    // Run OCR
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
    double? total;
    try {
      final inputImage = InputImage.fromFilePath(widget.imagePath);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result = await recognizer.processImage(inputImage);
      await recognizer.close();
      total = _extractTotal(result.text);
    } catch (e) {
      debugPrint('OCR error: $e');
    }

    // Wait at least enough for the animation to look complete
    await Future.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;

    setState(() {
      _extractedTotal = total;
      _ocrDone = true;
    });

    // Populate provider with real (or fallback) data
    context.read<BillRewardProvider>().setScanResult(
      totalAmount: total,
      imagePath: widget.imagePath,
    );

    // Push to confirm screen
    context.pushReplacement('/bill-reader/confirm');
  }

  /// Parse the highest-confidence total amount from OCR text.
  double? _extractTotal(String text) {
    // Ordered by specificity — first match wins
    final patterns = [
      r'(?:grand\s*total|net\s*total|net\s*amount|total\s*amount|total\s*bill|bill\s*total|amount\s*due|amount\s*payable)\s*[:\s]*[₹rs\.]*\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      r'(?:total)\s*[:\s]*[₹rs\.]*\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      r'[₹]\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    ];

    double? best;
    for (final pattern in patterns) {
      final matches = RegExp(pattern, caseSensitive: false)
          .allMatches(text);
      for (final m in matches) {
        final raw = m.group(1)!.replaceAll(',', '');
        final val = double.tryParse(raw);
        // Ignore implausibly small or large amounts
        if (val != null && val >= 10 && val <= 500000) {
          if (best == null || val > best) best = val;
        }
      }
      if (best != null) break; // use most-specific pattern's result
    }
    return best;
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
      body: Padding(
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

            // Checklist
            ..._steps.asMap().entries.map((e) {
              final visible = e.key < _visibleSteps;
              final isDone = _ocrDone || e.key < _visibleSteps;
              return AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
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

            const SizedBox(height: 16),

            // Bill image preview
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.cover,
                  width: double.infinity,
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
          ],
        ),
      ),
    );
  }
}

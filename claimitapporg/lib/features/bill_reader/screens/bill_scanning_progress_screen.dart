import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/bill_reward_provider.dart';

class BillScanningProgressScreen extends StatefulWidget {
  const BillScanningProgressScreen({super.key});

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

  final List<String> _steps = [
    'Upload or scan the shop bill',
    'The app will auto-read Shop Name and Bill Amount',
    'If the bill is long (up to 50cm), the app reads full bill',
  ];

  int _visibleSteps = 0;
  late Timer _stepTimer;

  @override
  void initState() {
    super.initState();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _progressAnim = CurvedAnimation(
      parent: _progressCtrl,
      curve: Curves.easeInOut,
    );
    _progressCtrl.forward();

    // Reveal checklist steps one by one
    int step = 0;
    _stepTimer = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (step < _steps.length) {
          _visibleSteps = step + 1;
          step++;
        } else {
          t.cancel();
        }
      });
    });

    // Navigate to success after scanning completes
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        context.read<BillRewardProvider>().claimReward();
        context.pushReplacement('/bill-reader/success');
      }
    });
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _stepTimer.cancel();
    super.dispose();
  }

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
          'Bill Reader',
          style: TextStyle(
              color: _blue, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              'Scanning',
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
                  value: _progressAnim.value,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE0E0E0),
                  valueColor: const AlwaysStoppedAnimation<Color>(_blue),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Checklist items
            ..._steps.asMap().entries.map((e) {
              final visible = e.key < _visibleSteps;
              return AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: visible
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: visible
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: visible
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

            // Bill image placeholder
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  'https://images.unsplash.com/photo-1572635196237-14b3f281503f?w=500&q=80',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF5F5F5),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.receipt_long_rounded,
                              size: 60, color: Color(0xFFBDBDBD)),
                          SizedBox(height: 8),
                          Text('Bill preview',
                              style: TextStyle(color: Color(0xFFBDBDBD))),
                        ],
                      ),
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

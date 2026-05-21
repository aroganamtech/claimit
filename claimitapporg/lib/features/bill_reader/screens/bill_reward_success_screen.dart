import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/bill_reward_provider.dart';
import '../models/bill_reward_model.dart';

class BillRewardSuccessScreen extends StatefulWidget {
  const BillRewardSuccessScreen({super.key});

  @override
  State<BillRewardSuccessScreen> createState() =>
      _BillRewardSuccessScreenState();
}

class _BillRewardSuccessScreenState extends State<BillRewardSuccessScreen>
    with TickerProviderStateMixin {
  static const _blue = Color(0xFF1565C0);

  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // We capture the entry at build time so we can display it even after
  // claimReward() clears _lastScanned.
  BillRewardEntry? _entry;

  @override
  void initState() {
    super.initState();

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleCtrl,
      curve: Curves.elasticOut,
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _scaleCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeCtrl.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capture most-recently added history entry (already committed by scanning screen)
    final provider = context.read<BillRewardProvider>();
    if (_entry == null && provider.history.isNotEmpty) {
      _entry = provider.history.first;
    }
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _blue, size: 20),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'Reward zone',
          style: TextStyle(
              color: _blue, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // ── Green checkmark ──────────────────────────────────────────
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 52),
                ),
              ),

              const SizedBox(height: 20),

              // ── Reward points ────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Coin icon
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAB308),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'C+',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry != null ? '${entry.rewardPoints}' : '--',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Success message ──────────────────────────────────────────
              const Text(
                'Successfully Reward Claimed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _blue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry != null
                    ? 'Your ${entry.rewardPoints} Redeem Points is Added in wallet.'
                    : 'Your Redeem Points are Added in wallet.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF757575),
                ),
              ),

              // Confetti-like dots decorations
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  6,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: [
                        Colors.red,
                        Colors.blue,
                        Colors.green,
                        Colors.orange,
                        Colors.purple,
                        Colors.pink,
                      ][i],
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Bill detail card ─────────────────────────────────────────
              if (entry != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.shopName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total Bill: ₹${entry.totalBill.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF555555)),
                            ),
                            Text(
                              'Discount: ₹${entry.discount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF555555)),
                            ),
                          ],
                        ),
                      ),
                      // Receipt thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 60,
                          height: 72,
                          color: const Color(0xFFF5F5F5),
                          child: const Icon(Icons.receipt_long_rounded,
                              color: Color(0xFFBDBDBD), size: 36),
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // ── Continue button ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.pushReplacement('/bill-reader/wallet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

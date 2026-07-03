import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/bill_reward_provider.dart';
import '../models/bill_reward_model.dart';
import '../../dashboard/screens/dashboard_screen.dart' show showReelzAdIfReady;

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
    // Show new-user welcome-bonus popup once
    if (provider.showNewUserBonusPopup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showBonusDialog(provider.bonusPoints);
        provider.dismissBonusPopup();
      });
    }
    // NOTE: the auto-popup ad (3 s into this screen) was removed — it
    // interrupted the user while reading their reward. The interstitial now
    // shows on the Continue button instead (natural transition point),
    // with frequency rules handled inside showReelzAdIfReady().
  }

  void _showBonusDialog(int pts) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                  color: Color(0xFFFFF8E1), shape: BoxShape.circle),
              child: const Center(
                child: Text('🎉', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Welcome Bonus!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 10),
            Text(
              'You just earned $pts free reward points\nas a welcome gift!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF374151), height: 1.5),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(dlgCtx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Awesome!'),
            ),
          ),
        ],
      ),
    );
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
      body: SafeArea(
        top: false,
        child: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
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

              // ── Success message ──────────────────────────────────────────
              Text(
                (entry?.isRedeem ?? false)
                    ? 'Discount Redeemed Successfully!'
                    : 'Reward Claimed Successfully!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _blue,
                ),
              ),
              const SizedBox(height: 18),

              // ── Reward breakdown card ────────────────────────────────────
              if (entry != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Bill amount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text('Bill Amount',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 14)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹${entry.totalBill.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(
                          color: Colors.white24, height: 20, thickness: 0.8),
                      if (entry.isRedeem) ...[
                        // Discount row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.percent_rounded,
                                      color: Colors.white70, size: 16),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text('Discount Applied',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: Colors.white70, fontSize: 14)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${entry.discount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Color(0xFF90EE90),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Points deducted row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.remove_circle_outline_rounded,
                                      color: Colors.white70, size: 16),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text('Points Used',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: Colors.white70, fontSize: 14)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '− ${BillRewardEntry.fmtPoints(entry.pointsDeducted)} pts',
                              style: const TextStyle(
                                  color: Color(0xFFFFCDD2),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Cashback row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.account_balance_rounded,
                                      color: Colors.white70, size: 16),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text('Cashback (1%)',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: Colors.white70, fontSize: 14)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+ ₹${entry.cashback.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Color(0xFF90EE90),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Reward points row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.stars_rounded,
                                      color: Colors.white70, size: 16),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text('Reward Points (10%)',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: Colors.white70, fontSize: 14)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+ ${BillRewardEntry.fmtPoints(entry.rewardPoints)} pts',
                              style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              Text(
                entry == null
                    ? 'Your rewards have been added to your wallet.'
                    : entry.isRedeem
                        ? '₹${entry.discount.toStringAsFixed(0)} discount applied · ${BillRewardEntry.fmtPoints(entry.pointsDeducted)} points used from your wallet.'
                        : '₹${entry.cashback.toStringAsFixed(0)} cashback & ${BillRewardEntry.fmtPoints(entry.rewardPoints)} points added to your wallet.',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                              entry.isRedeem
                                  ? 'Points Used: ${BillRewardEntry.fmtPoints(entry.pointsDeducted)} pts'
                                  : 'Cashback: ₹${entry.cashback.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF2563EB)),
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

              const SizedBox(height: 24),

              // ── Continue button ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    // Traditional interstitial placement: between finishing
                    // the scan flow and the next screen. Frequency rules
                    // (every 2nd scan, 5-min cooldown, 3/session) are inside.
                    await showReelzAdIfReady(context);
                    if (context.mounted) {
                      context.pushReplacement('/bill-reader/wallet');
                    }
                  },
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
          ),          // Column
        ),            // SingleChildScrollView
        ),            // FadeTransition
      ),              // SafeArea
    );
  }
}

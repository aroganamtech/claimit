import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/bill_reward_model.dart';
import '../providers/bill_reward_provider.dart';

class BillRewardWalletScreen extends StatelessWidget {
  const BillRewardWalletScreen({super.key});

  static const _blue = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _blue, size: 20),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'Reward Wallet zone',
          style: TextStyle(
              color: _blue, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: Consumer<BillRewardProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // ── Blue summary card ─────────────────────────────────────────
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _blue.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _WalletRow(
                      label: 'Lifetime Cashback',
                      value:
                          '₹ ${provider.lifetimeCashback.toStringAsFixed(0)}',
                      valueFontSize: 26,
                    ),
                    const Divider(
                        color: Colors.white24, height: 24, thickness: 0.8),
                    _WalletRow(
                      label: 'Current Reward points',
                      prefixWidget: _CoinBadge(),
                      value: '${provider.currentPoints}',
                      valueFontSize: 22,
                    ),
                    const Divider(
                        color: Colors.white24, height: 24, thickness: 0.8),
                    _WalletRow(
                      label: 'Cashback Wallet',
                      value:
                          '₹ ${provider.cashbackWallet.toStringAsFixed(0)}',
                      valueFontSize: 22,
                    ),
                    const SizedBox(height: 16),
                    // Redeem Now button
                    // SizedBox(
                    //   width: double.infinity,
                    //   height: 44,
                    //   child: OutlinedButton.icon(
                    //     onPressed: () => context.push('/profile'),
                    //     icon: const Icon(Icons.storefront_rounded, size: 26),
                    //     label: const Text(
                    //       'Redeem Now',
                    //       style: TextStyle(
                    //           fontSize: 15, fontWeight: FontWeight.bold),
                    //     ),
                    //     style: OutlinedButton.styleFrom(
                    //       foregroundColor: Colors.white,
                    //       side: const BorderSide(
                    //           color: Colors.white70, width: 1.5),
                    //       shape: RoundedRectangleBorder(
                    //           borderRadius: BorderRadius.circular(24)),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),

              // ── History header ────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 4, 18, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Reward history',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),

              // ── History list ──────────────────────────────────────────────
              Expanded(
                child: provider.history.isEmpty
                    ? const Center(
                        child: Text(
                          'No rewards yet.\nScan a bill to get started!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey, fontSize: 15, height: 1.6),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: provider.history.length,
                        itemBuilder: (ctx, i) =>
                            _HistoryTile(entry: provider.history[i]),
                      ),
              ),
            ],
          );
        },
      ),

      // ── Scan another bill FAB ──────────────────────────────────────────────
      // floatingActionButton: FloatingActionButton.extended(
      //   backgroundColor: _blue,
      //   foregroundColor: Colors.white,
      //   icon: const Icon(Icons.qr_code_scanner_rounded),
      //   label: const Text('Scan Bill',
      //       style: TextStyle(fontWeight: FontWeight.bold)),
      //   onPressed: () => context.push('/bill-reader/scanner'),
      // ),
    );
  }
}

// ── Wallet summary row ────────────────────────────────────────────────────────
class _WalletRow extends StatelessWidget {
  final String label;
  final String value;
  final double valueFontSize;
  final Widget? prefixWidget;

  const _WalletRow({
    required this.label,
    required this.value,
    this.valueFontSize = 20,
    this.prefixWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        if (prefixWidget != null) ...[
          prefixWidget!,
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: Colors.white,
              fontSize: valueFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Coin badge ────────────────────────────────────────────────────────────────
class _CoinBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
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
            fontSize: 9,
          ),
        ),
      ),
    );
  }
}

// ── History tile ──────────────────────────────────────────────────────────────
class _HistoryTile extends StatelessWidget {
  final BillRewardEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy | hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Shop avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: entry.shopColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                entry.shopName[0].toUpperCase(),
                style: TextStyle(
                  color: entry.shopColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Shop name + date
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
                    fontSize: 14,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateFmt.format(entry.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),

          // Amount + cashback + points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${entry.totalBill.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1565C0),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'CB ₹${entry.cashback.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CoinBadge(),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.rewardPoints} pts',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

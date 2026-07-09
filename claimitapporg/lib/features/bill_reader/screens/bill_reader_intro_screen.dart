import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shops/models/shop_category.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BillReaderIntroScreen
// Entry point for the bottom-nav "Scan Bill" button. The user must first
// choose WHICH kind of bill they're about to scan, since the two flows are
// mutually exclusive and have different reward logic:
//
//   • Redeem Bill  — user already has points; pick a Redeem Zone shop,
//                    confirm eligibility, then scan to SPEND points against
//                    a discount. No cashback/points are ever earned here.
//   • Reward Bill  — no discount upfront; pick a Reward Zone shop, pay full
//                    price, then scan afterward to EARN cashback + points.
//                    No points are ever spent here.
// ─────────────────────────────────────────────────────────────────────────────

class BillReaderIntroScreen extends StatelessWidget {
  const BillReaderIntroScreen({super.key});

  static const _blue  = Color(0xFF1565C0);
  static const _green = Color(0xFF059669);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _blue, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Scan Bill',
          style: TextStyle(
            color: _blue,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What kind of bill are you scanning?',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose the option that matches your purchase before scanning.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              _ChoiceCard(
                color: _blue,
                bgColor: const Color(0xFFE3F2FD),
                icon: Icons.card_giftcard_rounded,
                title: 'Reward Bill',
                subtitle: 'Pay full price at a Reward Zone shop, then scan '
                    'the bill to earn cashback + reward points.',
                buttonLabel: 'Select Reward Shop',
                onTap: () => context.push(
                  '/shops',
                  extra: const ShopCategory(
                    id: 0,
                    name: 'Reward Zone',
                    icon: Icons.card_membership_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
                const SizedBox(height: 16),
              // ── Redeem Bill option ───────────────────────────────────────
              _ChoiceCard(
                color: _green,
                bgColor: const Color(0xFFE8F5E9),
                icon: Icons.redeem_rounded,
                title: 'Redeem Bill',
                subtitle: 'Use your existing points to claim a discount at a '
                    'Redeem Zone shop. Plus additional Rewards points And 1% Cashback',
                buttonLabel: 'Select Redeem Shop',
                onTap: () => context.push(
                  '/shops',
                  extra: const ShopCategory(
                    id: -1,
                    name: 'Redeem Zone',
                    icon: Icons.redeem_rounded,
                    color: Color(0xFF059669),
                  ),
                ),
              ),

              

              // ── Reward Bill option ───────────────────────────────────────
              
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final Color color;
  final Color bgColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

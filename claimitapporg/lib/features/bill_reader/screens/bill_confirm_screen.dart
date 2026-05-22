import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/bill_reward_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BillConfirmScreen
// Shows the scanned image + OCR-extracted total.
// User confirms the amount (or corrects it) before reward is claimed.
// ─────────────────────────────────────────────────────────────────────────────

class BillConfirmScreen extends StatefulWidget {
  const BillConfirmScreen({super.key});

  @override
  State<BillConfirmScreen> createState() => _BillConfirmScreenState();
}

class _BillConfirmScreenState extends State<BillConfirmScreen> {
  static const _blue = Color(0xFF1565C0);
  static const _green = Color(0xFF2E7D32);

  late TextEditingController _amtCtrl;
  bool _confirmed = false;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<BillRewardProvider>();
    final total = provider.pendingTotal;
    _amtCtrl = TextEditingController(
      text: total != null ? total.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmAndClaim() async {
    final raw = _amtCtrl.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the total bill amount')),
      );
      return;
    }
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid bill amount')),
      );
      return;
    }

    setState(() => _claiming = true);
    final provider = context.read<BillRewardProvider>();
    provider.updatePendingTotal(amount);

    // Call backend to record scan + update reward points
    await provider.claimReward();

    if (!mounted) return;
    setState(() => _claiming = false);
    context.pushReplacement('/bill-reader/success');
  }

  void _rescan() {
    context.go('/bill-reader/scanner');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<BillRewardProvider>();
    final imagePath = provider.pendingImagePath;
    final extractedTotal = provider.pendingTotal;
    final points = _estimatedPoints;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _blue, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Confirm Bill',
          style: TextStyle(
              color: _blue, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status banner ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: extractedTotal != null
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: extractedTotal != null
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF9800),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    extractedTotal != null
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: extractedTotal != null
                        ? _green
                        : const Color(0xFFF57C00),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      extractedTotal != null
                          ? 'Total amount detected! Please verify it is correct.'
                          : 'Could not auto-detect total. Please enter the amount manually.',
                      style: TextStyle(
                        fontSize: 13,
                        color: extractedTotal != null
                            ? _green
                            : const Color(0xFFF57C00),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Bill image ────────────────────────────────────────────────
            if (imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF5F5F5),
                      child: const Center(
                        child: Icon(Icons.receipt_long_rounded,
                            size: 56, color: Color(0xFFBDBDBD)),
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // ── Amount entry ──────────────────────────────────────────────
            const Text(
              'Total Bill Amount (₹)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _amtCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _blue),
              decoration: InputDecoration(
                prefixText: '₹  ',
                prefixStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9CA3AF)),
                hintText: '0',
                hintStyle: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 28),
                filled: true,
                fillColor: const Color(0xFFF8FAFF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: _blue, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
              ),
            ),

            const SizedBox(height: 16),

            // ── Reward preview ────────────────────────────────────────────
            if (points > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEAB308),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('C+',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('You will earn',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF92400E))),
                        Text(
                          '+$points reward points',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // ── Confirm button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _claiming ? null : _confirmAndClaim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                child: _claiming
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Yes, Claim Reward',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 12),

            // ── Rescan button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _rescan,
                icon: const Icon(Icons.qr_code_scanner_rounded,
                    size: 20),
                label: const Text('Scan Again',
                    style: TextStyle(fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: const BorderSide(color: _blue, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  int get _estimatedPoints {
    final raw = _amtCtrl.text.trim();
    final amount = double.tryParse(raw) ?? 0;
    return (amount * 0.1).round();
  }
}

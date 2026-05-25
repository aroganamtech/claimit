import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/bill_reward_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BillConfirmScreen
// Shows the scanned image + OCR-extracted data:
//   • Shop name  (editable)
//   • Bill date  (from OCR)   — must be today
//   • Scan time  (now)
//   • Total amount  (editable)
// On confirm: runs duplicate check before claiming reward.
// ─────────────────────────────────────────────────────────────────────────────

class BillConfirmScreen extends StatefulWidget {
  const BillConfirmScreen({super.key});

  @override
  State<BillConfirmScreen> createState() => _BillConfirmScreenState();
}

class _BillConfirmScreenState extends State<BillConfirmScreen> {
  static const _blue  = Color(0xFF1565C0);
  static const _green = Color(0xFF2E7D32);

  late TextEditingController _amtCtrl;
  late TextEditingController _shopCtrl;
  bool _claiming    = false;
  bool _showOcrText = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<BillRewardProvider>();
    _amtCtrl  = TextEditingController(
      text: provider.pendingTotal != null
          ? provider.pendingTotal!.toStringAsFixed(0)
          : '',
    );
    _shopCtrl = TextEditingController(
      text: provider.pendingShopName ?? '',
    );
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _shopCtrl.dispose();
    super.dispose();
  }

  // ── Confirm & claim ─────────────────────────────────────────────────────────

  Future<void> _confirmAndClaim() async {
    final raw = _amtCtrl.text.trim();
    if (raw.isEmpty) {
      _snack('Please enter the total bill amount');
      return;
    }
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      _snack('Enter a valid bill amount');
      return;
    }

    final shopName = _shopCtrl.text.trim();
    if (shopName.isEmpty) {
      _snack('Please enter the shop name');
      return;
    }

    final provider   = context.read<BillRewardProvider>();
    final billDate   = provider.pendingBillDate ?? DateTime.now();
    final billNumber = provider.pendingBillNumber;

    // ── Duplicate check (Bill No + Shop + Date + Amount) ─────────────────────
    final alreadyScanned = provider.isDuplicate(
      shopName:   shopName,
      amount:     amount,
      billDate:   billDate,
      billNumber: billNumber,
    );

    if (alreadyScanned) {
      _showAlreadyScannedDialog(shopName, amount, billDate);
      return;
    }

    // ── Proceed ───────────────────────────────────────────────────────────────
    setState(() => _claiming = true);
    provider.updatePendingTotal(amount);
    provider.updatePendingShopName(shopName);

    await provider.claimReward();

    if (!mounted) return;
    setState(() => _claiming = false);
    context.pushReplacement('/bill-reader/success');
  }

  void _showAlreadyScannedDialog(
      String shopName, double amount, DateTime billDate) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3E0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: Color(0xFFF57C00), size: 34),
            ),
            const SizedBox(height: 16),
            const Text(
              'Already Scanned!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 10),
            Text(
              'This bill from "$shopName" for ₹${amount.toStringAsFixed(0)} '
              'on ${_fmtDate(billDate)} has already been scanned.\n\n'
              'Each bill can only be redeemed once.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/bill-reader/scanner');
            },
            child: const Text('Scan Another Bill',
                style: TextStyle(color: _blue)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _rescan() => context.go('/bill-reader/scanner');

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _fmtDate(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  static String _fmtTime(DateTime d) {
    final h  = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$mi $ampm';
  }

  double get _billAmount => double.tryParse(_amtCtrl.text.trim()) ?? 0;
  int    get _estimatedPoints  => (_billAmount * 0.1).round();
  String get _cashbackPreview  => (_billAmount * 0.01).toStringAsFixed(0);

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider       = context.read<BillRewardProvider>();
    final imagePath      = provider.pendingImagePath;
    final extractedTotal = provider.pendingTotal;
    final ocrText        = provider.pendingOcrText ?? '';
    final billDate       = provider.pendingBillDate;
    final billNumber     = provider.pendingBillNumber;
    final now            = DateTime.now();
    // OCR fully succeeded only when at least the amount was extracted
    final ocrSuccess = extractedTotal != null;

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

            // ── Status banner ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: ocrSuccess
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ocrSuccess
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF9800),
                ),
              ),
              child: ocrSuccess
                  // ── OCR succeeded: simple green tick ─────────────────────
                  ? Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: _green, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Bill detected! Please verify the details below.',
                            style: TextStyle(
                                fontSize: 13, color: _green, height: 1.4),
                          ),
                        ),
                      ],
                    )
                  // ── OCR failed: client-specified message + Retake button ──
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.camera_enhance_rounded,
                                color: Color(0xFFF57C00), size: 22),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'We could not clearly read the bill. '
                                'Please retake the photo or enter '
                                'details manually.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFF57C00),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _rescan,
                            icon: const Icon(
                                Icons.camera_alt_outlined, size: 18),
                            label: const Text('Retake Photo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF57C00),
                              side: const BorderSide(
                                  color: Color(0xFFFF9800), width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8),
                              textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // ── Date & time info card ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  // Bill number — strongest duplicate-check field
                  _InfoRow(
                    icon: Icons.tag_rounded,
                    label: 'Bill Number',
                    value: billNumber?.isNotEmpty == true
                        ? billNumber!
                        : 'Not detected',
                    valueColor: billNumber?.isNotEmpty == true
                        ? const Color(0xFF374151)
                        : const Color(0xFFF57C00),
                  ),
                  const Divider(height: 16),
                  _InfoRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Bill Date (from receipt)',
                    value: billDate != null
                        ? _fmtDate(billDate)
                        : 'Not detected — using today',
                    valueColor: billDate != null
                        ? const Color(0xFF374151)
                        : const Color(0xFFF57C00),
                  ),
                  const Divider(height: 16),
                  _InfoRow(
                    icon: Icons.access_time_rounded,
                    label: 'Scan Time',
                    value: '${_fmtDate(now)}  ${_fmtTime(now)}',
                    valueColor: const Color(0xFF374151),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Bill image ────────────────────────────────────────────────────
            if (imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  // 180dp ≈ 22.5% of 800dp design baseline
                  height: MediaQuery.of(context).size.height * 0.225,
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

            const SizedBox(height: 20),

            // ── Shop name field ───────────────────────────────────────────────
            const Text(
              'Shop Name',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _shopCtrl,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: 'e.g. Big Bazaar, DMart…',
                prefixIcon: const Icon(Icons.storefront_rounded,
                    color: Color(0xFF2563EB), size: 22),
                hintStyle: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 14),
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
                    horizontal: 16, vertical: 16),
              ),
            ),

            const SizedBox(height: 16),

            // ── Amount field ──────────────────────────────────────────────────
            const Text(
              'Total Bill Amount (₹)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
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

            // ── Reward preview ────────────────────────────────────────────────
            if (_estimatedPoints > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You will earn after scan:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 10),
                    _RewardRow(
                      icon: Icons.receipt_long_rounded,
                      iconColor: const Color(0xFF6B7280),
                      label: 'Bill Amount',
                      value: '₹${_billAmount.toStringAsFixed(0)}',
                      valueColor: const Color(0xFF374151),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Divider(height: 1, color: Color(0xFFFFE082)),
                    ),
                    _RewardRow(
                      icon: Icons.account_balance_rounded,
                      iconColor: const Color(0xFF2563EB),
                      label: 'Cashback (1%)',
                      value: '₹$_cashbackPreview',
                      valueColor: const Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 6),
                    _RewardRow(
                      icon: Icons.stars_rounded,
                      iconColor: const Color(0xFFD97706),
                      label: 'Reward Points (10%)',
                      value: '$_estimatedPoints pts',
                      valueColor: const Color(0xFFD97706),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            // ── Raw OCR text (expandable) ─────────────────────────────────────
            if (ocrText.isNotEmpty)
              GestureDetector(
                onTap: () =>
                    setState(() => _showOcrText = !_showOcrText),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.text_snippet_outlined,
                              size: 28, color: Color(0xFF6B7280)),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'What OCR read (tap to expand)',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280)),
                            ),
                          ),
                          Icon(
                            _showOcrText
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 26,
                            color: const Color(0xFF6B7280),
                          ),
                        ],
                      ),
                      if (_showOcrText) ...[
                        const Divider(height: 12),
                        Text(
                          ocrText.trim().isEmpty
                              ? '(No text detected)'
                              : ocrText.trim(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF374151),
                            fontFamily: 'monospace',
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // ── Confirm button ────────────────────────────────────────────────
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 12),

            // ── Rescan button ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _rescan,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 28),
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
}

// ── Info row (date / scan time display) ──────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9CA3AF))),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: valueColor)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Reward breakdown row ──────────────────────────────────────────────────────
class _RewardRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;

  const _RewardRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF92400E))),
        ),
        Flexible(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: valueColor)),
        ),
      ],
    );
  }
}

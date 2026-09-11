import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/bill_reward_model.dart';
import '../providers/bill_reward_provider.dart';
import '../services/bill_service.dart';

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
  // Set by the scanning screen when OCR validation found a problem
  // ('date_mismatch' or 'shop_mismatch'). When non-null, this screen forces
  // manual-review mode and blocks the auto "Confirm & Claim" path.
  final String? validationIssue;

  const BillConfirmScreen({super.key, this.validationIssue});

  @override
  State<BillConfirmScreen> createState() => _BillConfirmScreenState();
}

class _BillConfirmScreenState extends State<BillConfirmScreen> {
  static const _blue  = Color(0xFF1565C0);
  static const _green = Color(0xFF2E7D32);

  late TextEditingController _amtCtrl;
  late TextEditingController _shopCtrl;
  bool _claiming         = false;
  bool _showOcrText      = false;
  bool _manualMode       = false;   // user chose to enter/fix manually
  bool _submittingManual = false;

  String? get _issue => widget.validationIssue;

  // 'high_amount' is not an error — it gets a friendly blue "thank you"
  // banner instead of the red error style.
  bool get _isFriendlyIssue => _issue == 'high_amount';

  String get _issueMessage {
    switch (_issue) {
      case 'high_amount':
        return 'Thank you! Bills above ₹5,000 are verified by our team. '
            'Please submit your bill — your reward will be updated soon.';
      case 'ocr_unverified':
        return 'We couldn\'t read this bill clearly — this can happen with '
            'a slow internet connection or a blurry photo. Check your '
            'connection and rescan, or fill in the details below and '
            'submit for manual review.';
      case 'date_mismatch':
        return 'The bill date doesn\'t match today\'s date. Please review '
            'the details below and submit for manual review.';
      case 'shop_mismatch':
        return 'The shop name on the bill doesn\'t match the shop you '
            'selected. Please review the details below and submit '
            'for manual review.';
      default:
        return 'We couldn\'t fully verify this bill automatically. Please '
            'review the details below and submit for manual review.';
    }
  }

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
    // Validation failures always force manual-review mode — the user can
    // still correct fields, but auto-claim is disabled (see _confirmAndClaim).
    if (_issue != null) {
      _manualMode = true;
    }
    _loadRates();
  }

  /// The reward percentages an admin has set — read from the same app-wide
  /// cache the shop cards and offer chips use, so this preview can never
  /// disagree with the number the user was shown on the way in.
  double get _cashbackPct => BillService.cashbackPercent;
  double get _pointsPct   => BillService.pointsPercent;

  Future<void> _loadRates() async {
    await BillService.instance.ensureRates();
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _shopCtrl.dispose();
    super.dispose();
  }

  // ── Confirm & claim ─────────────────────────────────────────────────────────

  Future<void> _confirmAndClaim() async {
    // Validation failure from OCR (date/shop mismatch) — block auto-claim
    // and push the user toward manual/admin review instead.
    if (_issue != null) {
      _snack(_isFriendlyIssue
          ? 'Please submit your bill — your reward will be updated soon!'
          : 'Please submit for review — this bill needs a manual check.');
      return;
    }

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
    final billTime   = provider.pendingBillTime;

    // ── Duplicate check (Shop + Date + Time + Amount) ────────────────────────
    final alreadyScanned = provider.isDuplicate(
      shopName:   shopName,
      amount:     amount,
      billDate:   billDate,
      billNumber: billNumber,
      billTime:   billTime,
    );

    if (alreadyScanned) {
      _showAlreadyScannedDialog(shopName, amount, billDate);
      return;
    }

    // ── Proceed ───────────────────────────────────────────────────────────────
    setState(() => _claiming = true);
    provider.updatePendingTotal(amount);
    provider.updatePendingShopName(shopName);

    try {
      await provider.claimReward();
    } on BillAlreadyScannedException {
      // Server confirmed this bill was already claimed (local cache may have
      // been cold — e.g. app reinstalled or SharedPreferences cleared).
      if (!mounted) return;
      setState(() => _claiming = false);
      _showAlreadyScannedDialog(shopName, amount, billDate);
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _claiming = false);
      _snack('Failed to claim reward. Please try again.');
      return;
    }

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

  Future<void> _submitForReview() async {
    final raw = _amtCtrl.text.trim();
    if (raw.isEmpty || (double.tryParse(raw) ?? 0) <= 0) {
      _snack('Please enter the bill amount before submitting');
      return;
    }
    final provider  = context.read<BillRewardProvider>();
    final imagePath = provider.pendingImagePath;
    if (imagePath == null || imagePath.isEmpty) {
      _snack('Bill image is required. Please retake the photo.');
      return;
    }

    setState(() => _submittingManual = true);
    try {
      final amount   = double.parse(raw);
      final shopName = _shopCtrl.text.trim();
      final reason   = _issue ?? (_manualMode ? 'wrong_data' : 'missing_fields');
      await BillService.instance.submitManualReview(
        totalAmount:  amount,
        imagePath:    imagePath,
        shopName:     shopName.isNotEmpty ? shopName : null,
        shopId:       provider.pendingShopId,
        scanType:     provider.pendingScanType,
        billNumber:   provider.pendingBillNumber,
        billDate:     provider.pendingBillDate,
        billTime:     provider.pendingBillTime,
        manualReason: reason,
      );
      if (!mounted) return;
      context.pushReplacement('/bill-reader/review-pending');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submittingManual = false);
    }
  }

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
  // Formatting lives on BillService so every screen renders the percentage
  // identically ("1" not "1.0", but "1.5" kept as "1.5").
  static String _fmtPct(double v) => BillService.fmtPct(v);

  // Both use the admin-set rates rather than a hard-coded 1% / 10%, so this
  // preview always matches what the server credits.
  double get _estimatedPoints  => _billAmount * _pointsPct / 100;
  String get _cashbackPreview  =>
      (_billAmount * _cashbackPct / 100).toStringAsFixed(0);

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider       = context.read<BillRewardProvider>();
    final imagePath      = provider.pendingImagePath;
    final extractedTotal = provider.pendingTotal;
    final ocrText        = provider.pendingOcrText ?? '';
    final billDate       = provider.pendingBillDate;
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

            // ── Validation-issue banner (date/shop mismatch from OCR) ──────────
            if (_issue != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  // Friendly blue for high-amount review, red for real issues
                  color: _isFriendlyIssue
                      ? const Color(0xFFE3F2FD)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _isFriendlyIssue
                          ? const Color(0xFF64B5F6)
                          : const Color(0xFFEF5350)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                            _isFriendlyIssue
                                ? Icons.verified_user_rounded
                                : Icons.error_outline_rounded,
                            color: _isFriendlyIssue
                                ? const Color(0xFF1565C0)
                                : const Color(0xFFC62828),
                            size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _issueMessage,
                            style: TextStyle(
                              fontSize: 13,
                              color: _isFriendlyIssue
                                  ? const Color(0xFF1565C0)
                                  : const Color(0xFFC62828),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Unreadable-bill case: often just weak internet (AI
                    // unreachable) or a blurry photo — offer a quick rescan.
                    if (_issue == 'ocr_unverified') ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          // The scanner screen is already below this one in
                          // the navigation stack (scanner → scanning →
                          // pushReplacement → confirm), so just pop back to
                          // it. pushReplacement here would create a second
                          // scanner page with the same ValueKey → duplicate
                          // page key crash.
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Check Internet & Rescan'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFC62828),
                            side: const BorderSide(color: Color(0xFFEF5350)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

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
            Row(
              children: [
                const Text(
                  'Shop Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (!_manualMode) ...[
                  const SizedBox(width: 6),
                  const Text('(read-only)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _shopCtrl,
              readOnly: !_manualMode,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _manualMode
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFF374151)),
              decoration: InputDecoration(
                hintText: 'e.g. Big Bazaar, DMart…',
                prefixIcon: Icon(Icons.storefront_rounded,
                    color: _manualMode
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF9CA3AF),
                    size: 22),
                hintStyle: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 14),
                filled: true,
                fillColor: _manualMode
                    ? const Color(0xFFF8FAFF)
                    : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _blue, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _manualMode
                        ? const Color(0xFFE5E7EB)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
              ),
            ),

            const SizedBox(height: 16),

            // ── Amount field ──────────────────────────────────────────────────
            Row(
              children: [
                const Text(
                  'Total Bill Amount (₹)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (!_manualMode) ...[
                  const SizedBox(width: 6),
                  const Text('(read-only)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amtCtrl,
              readOnly: !_manualMode,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _manualMode ? _blue : const Color(0xFF374151)),
              decoration: InputDecoration(
                prefixText: '₹  ',
                prefixStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _manualMode
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFFBDBDBD)),
                hintText: '0',
                hintStyle: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 28),
                filled: true,
                fillColor: _manualMode
                    ? const Color(0xFFF8FAFF)
                    : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _blue, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
              ),
            ),

            const SizedBox(height: 16),

            // ── Reward preview ────────────────────────────────────────────────
            // Shown for BOTH scan types — redeem scans now ALSO earn
            // cashback + points on the bill total (plus the discount,
            // previewed separately below).
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
                      label: 'Cashback (${_fmtPct(_cashbackPct)}%)',
                      value: '₹$_cashbackPreview',
                      valueColor: const Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 6),
                    _RewardRow(
                      icon: Icons.stars_rounded,
                      iconColor: const Color(0xFFD97706),
                      label: 'Reward Points (${_fmtPct(_pointsPct)}%)',
                      value: '${BillRewardEntry.fmtPoints(_estimatedPoints)} pts',
                      valueColor: const Color(0xFFD97706),
                    ),
                    // How to earn a higher rate. Null on the top tier, so
                    // nobody is nagged towards something that doesn't exist.
                    if (BillService.tierProgressLabel != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.trending_up_rounded,
                              size: 15, color: Color(0xFF059669)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              BillService.tierProgressLabel!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

            // ── Redeem Zone discount preview ────────────────────────────────────
            // Shown only when this scan is tied to a Redeem Zone shop and no
            // validation issue is blocking the auto-claim path.
            if (_issue == null &&
                provider.isPendingRedeem &&
                provider.pendingShopId != null &&
                (provider.pendingDiscount ?? 0) > 0) ...[
              const SizedBox(height: 14),
              Builder(builder: (context) {
                final pct = provider.pendingDiscount!;
                final discountValue = _billAmount * pct / 100;
                final wallet = provider.currentPoints;
                final deducted =
                    discountValue < wallet ? discountValue : wallet;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBDEFB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Redeem Zone — $pct% discount',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _blue),
                      ),
                      const SizedBox(height: 10),
                      _RewardRow(
                        icon: Icons.percent_rounded,
                        iconColor: const Color(0xFF6B7280),
                        label: 'Discount Value',
                        value: '₹${discountValue.toStringAsFixed(0)}',
                        valueColor: const Color(0xFF374151),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Divider(height: 1, color: Color(0xFFBBDEFB)),
                      ),
                      _RewardRow(
                        icon: Icons.remove_circle_outline_rounded,
                        iconColor: const Color(0xFFC62828),
                        label: 'Points to be Deducted',
                        value:
                            '${BillRewardEntry.fmtPoints(deducted.toDouble())} pts',
                        valueColor: const Color(0xFFC62828),
                      ),
                    ],
                  ),
                );
              }),
            ],

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

            const SizedBox(height: 20),

            // ── Missing fields warning ────────────────────────────────────────
            Builder(builder: (ctx) {
              final shopMissing = _shopCtrl.text.trim().isEmpty;
              final amtMissing  = _amtCtrl.text.trim().isEmpty ||
                  (double.tryParse(_amtCtrl.text.trim()) ?? 0) <= 0;
              final hasMissing  = shopMissing || amtMissing;
              if (!hasMissing && !_manualMode) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _manualMode
                      ? const Color(0xFFF3E5F5)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _manualMode
                        ? const Color(0xFFAB47BC)
                        : const Color(0xFFFF9800),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                        _manualMode
                            ? Icons.edit_note_rounded
                            : Icons.warning_amber_rounded,
                        color: _manualMode
                            ? const Color(0xFF7B1FA2)
                            : const Color(0xFFF57C00),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _manualMode
                              ? 'Manual entry mode — fill in the correct details and submit for review.'
                              : 'Some fields are missing. Fill them in and submit for team review.',
                          style: TextStyle(
                            fontSize: 13,
                            color: _manualMode
                                ? const Color(0xFF7B1FA2)
                                : const Color(0xFFF57C00),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ]),
                    if (!_manualMode && hasMissing) ...[
                      const SizedBox(height: 8),
                      if (shopMissing)
                        const Text('• Shop name is missing',
                            style: TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                      if (amtMissing)
                        const Text('• Bill amount is missing',
                            style: TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                    ],
                  ],
                ),
              );
            }),

            // ── Manual mode toggle — always visible after OCR ─────────────────
            if (!_manualMode)
              GestureDetector(
                onTap: () => setState(() => _manualMode = true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCE93D8)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: Color(0xFF7B1FA2), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'OCR data looks wrong? Tap to enter manually for review',
                          style: TextStyle(fontSize: 13, color: Color(0xFF7B1FA2), fontWeight: FontWeight.w500),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Color(0xFF7B1FA2)),
                    ],
                  ),
                ),
              ),

            // ── Confirm button (normal OCR flow, not manual mode) ─────────────
            if (!_manualMode)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_claiming ||
                      _shopCtrl.text.trim().isEmpty ||
                      (_amtCtrl.text.trim().isEmpty))
                      ? null
                      : _confirmAndClaim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: _claiming
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Yes, Claim Reward',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

            const SizedBox(height: 12),

            // ── Submit for review button (missing fields OR manual mode) ───────
            if (_manualMode ||
                _shopCtrl.text.trim().isEmpty ||
                (_amtCtrl.text.trim().isEmpty))
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _submittingManual ? null : _submitForReview,
                  icon: _submittingManual
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 20),
                  label: Text(
                    _submittingManual
                        ? 'Submitting...'
                        : _manualMode
                            ? 'Submit for Review'
                            : 'Submit Incomplete Bill for Review',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B1FA2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                ),
              ),

            // Only allow leaving manual mode when there's no OCR validation
            // issue — a flagged bill (date/shop mismatch) must go through
            // review and can't be silently switched back to auto-claim.
            if (_manualMode && _issue == null) ...[
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _manualMode = false),
                  child: const Text('Cancel — go back to OCR data',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── Rescan button ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _rescan,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 28),
                label: const Text('Scan Again', style: TextStyle(fontSize: 15)),
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

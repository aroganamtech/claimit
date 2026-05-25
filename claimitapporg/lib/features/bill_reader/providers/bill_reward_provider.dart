import 'dart:math';
import 'package:flutter/material.dart';
import '../models/bill_reward_model.dart';
import '../services/bill_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BillRewardProvider
// ─────────────────────────────────────────────────────────────────────────────

class BillRewardProvider extends ChangeNotifier {
  // ── Wallet ─────────────────────────────────────────────────────────────────
  double _lifetimeCashback = 5000;
  int    _currentPoints    = 2780;
  double _cashbackWallet   = 500;

  double get lifetimeCashback => _lifetimeCashback;
  int    get currentPoints    => _currentPoints;
  double get cashbackWallet   => _cashbackWallet;

  // ── Pending scan data (set by OCR screen, consumed by confirm screen) ──────
  double?   _pendingTotal;
  String?   _pendingImagePath;
  String?   _pendingOcrText;    // raw OCR text for debugging / display
  String?   _pendingShopName;   // shop name extracted by OCR
  DateTime? _pendingBillDate;   // date printed on the bill (from OCR)
  String?   _pendingBillNumber; // bill/invoice/receipt number from OCR

  double?   get pendingTotal      => _pendingTotal;
  String?   get pendingImagePath  => _pendingImagePath;
  String?   get pendingOcrText    => _pendingOcrText;
  String?   get pendingShopName   => _pendingShopName;
  DateTime? get pendingBillDate   => _pendingBillDate;
  String?   get pendingBillNumber => _pendingBillNumber;

  // ── History ────────────────────────────────────────────────────────────────
  final List<BillRewardEntry> _history = [
    BillRewardEntry(
      id: 'h1',
      shopName: 'Big Bazaar',
      shopColor: const Color(0xFF1565C0),
      totalBill: 4500,
      discount: 45,   // 1% cashback
      cashback: 45,
      rewardPoints: 450, // 10% points
      date: DateTime(2024, 9, 17, 10, 34),
    ),
    BillRewardEntry(
      id: 'h2',
      shopName: 'Amazon',
      shopColor: const Color(0xFFFF9900),
      totalBill: 3200,
      discount: 32,
      cashback: 32,
      rewardPoints: 320,
      date: DateTime(2024, 9, 18, 11, 15),
    ),
    BillRewardEntry(
      id: 'h3',
      shopName: 'Myntra',
      shopColor: const Color(0xFFE91E8C),
      totalBill: 2500,
      discount: 25,
      cashback: 25,
      rewardPoints: 250,
      date: DateTime(2024, 9, 19, 9, 45),
    ),
    BillRewardEntry(
      id: 'h4',
      shopName: 'D Mart',
      shopColor: const Color(0xFF1B5E20),
      totalBill: 5600,
      discount: 56,
      cashback: 56,
      rewardPoints: 560,
      date: DateTime(2024, 9, 20, 14, 22),
    ),
  ];

  List<BillRewardEntry> get history => List.unmodifiable(_history);

  // ─────────────────────────────────────────────────────────────────────────
  // Called by BillScanningProgressScreen after OCR finishes.
  // Stores the result so BillConfirmScreen can display it.
  // ─────────────────────────────────────────────────────────────────────────
  void setScanResult({
    double? totalAmount,
    String? imagePath,
    String? ocrText,
    String? shopName,
    DateTime? billDate,
    String? billNumber,
  }) {
    _pendingTotal      = totalAmount;
    _pendingImagePath  = imagePath;
    _pendingOcrText    = ocrText;
    _pendingShopName   = shopName;
    _pendingBillDate   = billDate;
    _pendingBillNumber = billNumber;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Called by BillConfirmScreen when user corrects the amount / shop name.
  // ─────────────────────────────────────────────────────────────────────────
  void updatePendingTotal(double amount) {
    _pendingTotal = amount;
    notifyListeners();
  }

  void updatePendingShopName(String name) {
    _pendingShopName = name;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Duplicate detection — returns true if this bill was already scanned.
  // Matches on: shop name (case-insensitive) + amount + bill calendar date.
  // ─────────────────────────────────────────────────────────────────────────
  bool isDuplicate({
    required String shopName,
    required double amount,
    required DateTime billDate,
    String? billNumber,
  }) {
    final shop    = shopName.toLowerCase().trim();
    final amt     = amount.toStringAsFixed(0);
    final dateStr = '${billDate.year}-${billDate.month}-${billDate.day}';

    // Build the same key logic as BillRewardEntry.duplicateKey
    final String key;
    if (billNumber != null && billNumber.trim().isNotEmpty) {
      final bn = billNumber.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      key = '$bn|$shop|$dateStr|$amt';
    } else {
      key = '$shop|$dateStr|$amt';
    }
    return _history.any((e) => e.duplicateKey == key);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Commit: POST to backend, add to history, update wallet.
  // If the backend call fails we still add locally so the user isn't stuck.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> claimReward() async {
    final total = _pendingTotal;
    if (total == null || total <= 0) return;

    final points   = BillRewardEntry.calcPoints(total);    // 10% pts
    final cashback = BillRewardEntry.calcCashback(total);  // 1% cashback

    // ── Attempt backend sync ────────────────────────────────────────────
    // Use the OCR-extracted shop name as the default, fall back to 'Shop'
    String shopName = (_pendingShopName?.isNotEmpty == true)
        ? _pendingShopName!
        : 'Shop';
    try {
      final result = await BillService.instance.submitBillScan(
        totalAmount: total,
        imagePath:   _pendingImagePath,
        shopName:    shopName,
        billNumber:  _pendingBillNumber,
        billDate:    _pendingBillDate,
      );
      // Backend shop name overrides OCR only if explicitly provided
      shopName = result['shop_name'] as String? ?? shopName;
      // Backend may return updated points — use them if available
      final serverPoints = result['reward_points'] as int?;
      if (serverPoints != null) {
        _currentPoints = serverPoints;
      } else {
        _currentPoints += points;
      }
      _lifetimeCashback += cashback;
      _cashbackWallet   += cashback;
    } catch (e) {
      debugPrint('Bill sync error: $e — applying locally');
      _currentPoints    += points;
      _lifetimeCashback += cashback;
      _cashbackWallet   += cashback;
    }

    // ── Add to history ──────────────────────────────────────────────────
    final colors = [
      const Color(0xFF1565C0),
      const Color(0xFF7B1FA2),
      const Color(0xFF2E7D32),
      const Color(0xFFE65100),
      const Color(0xFFB71C1C),
    ];
    final scanNow = DateTime.now();
    final entry = BillRewardEntry(
      id: 'scan_${scanNow.millisecondsSinceEpoch}',
      shopName: shopName,
      shopColor: colors[Random().nextInt(colors.length)],
      totalBill: total,
      discount: cashback,
      cashback: cashback,
      rewardPoints: points,
      date: scanNow,
      billDate: _pendingBillDate,
      billNumber: _pendingBillNumber,
    );

    _history.insert(0, entry);
    _pendingTotal      = null;
    _pendingImagePath  = null;
    _pendingShopName   = null;
    _pendingBillDate   = null;
    _pendingBillNumber = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Transfer cashback wallet balance to bank.
  // Returns true on success, false if balance is insufficient.
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> transferToBank({required double amount, required String accountDetails}) async {
    if (amount <= 0 || amount > _cashbackWallet) return false;

    // Simulate network delay / backend call
    await Future.delayed(const Duration(milliseconds: 800));

    _cashbackWallet -= amount;
    notifyListeners();
    return true;
  }
}

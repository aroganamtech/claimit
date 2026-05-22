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
  double? _pendingTotal;
  String? _pendingImagePath;

  double? get pendingTotal     => _pendingTotal;
  String? get pendingImagePath => _pendingImagePath;

  // ── History ────────────────────────────────────────────────────────────────
  final List<BillRewardEntry> _history = [
    BillRewardEntry(
      id: 'h1',
      shopName: 'Big Bazaar',
      shopColor: const Color(0xFF1565C0),
      totalBill: 4500,
      discount: 450,
      rewardPoints: 450,
      date: DateTime(2024, 9, 17, 10, 34),
    ),
    BillRewardEntry(
      id: 'h2',
      shopName: 'Amazon',
      shopColor: const Color(0xFFFF9900),
      totalBill: 3200,
      discount: 320,
      rewardPoints: 300,
      date: DateTime(2024, 9, 18, 11, 15),
    ),
    BillRewardEntry(
      id: 'h3',
      shopName: 'Myntra',
      shopColor: const Color(0xFFE91E8C),
      totalBill: 2500,
      discount: 250,
      rewardPoints: 250,
      date: DateTime(2024, 9, 19, 9, 45),
    ),
    BillRewardEntry(
      id: 'h4',
      shopName: 'D Mart',
      shopColor: const Color(0xFF1B5E20),
      totalBill: 5600,
      discount: 560,
      rewardPoints: 560,
      date: DateTime(2024, 9, 20, 14, 22),
    ),
  ];

  List<BillRewardEntry> get history => List.unmodifiable(_history);

  // ─────────────────────────────────────────────────────────────────────────
  // Called by BillScanningProgressScreen after OCR finishes.
  // Stores the result so BillConfirmScreen can display it.
  // ─────────────────────────────────────────────────────────────────────────
  void setScanResult({double? totalAmount, String? imagePath}) {
    _pendingTotal     = totalAmount;
    _pendingImagePath = imagePath;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Called by BillConfirmScreen when user corrects the amount.
  // ─────────────────────────────────────────────────────────────────────────
  void updatePendingTotal(double amount) {
    _pendingTotal = amount;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Commit: POST to backend, add to history, update wallet.
  // If the backend call fails we still add locally so the user isn't stuck.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> claimReward() async {
    final total = _pendingTotal;
    if (total == null || total <= 0) return;

    final points   = BillRewardEntry.calcPoints(total);
    final discount = BillRewardEntry.calcDiscount(total);

    // ── Attempt backend sync ────────────────────────────────────────────
    String shopName = 'Shop';
    try {
      final result = await BillService.instance.submitBillScan(
        totalAmount: total,
        imagePath: _pendingImagePath,
      );
      shopName = result['shop_name'] as String? ?? 'Shop';
      // Backend may return updated points — use them if available
      final serverPoints = result['reward_points'] as int?;
      if (serverPoints != null) {
        _currentPoints = serverPoints;
      } else {
        _currentPoints += points;
      }
      _lifetimeCashback += discount;
      _cashbackWallet   += discount;
    } catch (e) {
      debugPrint('Bill sync error: $e — applying locally');
      _currentPoints    += points;
      _lifetimeCashback += discount;
      _cashbackWallet   += discount;
    }

    // ── Add to history ──────────────────────────────────────────────────
    final colors = [
      const Color(0xFF1565C0),
      const Color(0xFF7B1FA2),
      const Color(0xFF2E7D32),
      const Color(0xFFE65100),
      const Color(0xFFB71C1C),
    ];
    final entry = BillRewardEntry(
      id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
      shopName: shopName,
      shopColor: colors[Random().nextInt(colors.length)],
      totalBill: total,
      discount: discount,
      rewardPoints: points,
      date: DateTime.now(),
    );

    _history.insert(0, entry);
    _pendingTotal     = null;
    _pendingImagePath = null;
    notifyListeners();
  }
}

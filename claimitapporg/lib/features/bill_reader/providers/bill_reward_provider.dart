import 'dart:math';
import 'package:flutter/material.dart';
import '../models/bill_reward_model.dart';

class BillRewardProvider extends ChangeNotifier {
  // ── Wallet totals ──────────────────────────────────────────────────────────
  double _lifetimeCashback = 5000;
  int _currentPoints = 2780;
  double _cashbackWallet = 500;

  double get lifetimeCashback => _lifetimeCashback;
  int get currentPoints => _currentPoints;
  double get cashbackWallet => _cashbackWallet;

  // ── Last scanned entry (shown on success screen) ───────────────────────────
  BillRewardEntry? _lastScanned;
  BillRewardEntry? get lastScanned => _lastScanned;

  // ── History ────────────────────────────────────────────────────────────────
  final List<BillRewardEntry> _history = [
    BillRewardEntry(
      id: 'h1',
      shopName: 'Big Bazaar',
      shopColor: const Color(0xFF1565C0),
      totalBill: 4500,
      discount: 450,
      rewardPoints: 450,
      date: DateTime(2023, 9, 17, 10, 34),
    ),
    BillRewardEntry(
      id: 'h2',
      shopName: 'Amazon',
      shopColor: const Color(0xFFFF9900),
      totalBill: 3200,
      discount: 320,
      rewardPoints: 300,
      date: DateTime(2023, 9, 18, 11, 15),
    ),
    BillRewardEntry(
      id: 'h3',
      shopName: 'Myntra',
      shopColor: const Color(0xFFE91E8C),
      totalBill: 2500,
      discount: 250,
      rewardPoints: 250,
      date: DateTime(2023, 9, 19, 9, 45),
    ),
    BillRewardEntry(
      id: 'h4',
      shopName: 'D Mart',
      shopColor: const Color(0xFF1B5E20),
      totalBill: 5600,
      discount: 560,
      rewardPoints: 560,
      date: DateTime(2023, 9, 20, 14, 22),
    ),
  ];

  List<BillRewardEntry> get history => List.unmodifiable(_history);

  // ── Sample shops for simulated scan ───────────────────────────────────────
  static const _sampleShops = [
    {'name': 'Maarhaba Restaurant', 'color': 0xFF7B1FA2, 'min': 400.0, 'max': 1200.0},
    {'name': 'Café Coffee Day',     'color': 0xFF4E342E, 'min': 180.0, 'max': 600.0},
    {'name': 'Reliance Fresh',      'color': 0xFF1565C0, 'min': 500.0, 'max': 2500.0},
    {'name': 'Haldiram\'s',         'color': 0xFFE65100, 'min': 250.0, 'max': 900.0},
    {'name': 'Pizza Hut',           'color': 0xFFB71C1C, 'min': 400.0, 'max': 1500.0},
    {'name': 'Wellness Pharmacy',   'color': 0xFF00695C, 'min': 200.0, 'max': 800.0},
  ];

  /// Called when user triggers a bill scan (camera or gallery).
  /// Simulates OCR by picking a random shop & amount.
  BillRewardEntry simulateScan() {
    final rng = Random();
    final shop = _sampleShops[rng.nextInt(_sampleShops.length)];
    final minAmt = shop['min'] as double;
    final maxAmt = shop['max'] as double;
    final total = (minAmt + rng.nextDouble() * (maxAmt - minAmt));
    // Round to nearest 10
    final roundedTotal = (total / 10).round() * 10.0;

    final entry = BillRewardEntry(
      id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
      shopName: shop['name'] as String,
      shopColor: Color(shop['color'] as int),
      totalBill: roundedTotal,
      discount: BillRewardEntry.calcDiscount(roundedTotal),
      rewardPoints: BillRewardEntry.calcPoints(roundedTotal),
      date: DateTime.now(),
    );

    _lastScanned = entry;
    notifyListeners();
    return entry;
  }

  /// Commits the last scanned entry to history + updates wallet.
  void claimReward() {
    if (_lastScanned == null) return;
    final entry = _lastScanned!;

    _history.insert(0, entry);
    _currentPoints += entry.rewardPoints;
    _lifetimeCashback += entry.discount;
    _cashbackWallet += entry.discount;
    _lastScanned = null;
    notifyListeners();
  }
}

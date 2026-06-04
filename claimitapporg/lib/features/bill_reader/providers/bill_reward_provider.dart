import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bill_reward_model.dart';
import '../services/bill_service.dart';
import '../../../core/utils/error_handler.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BillRewardProvider
//
// Persistence strategy (two-layer):
//   1. SharedPreferences cache — restored immediately on every app launch so
//      the user always sees their last-known wallet/history without waiting
//      for a network round-trip.
//   2. Server (Vercel API) — authoritative source; overwrites the cache after
//      every successful API call.
//
// loadAll() is the public entry-point called:
//   • From main.dart via authStateNotifier whenever the user authenticates
//   • From BillRewardWalletScreen.initState (refresh on screen open)
// ─────────────────────────────────────────────────────────────────────────────

class BillRewardProvider extends ChangeNotifier {
  // ── Wallet ─────────────────────────────────────────────────────────────────
  double _lifetimeCashback = 0;
  int    _currentPoints    = 0;
  double _cashbackWallet   = 0;
  bool   _walletLoaded     = false;

  double get lifetimeCashback => _lifetimeCashback;
  int    get currentPoints    => _currentPoints;
  double get cashbackWallet   => _cashbackWallet;
  bool   get walletLoaded     => _walletLoaded;

  // ── Pending scan data ──────────────────────────────────────────────────────
  double?   _pendingTotal;
  String?   _pendingImagePath;
  String?   _pendingOcrText;
  String?   _pendingShopName;
  DateTime? _pendingBillDate;
  String?   _pendingBillNumber;
  String?   _pendingBillTime;   // "HH:MM" from OCR receipt

  double?   get pendingTotal      => _pendingTotal;
  String?   get pendingImagePath  => _pendingImagePath;
  String?   get pendingOcrText    => _pendingOcrText;
  String?   get pendingShopName   => _pendingShopName;
  DateTime? get pendingBillDate   => _pendingBillDate;
  String?   get pendingBillNumber => _pendingBillNumber;
  String?   get pendingBillTime   => _pendingBillTime;

  // ── History ────────────────────────────────────────────────────────────────
  final List<BillRewardEntry> _history = [];
  List<BillRewardEntry> get history => List.unmodifiable(_history);

  // ── New-user bonus popup ───────────────────────────────────────────────────
  bool _showNewUserBonusPopup = false;
  int  _bonusPoints           = 0;
  bool get showNewUserBonusPopup => _showNewUserBonusPopup;
  int  get bonusPoints           => _bonusPoints;
  void dismissBonusPopup() {
    _showNewUserBonusPopup = false;
    notifyListeners();
  }

  // ── SharedPreferences keys ─────────────────────────────────────────────────
  static const _kPoints   = 'bill_reward_points';
  static const _kCbWallet = 'bill_cashback_wallet';
  static const _kLifetime = 'bill_lifetime_cashback';
  static const _kHistory  = 'bill_history_json';

  // ─────────────────────────────────────────────────────────────────────────
  // Constructor — immediately restore cached data so UI is not blank on
  // app restart while the network request is in flight.
  // ─────────────────────────────────────────────────────────────────────────
  BillRewardProvider() {
    _restoreFromCache();
  }

  // ── Restore from SharedPreferences ────────────────────────────────────────
  Future<void> _restoreFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentPoints    = prefs.getInt(_kPoints)       ?? 0;
      _cashbackWallet   = prefs.getDouble(_kCbWallet)  ?? 0;
      _lifetimeCashback = prefs.getDouble(_kLifetime)  ?? 0;

      final raw = prefs.getString(_kHistory);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _history.clear();
        for (var i = 0; i < list.length; i++) {
          final m = list[i] as Map<String, dynamic>;
          _history.add(_entryFromMap(m, _shopColors[i % _shopColors.length]));
        }
      }

      if (_currentPoints > 0 || _history.isNotEmpty) {
        _walletLoaded = true;
        notifyListeners();
      }
    } catch (_) {
      // Cache miss / parse error — start fresh, API will fill in on loadAll()
    }
  }

  // ── Persist wallet + history to SharedPreferences ──────────────────────────
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt   (_kPoints,   _currentPoints);
      await prefs.setDouble(_kCbWallet, _cashbackWallet);
      await prefs.setDouble(_kLifetime, _lifetimeCashback);

      // Keep last 100 entries to avoid unbounded storage growth
      final slice   = _history.take(100).toList();
      final encoded = jsonEncode(slice.map(_entryToMap).toList());
      await prefs.setString(_kHistory, encoded);
    } catch (_) {}
  }

  // ── Clear cache (e.g. on logout) ──────────────────────────────────────────
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPoints);
      await prefs.remove(_kCbWallet);
      await prefs.remove(_kLifetime);
      await prefs.remove(_kHistory);
    } catch (_) {}
    _currentPoints    = 0;
    _cashbackWallet   = 0;
    _lifetimeCashback = 0;
    _walletLoaded     = false;
    _history.clear();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Load wallet + history from server
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> loadWallet() async {
    try {
      final data = await BillService.instance.fetchWallet();
      _currentPoints    = (data['reward_points']     as num?)?.toInt()    ?? _currentPoints;
      _cashbackWallet   = (data['cashback_wallet']   as num?)?.toDouble() ?? _cashbackWallet;
      _lifetimeCashback = (data['lifetime_cashback'] as num?)?.toDouble() ?? _lifetimeCashback;
      _walletLoaded     = true;
      notifyListeners();
      await _saveToCache();
    } catch (e) {
      AppError.friendly(e, '', context: 'BillWallet');
      // Cache already shown from _restoreFromCache — nothing more to do
    }
  }

  Future<void> loadHistory() async {
    try {
      final items = await BillService.instance.fetchHistory();
      _history.clear();
      for (var i = 0; i < items.length; i++) {
        _history.add(_entryFromMap(items[i], _shopColors[i % _shopColors.length]));
      }
      notifyListeners();
      await _saveToCache();
    } catch (e) {
      AppError.friendly(e, '', context: 'BillHistory');
      // Cache already shown — nothing more to do
    }
  }

  /// Load both wallet + history in parallel.
  /// Called from main.dart on auth, and from wallet screen on open.
  Future<void> loadAll() async {
    await Future.wait([loadWallet(), loadHistory()]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Called by BillScanningProgressScreen after OCR finishes
  // ─────────────────────────────────────────────────────────────────────────
  void setScanResult({
    double?   totalAmount,
    String?   imagePath,
    String?   ocrText,
    String?   shopName,
    DateTime? billDate,
    String?   billNumber,
    String?   billTime,
  }) {
    _pendingTotal      = totalAmount;
    _pendingImagePath  = imagePath;
    _pendingOcrText    = ocrText;
    _pendingShopName   = shopName;
    _pendingBillDate   = billDate;
    _pendingBillNumber = billNumber;
    _pendingBillTime   = billTime;
    notifyListeners();
  }

  void updatePendingTotal(double amount) {
    _pendingTotal = amount;
    notifyListeners();
  }

  void updatePendingShopName(String name) {
    _pendingShopName = name;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local duplicate check (fast path — server also enforces via 409)
  // ─────────────────────────────────────────────────────────────────────────
  bool isDuplicate({
    required String   shopName,
    required double   amount,
    required DateTime billDate,
    String?           billNumber,   // kept for API compat — no longer used in key
    String?           billTime,     // "HH:MM" from receipt; makes same-shop same-day valid
  }) {
    final shop    = shopName.toLowerCase().trim();
    final amt     = amount.toStringAsFixed(0);
    final dateStr = '${billDate.year}-${billDate.month}-${billDate.day}';

    final t = billTime?.trim();
    final String key = (t != null && t.isNotEmpty)
        ? '$shop|$dateStr|$t|$amt'
        : '$shop|$dateStr|$amt';

    return _history.any((e) => e.duplicateKey == key);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Commit: POST to backend → update wallet from server response → cache
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> claimReward() async {
    final total = _pendingTotal;
    if (total == null || total <= 0) return;

    String shopName = (_pendingShopName?.isNotEmpty == true)
        ? _pendingShopName!
        : 'Shop';

    final localPts = BillRewardEntry.calcPoints(total);
    final localCb  = BillRewardEntry.calcCashback(total);

    bool serverSuccess = false;

    try {
      final result = await BillService.instance.submitBillScan(
        totalAmount: total,
        imagePath:   _pendingImagePath,
        shopName:    shopName,
        billNumber:  _pendingBillNumber,
        billDate:    _pendingBillDate,
        billTime:    _pendingBillTime,
      );

      serverSuccess = true;

      // Server is authoritative — overwrite wallet from response
      final serverName = result['shop_name'] as String?;
      if (serverName != null && serverName.isNotEmpty) shopName = serverName;

      _currentPoints    = (result['reward_points']     as num?)?.toInt()    ?? (_currentPoints + localPts);
      _cashbackWallet   = (result['cashback_wallet']   as num?)?.toDouble() ?? (_cashbackWallet + localCb);
      _lifetimeCashback = (result['lifetime_cashback'] as num?)?.toDouble() ?? (_lifetimeCashback + localCb);

      // New-user 1000-point welcome bonus
      if (result['is_new_user_bonus'] == true) {
        _bonusPoints           = (result['bonus_points'] as num?)?.toInt() ?? 1000;
        _showNewUserBonusPopup = true;
      }
    } catch (e) {
      if (e is BillAlreadyScannedException) rethrow;
      AppError.friendly(e, '', context: 'BillSync');
      // Fallback: apply locally so the user still sees the reward this session
      _currentPoints    += localPts;
      _cashbackWallet   += localCb;
      _lifetimeCashback += localCb;
    }

    // Add to local history (even on server fallback — avoids blank history)
    final scanNow = DateTime.now();
    final entry = BillRewardEntry(
      id:           serverSuccess
                      ? 'scan_${scanNow.millisecondsSinceEpoch}'
                      : 'local_${scanNow.millisecondsSinceEpoch}',
      shopName:     shopName,
      shopColor:    _shopColors[_history.length % _shopColors.length],
      totalBill:    total,
      discount:     localCb,
      cashback:     localCb,
      rewardPoints: localPts,
      date:         scanNow,
      billDate:     _pendingBillDate,
      billNumber:   _pendingBillNumber,
      billTime:     _pendingBillTime,
    );
    _history.insert(0, entry);

    _pendingTotal      = null;
    _pendingImagePath  = null;
    _pendingShopName   = null;
    _pendingBillDate   = null;
    _pendingBillNumber = null;
    _pendingBillTime   = null;

    notifyListeners();

    // ── Persist immediately — survives app kill/restart ────────────────────
    await _saveToCache();
  }

  // ── Transfer cashback to bank ──────────────────────────────────────────────
  Future<bool> transferToBank({
    required double amount,
    required String accountDetails,
  }) async {
    if (amount <= 0 || amount > _cashbackWallet) return false;
    await Future.delayed(const Duration(milliseconds: 800));
    _cashbackWallet -= amount;
    notifyListeners();
    await _saveToCache();
    return true;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  static const _shopColors = [
    Color(0xFF1565C0),
    Color(0xFF7B1FA2),
    Color(0xFF2E7D32),
    Color(0xFFE65100),
    Color(0xFFB71C1C),
    Color(0xFF00838F),
    Color(0xFF558B2F),
    Color(0xFF6A1B9A),
  ];

  static BillRewardEntry _entryFromMap(Map<String, dynamic> m, Color color) {
    final total = (m['total_amount']    as num?)?.toDouble() ?? 0;
    final cb    = (m['earned_cashback'] as num?)?.toDouble()
               ?? (m['cashback']        as num?)?.toDouble()
               ?? total * 0.01;
    final pts   = (m['earned_points']   as num?)?.toInt()
               ?? (m['reward_points']   as num?)?.toInt()
               ?? (total * 0.1).round();

    DateTime? billDate;
    if (m['bill_date'] != null) {
      try { billDate = DateTime.parse(m['bill_date'] as String); } catch (_) {}
    }
    DateTime scannedAt = DateTime.now();
    if (m['scanned_at'] != null) {
      try { scannedAt = DateTime.parse(m['scanned_at'] as String); } catch (_) {}
    } else if (m['date'] != null) {
      try { scannedAt = DateTime.parse(m['date'] as String); } catch (_) {}
    }

    return BillRewardEntry(
      id:           m['id'] as String? ?? m['_id'] as String? ?? '',
      shopName:     m['shop_name'] as String? ?? 'Shop',
      shopColor:    color,
      totalBill:    total,
      discount:     cb,
      cashback:     cb,
      rewardPoints: pts,
      date:         scannedAt,
      billDate:     billDate,
      billNumber:   m['bill_number'] as String?,
      billTime:     m['bill_time']   as String?,
    );
  }

  /// Serialise an entry to a plain Map for JSON storage in SharedPreferences
  static Map<String, dynamic> _entryToMap(BillRewardEntry e) => {
    'id':              e.id,
    'shop_name':       e.shopName,
    'total_amount':    e.totalBill,
    'earned_cashback': e.cashback,
    'earned_points':   e.rewardPoints,
    'bill_number':     e.billNumber,
    'bill_time':       e.billTime,
    'bill_date':       e.billDate?.toIso8601String(),
    'scanned_at':      e.date.toIso8601String(),
  };
}

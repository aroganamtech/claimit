import 'package:flutter/material.dart';

class BillRewardEntry {
  final String id;
  final String shopName;
  final Color shopColor;
  final double totalBill;
  // Redeem Bill: ₹ value of the discount applied (always 0 for Reward Bill).
  final double discount;
  // Reward Bill: 1% cashback earned (always 0 for Redeem Bill).
  final double cashback;
  // Reward Bill: 1:10 points earned, e.g. Rs.1564 -> 156.4 pts (always 0 for
  // Redeem Bill — Redeem never earns points, it only spends them).
  final double rewardPoints;
  // Redeem Bill: points spent against the discount (always 0 for Reward Bill).
  final double pointsDeducted;
  final DateTime date;      // scan date/time (when the user scanned)
  final DateTime? billDate; // date printed on the bill (from OCR)
  final String? billNumber; // bill/invoice/receipt number from OCR
  final String? billTime;   // time printed on the bill e.g. "14:30" (from OCR)
  /// 'redeem' (spent points on a discount, earns nothing) or
  /// 'reward' (earned cashback + points, no discount). Defaults to 'reward'
  /// for older entries created before this field existed.
  final String scanType;

  const BillRewardEntry({
    required this.id,
    required this.shopName,
    required this.shopColor,
    required this.totalBill,
    required this.discount,
    required this.rewardPoints,
    required this.date,
    double? cashback,
    this.pointsDeducted = 0,
    this.billDate,
    this.billNumber,
    this.billTime,
    String? scanType,
  }) : cashback = cashback ?? totalBill * 0.01,
       scanType = scanType ?? 'reward';

  bool get isRedeem => scanType == 'redeem';
  bool get isReward => scanType != 'redeem';

  /// 1:10 rule — bill ÷ 10, decimal preserved (e.g. Rs.1564 -> 156.4 pts)
  static double calcPoints(double totalBill) => totalBill / 10;

  /// 1% of bill as cashback (e.g. Rs.5000 -> Rs.50)
  static double calcCashback(double totalBill) => totalBill * 0.01;

  /// Kept for backward-compat
  static double calcDiscount(double totalBill) => calcCashback(totalBill);

  /// Display helper — drops a trailing ".0" (156 instead of 156.0) but
  /// keeps real decimals (156.4) so fractional points are never hidden.
  static String fmtPoints(num pts) {
    final d = pts.toDouble();
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toStringAsFixed(1);
  }

  /// Unique fingerprint used for duplicate detection.
  ///
  /// Key: shop + date + time + amount
  ///   • When time is available: "shop|YYYY-M-D|HH:MM|amount"
  ///   • Without time:           "shop|YYYY-M-D|amount"  (backward-compat)
  ///
  /// Two purchases at the same shop on the same day for the same amount but
  /// at DIFFERENT times are treated as distinct, valid transactions.
  String get duplicateKey {
    final d = billDate ?? date;
    final dateStr = '${d.year}-${d.month}-${d.day}';
    // Lowercase + alphanumerics only — "Fresh Basket" and "FreshBasket"
    // must produce the SAME fingerprint (OCR spacing/case varies per scan).
    final shop = shopName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final amt = totalBill.toStringAsFixed(0);

    final t = billTime?.trim();
    if (t != null && t.isNotEmpty) {
      return '$shop|$dateStr|$t|$amt';
    }
    // No time on receipt — fall back to shop + date + amount
    return '$shop|$dateStr|$amt';
  }
}

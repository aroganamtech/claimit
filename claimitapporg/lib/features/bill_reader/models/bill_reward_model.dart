import 'package:flutter/material.dart';

class BillRewardEntry {
  final String id;
  final String shopName;
  final Color shopColor;
  final double totalBill;
  final double discount;
  final double cashback;    // 1% of bill e.g. Rs.5000 -> Rs.50
  final int rewardPoints;   // 10% of bill e.g. Rs.5000 -> 500 pts
  final DateTime date;      // scan date/time (when the user scanned)
  final DateTime? billDate; // date printed on the bill (from OCR)
  final String? billNumber; // bill/invoice/receipt number from OCR
  final String? billTime;   // time printed on the bill e.g. "14:30" (from OCR)

  const BillRewardEntry({
    required this.id,
    required this.shopName,
    required this.shopColor,
    required this.totalBill,
    required this.discount,
    required this.rewardPoints,
    required this.date,
    double? cashback,
    this.billDate,
    this.billNumber,
    this.billTime,
  }) : cashback = cashback ?? totalBill * 0.01;

  /// 10% of bill as redeem points (e.g. Rs.5000 -> 500 pts)
  static int calcPoints(double totalBill) => (totalBill * 0.1).round();

  /// 1% of bill as cashback (e.g. Rs.5000 -> Rs.50)
  static double calcCashback(double totalBill) => totalBill * 0.01;

  /// Kept for backward-compat
  static double calcDiscount(double totalBill) => calcCashback(totalBill);

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
    final shop = shopName.toLowerCase().trim();
    final amt = totalBill.toStringAsFixed(0);

    final t = billTime?.trim();
    if (t != null && t.isNotEmpty) {
      return '$shop|$dateStr|$t|$amt';
    }
    // No time on receipt — fall back to shop + date + amount
    return '$shop|$dateStr|$amt';
  }
}

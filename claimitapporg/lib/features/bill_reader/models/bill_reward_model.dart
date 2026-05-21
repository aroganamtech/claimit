import 'package:flutter/material.dart';

class BillRewardEntry {
  final String id;
  final String shopName;
  final Color shopColor;
  final double totalBill;
  final double discount;
  final int rewardPoints;
  final DateTime date;

  const BillRewardEntry({
    required this.id,
    required this.shopName,
    required this.shopColor,
    required this.totalBill,
    required this.discount,
    required this.rewardPoints,
    required this.date,
  });

  /// 10% of bill as reward points
  static int calcPoints(double totalBill) => (totalBill * 0.1).round();

  /// 10% discount
  static double calcDiscount(double totalBill) => totalBill * 0.1;
}

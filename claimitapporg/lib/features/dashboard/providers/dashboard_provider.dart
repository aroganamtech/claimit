import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';

class DashboardStats {
  final int totalClaims;
  final int pendingClaims;
  final int approvedClaims;
  final int rejectedClaims;
  final double totalClaimAmount;
  final double approvedAmount;

  DashboardStats({
    required this.totalClaims,
    required this.pendingClaims,
    required this.approvedClaims,
    required this.rejectedClaims,
    required this.totalClaimAmount,
    required this.approvedAmount,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalClaims: json['total_claims'] ?? 0,
      pendingClaims: json['pending_claims'] ?? 0,
      approvedClaims: json['approved_claims'] ?? 0,
      rejectedClaims: json['rejected_claims'] ?? 0,
      totalClaimAmount: (json['total_claim_amount'] ?? 0).toDouble(),
      approvedAmount: (json['approved_amount'] ?? 0).toDouble(),
    );
  }
}

class DashboardProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  DashboardStats? _stats;
  bool _isLoading = false;
  String? _error;

  DashboardStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(AppConstants.dashboard);
      if (response.statusCode == 200) {
        _stats = DashboardStats.fromJson(response.data);
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }
}

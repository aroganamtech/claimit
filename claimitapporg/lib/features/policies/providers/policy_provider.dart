import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../models/policy_model.dart';

class PolicyProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<PolicyModel> _policies = [];
  PolicyModel? _selectedPolicy;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;

  List<PolicyModel> get policies => _policies;
  PolicyModel? get selectedPolicy => _selectedPolicy;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  Future<void> fetchPolicies() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(AppConstants.policies);
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          _policies = data
              .whereType<Map<String, dynamic>>()
              .map(PolicyModel.fromJson)
              .toList();
        } else {
          _policies = [];
        }
      } else {
        _error = 'Failed to load policies (${response.statusCode})';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchPolicyDetail(String policyId) async {
    _isLoading = true;
    _error = null;
    _selectedPolicy = null;
    notifyListeners();

    try {
      // Try to find in cache first
      try {
        _selectedPolicy = _policies.firstWhere((p) => p.id == policyId);
      } catch (_) {
        _selectedPolicy = null;
      }

      final response = await _apiClient.get('/policies/$policyId');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        _selectedPolicy =
            PolicyModel.fromJson(response.data as Map<String, dynamic>);
      } else if (response.statusCode == 404 && _selectedPolicy == null) {
        _error = 'Policy not found';
      }
    } catch (e) {
      if (_selectedPolicy == null) _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createPolicy({
    required String policyNumber,
    required String policyType,
    required String insurerName,
    required double premiumAmount,
    required double sumInsured,
    required DateTime startDate,
    required DateTime endDate,
    List<String> coverages = const [],
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        AppConstants.policies,
        data: {
          'policy_number': policyNumber,
          'policy_type': policyType,
          'insurer_name': insurerName,
          'premium_amount': premiumAmount,
          'sum_insured': sumInsured,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'coverages': coverages,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (response.data is Map<String, dynamic>) {
          _policies.insert(
              0, PolicyModel.fromJson(response.data as Map<String, dynamic>));
        }
        _isSubmitting = false;
        notifyListeners();
        return true;
      }
      _error = 'Failed to create policy';
    } catch (e) {
      _error = e.toString();
    }

    _isSubmitting = false;
    notifyListeners();
    return false;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

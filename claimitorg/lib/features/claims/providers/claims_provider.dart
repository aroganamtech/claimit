import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../models/claim_model.dart';

class ClaimsProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<ClaimModel> _claims = [];
  ClaimModel? _selectedClaim;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;
  String _filterStatus = 'all';

  List<ClaimModel> get claims => _filterStatus == 'all'
      ? _claims
      : _claims.where((c) => c.status == _filterStatus).toList();
  ClaimModel? get selectedClaim => _selectedClaim;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  String get filterStatus => _filterStatus;

  void setFilter(String status) {
    _filterStatus = status;
    notifyListeners();
  }

  Future<void> fetchClaims() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(AppConstants.claims);
      if (response.statusCode == 200) {
        final data = response.data as List<dynamic>;
        _claims = data.map((e) => ClaimModel.fromJson(e)).toList();
        _claims.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchClaimDetail(String claimId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/claims/$claimId');
      if (response.statusCode == 200) {
        _selectedClaim = ClaimModel.fromJson(response.data);
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<ClaimModel?> createClaim({
    required String claimType,
    required String policyNumber,
    required String description,
    required double claimAmount,
    required DateTime incidentDate,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        AppConstants.createClaim,
        data: {
          'claim_type': claimType,
          'policy_number': policyNumber,
          'description': description,
          'claim_amount': claimAmount,
          'incident_date': incidentDate.toIso8601String(),
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final newClaim = ClaimModel.fromJson(response.data);
        _claims.insert(0, newClaim);
        _isSubmitting = false;
        notifyListeners();
        return newClaim;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isSubmitting = false;
    notifyListeners();
    return null;
  }

  Future<bool> uploadDocument(String claimId, String filePath, String fileName) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        'claim_id': claimId,
      });

      final response = await _apiClient.uploadFile(
        '/claims/$claimId/documents',
        formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchClaimDetail(claimId);
        _isSubmitting = false;
        notifyListeners();
        return true;
      }
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

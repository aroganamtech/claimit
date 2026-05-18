import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/models/user_model.dart';

class ProfileProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  bool _isLoading = false;
  bool _isUpdating = false;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get error => _error;

  Future<bool> updateProfile({
    required String fullName,
    String? email,
    String? dateOfBirth,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? aadharNumber,
    String? panNumber,
  }) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.put(
        AppConstants.updateProfile,
        data: {
          'full_name': fullName,
          if (email != null) 'email': email,
          if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
          if (address != null) 'address': address,
          if (city != null) 'city': city,
          if (state != null) 'state': state,
          if (pincode != null) 'pincode': pincode,
          if (aadharNumber != null) 'aadhar_number': aadharNumber,
          if (panNumber != null) 'pan_number': panNumber,
        },
      );

      _isUpdating = false;
      notifyListeners();
      return response.statusCode == 200;
    } catch (e) {
      _error = e.toString();
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadAvatar(String filePath) async {
    _isUpdating = true;
    notifyListeners();

    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      });

      final response = await _apiClient.uploadFile(
        AppConstants.uploadAvatar,
        formData,
      );

      _isUpdating = false;
      notifyListeners();
      return response.statusCode == 200;
    } catch (e) {
      _error = e.toString();
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }
}

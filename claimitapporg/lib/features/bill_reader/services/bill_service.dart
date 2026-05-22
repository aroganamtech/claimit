import 'dart:convert';
import 'dart:io';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BillService — POST /bill/scan to FastAPI backend
// ─────────────────────────────────────────────────────────────────────────────

class BillService {
  BillService._();
  static final instance = BillService._();

  final _client = ApiClient();

  Future<Map<String, dynamic>> submitBillScan({
    required double totalAmount,
    String? imagePath,
  }) async {
    final rewardPoints = (totalAmount * 0.1).round();

    // Optionally encode the image
    String? imageBase64;
    if (imagePath != null) {
      try {
        final bytes = await File(imagePath).readAsBytes();
        imageBase64 = base64Encode(bytes);
      } catch (_) {}
    }

    final body = <String, dynamic>{
      'total_amount': totalAmount,
      'reward_points': rewardPoints,
      if (imageBase64 != null) 'image_base64': imageBase64,
    };

    final response = await _client.post(
      AppConstants.billScan,
      data: body,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.data as Map<String, dynamic>;
    }

    throw Exception('Bill scan API error: ${response.statusCode}');
  }
}

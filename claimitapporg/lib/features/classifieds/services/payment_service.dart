import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';

/// Cashfree payment-link flow used for the Local Finds (Rs.730) and Local
/// Classifieds (Rs.250) listing fees.
///
/// Flow:
///  1. [createLink] asks the backend to create a Cashfree payment link.
///  2. The link opens in the browser (Cashfree's own hosted checkout page —
///     no card/UPI details ever pass through this app).
///  3. Once the user returns to the app, [checkStatus] polls the backend
///     until Cashfree reports the link as PAID (or the user gives up).
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  final _api = ApiClient();

  /// Creates a payment link for [amount] rupees. Returns the link id +
  /// hosted checkout URL, or null on failure.
  Future<({String linkId, String url})?> createLink({
    required double amount,
    required String purpose,
  }) async {
    try {
      final resp = await _api.post(
        AppConstants.createPaymentLink,
        data: {'amount': amount, 'purpose': purpose},
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final linkId = resp.data['link_id'] as String? ?? '';
        final url = resp.data['payment_link_url'] as String? ?? '';
        if (linkId.isNotEmpty && url.isNotEmpty) return (linkId: linkId, url: url);
      }
    } catch (e) {
      debugPrint('PaymentService.createLink error: $e');
    }
    return null;
  }

  /// Opens the Cashfree hosted checkout page in the external browser.
  Future<bool> openCheckout(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Returns the Cashfree link status: ACTIVE, PAID, EXPIRED, CANCELLED, ...
  Future<String> checkStatus(String linkId) async {
    try {
      final resp = await _api.get('${AppConstants.paymentLinkStatus}/$linkId');
      if (resp.statusCode == 200 && resp.data is Map) {
        return resp.data['status'] as String? ?? 'UNKNOWN';
      }
    } catch (e) {
      debugPrint('PaymentService.checkStatus error: $e');
    }
    return 'UNKNOWN';
  }
}

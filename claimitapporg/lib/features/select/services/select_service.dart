import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../models/select_professional.dart';
import '../models/select_booking.dart';
import '../models/select_chat.dart';
import '../models/select_coverage.dart';

/// Listing-plan price returned by GET /select/plans.
typedef SelectPlanPrices = ({int premium, int standard});

/// All Claimit Select network calls. Follows the same conventions as
/// LearnService / ClassifiedService: never throws, returns empty/null on
/// failure and logs with debugPrint so a network blip can't crash a screen.
class SelectService {
  SelectService._();
  static final SelectService instance = SelectService._();

  final _api = ApiClient();

  /// GET /select/professionals — the directory list.
  ///
  /// [sort] is one of "nearby", "top_rated", "offers". Latitude/longitude are
  /// optional; when supplied with sort="nearby" the backend returns a real
  /// distance for each professional.
  Future<List<SelectProfessional>> fetchProfessionals({
    String? category,
    String sort = 'nearby',
    String? search,
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    try {
      final params = <String, dynamic>{'sort': sort};
      if (category != null && category.isNotEmpty) params['category'] = category;
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
      if (lat != null && lng != null) {
        params['lat'] = lat;
        params['lng'] = lng;
        // Limit to the selected radius rather than the backend's wide
        // default, so this page shows the same area as the search screen.
        if (radiusKm != null) params['radius_km'] = radiusKm;
      }
      final resp = await _api.get(AppConstants.selectProfessionals, queryParams: params);
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['professionals'] as List? ?? [];
        return list
            .map((j) => SelectProfessional.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('SelectService.fetchProfessionals error: $e');
    }
    return [];
  }

  /// GET /select/coverage — how many professionals are in a city, category by
  /// category, plus the nearby cities and their counts.
  ///
  /// [city] is matched by prefix, so this doubles as a type-ahead. Passing
  /// [lat]/[lng] lets the backend skip resolving the city to a point, which is
  /// what the app already has when a location is selected.
  ///
  /// Returns [SelectCoverage.empty] rather than throwing, so the screen can
  /// render an honest "nothing here" instead of crashing on a network blip.
  Future<SelectCoverage> fetchCoverage({
    required String city,
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    try {
      final params = <String, dynamic>{'city': city.trim()};
      if (lat != null && lng != null) {
        params['lat'] = lat;
        params['lng'] = lng;
      }
      if (radiusKm != null) params['radius_km'] = radiusKm;

      final resp = await _api.get(AppConstants.selectCoverage, queryParams: params);
      if (resp.statusCode == 200 && resp.data is Map) {
        return SelectCoverage.fromJson(
          Map<String, dynamic>.from(resp.data as Map),
        );
      }
    } catch (e) {
      debugPrint('SelectService.fetchCoverage error: $e');
    }
    return SelectCoverage.empty;
  }

  /// GET /select/professionals/{id}
  Future<SelectProfessional?> fetchProfessional(String id) async {
    try {
      final resp = await _api.get('${AppConstants.selectProfessionals}/$id');
      if (resp.statusCode == 200 && resp.data is Map) {
        final j = resp.data['professional'];
        if (j is Map<String, dynamic>) return SelectProfessional.fromJson(j);
      }
    } catch (e) {
      debugPrint('SelectService.fetchProfessional error: $e');
    }
    return null;
  }

  /// GET /select/my-profile — the signed-in user's own listing, if any.
  Future<SelectProfessional?> fetchMyProfile() async {
    try {
      final resp = await _api.get(AppConstants.selectMyProfile);
      if (resp.statusCode == 200 && resp.data is Map) {
        final j = resp.data['professional'];
        if (j is Map<String, dynamic>) return SelectProfessional.fromJson(j);
      }
    } catch (e) {
      debugPrint('SelectService.fetchMyProfile error: $e');
    }
    return null;
  }

  /// GET /select/plans — live Premium/Standard listing prices (admin-set).
  /// Returns null on failure so the caller keeps its own fallback prices.
  Future<SelectPlanPrices?> fetchPlanPrices() async {
    try {
      final resp = await _api.get(AppConstants.selectPlans);
      if (resp.statusCode == 200 && resp.data is Map) {
        final plans = resp.data['plans'];
        if (plans is Map) {
          final premium = (plans['premium']?['price'] as num?)?.toInt();
          final standard = (plans['standard']?['price'] as num?)?.toInt();
          if (premium != null && standard != null) {
            return (premium: premium, standard: standard);
          }
        }
      }
    } catch (e) {
      debugPrint('SelectService.fetchPlanPrices error: $e');
    }
    return null;
  }

  /// POST /select/professionals — register (or update) the caller's listing.
  /// Returns the saved professional, or null on failure.
  Future<SelectProfessional?> registerProfessional(Map<String, dynamic> body) async {
    try {
      final resp = await _api.post(AppConstants.selectProfessionals, data: body);
      if ((resp.statusCode == 200 || resp.statusCode == 201) && resp.data is Map) {
        final j = resp.data['professional'];
        if (j is Map<String, dynamic>) return SelectProfessional.fromJson(j);
      }
      debugPrint('SelectService.registerProfessional failed: ${resp.statusCode} ${resp.data}');
    } catch (e) {
      debugPrint('SelectService.registerProfessional error: $e');
    }
    return null;
  }

  /// POST /select/bookings — book a consultation (a free request for now).
  Future<SelectBooking?> createBooking({
    required String professionalId,
    required String service,
    required String date,
    required String timeSlot,
    required String mode,
    String message = '',
  }) async {
    try {
      final resp = await _api.post(AppConstants.selectBookings, data: {
        'professional_id': professionalId,
        'service': service,
        'date': date,
        'time_slot': timeSlot,
        'mode': mode,
        'message': message,
      });
      if ((resp.statusCode == 200 || resp.statusCode == 201) && resp.data is Map) {
        final j = resp.data['booking'];
        if (j is Map<String, dynamic>) return SelectBooking.fromJson(j);
      }
      debugPrint('SelectService.createBooking failed: ${resp.statusCode} ${resp.data}');
    } catch (e) {
      debugPrint('SelectService.createBooking error: $e');
    }
    return null;
  }

  /// GET /select/bookings — the caller's consultations, newest first.
  Future<List<SelectBooking>> fetchMyBookings() async {
    try {
      final resp = await _api.get(AppConstants.selectBookings);
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['bookings'] as List? ?? [];
        return list
            .map((j) => SelectBooking.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('SelectService.fetchMyBookings error: $e');
    }
    return [];
  }

  /// GET /select/bookings/received — bookings made with the caller's listing.
  /// Returns empty when the caller isn't a listed professional.
  Future<List<SelectBooking>> fetchReceivedBookings() async {
    try {
      final resp = await _api.get(AppConstants.selectBookingsIn);
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['bookings'] as List? ?? [];
        return list
            .map((j) => SelectBooking.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('SelectService.fetchReceivedBookings error: $e');
    }
    return [];
  }

  /// PATCH /select/bookings/{id}/status — professional confirms or declines.
  Future<bool> updateBookingStatus(String bookingId, String status) async {
    try {
      final resp = await _api.patch(
        '${AppConstants.selectBookings}/$bookingId/status',
        data: {'status': status},
      );
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('SelectService.updateBookingStatus error: $e');
    }
    return false;
  }

  // ── Chat ────────────────────────────────────────────────────────────────

  /// GET /select/conversations — every thread the caller is part of.
  Future<List<SelectConversation>> fetchConversations() async {
    try {
      final resp = await _api.get(AppConstants.selectConversations);
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['conversations'] as List? ?? [];
        return list
            .map((j) => SelectConversation.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('SelectService.fetchConversations error: $e');
    }
    return [];
  }

  /// POST /select/conversations — start a chat with a professional, or return
  /// the existing thread. Safe to call repeatedly (the backend is idempotent).
  Future<SelectConversation?> startConversation(String professionalId) async {
    try {
      final resp = await _api.post(
        AppConstants.selectConversations,
        data: {'professional_id': professionalId},
      );
      if ((resp.statusCode == 200 || resp.statusCode == 201) && resp.data is Map) {
        final j = resp.data['conversation'];
        if (j is Map<String, dynamic>) return SelectConversation.fromJson(j);
      }
      debugPrint('SelectService.startConversation failed: ${resp.statusCode} ${resp.data}');
    } catch (e) {
      debugPrint('SelectService.startConversation error: $e');
    }
    return null;
  }

  /// GET /select/conversations/{id}/messages — oldest first. Also clears the
  /// caller's unread badge for that thread, server-side.
  Future<List<SelectMessage>> fetchMessages(String conversationId) async {
    try {
      final resp = await _api
          .get('${AppConstants.selectConversations}/$conversationId/messages');
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['messages'] as List? ?? [];
        return list
            .map((j) => SelectMessage.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('SelectService.fetchMessages error: $e');
    }
    return [];
  }

  /// POST /select/conversations/{id}/messages
  Future<SelectMessage?> sendMessage(String conversationId, String text) async {
    try {
      final resp = await _api.post(
        '${AppConstants.selectConversations}/$conversationId/messages',
        data: {'text': text},
      );
      if ((resp.statusCode == 200 || resp.statusCode == 201) && resp.data is Map) {
        final j = resp.data['message'];
        if (j is Map<String, dynamic>) return SelectMessage.fromJson(j);
      }
    } catch (e) {
      debugPrint('SelectService.sendMessage error: $e');
    }
    return null;
  }
}

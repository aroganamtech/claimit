import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../models/privilege_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// All Claimit Privilege network calls.
//
// Follows the same convention as SelectService / BillService: never throws,
// returns an empty list or null on failure and logs with debugPrint, so a
// network blip can't take a screen down.
//
// The one exception is issuing and approving a pass. Those DO surface an
// error message, because "nothing happened" at a billing counter with a queue
// behind you is worse than being told why.
// ─────────────────────────────────────────────────────────────────────────────

/// A partner page plus whether more exist and whether these are the nearest
/// rather than the in-radius ones.
typedef PartnerPage = ({
  List<PrivilegePartner> partners,
  bool hasMore,
  bool showingNearest,
});

class PrivilegeService {
  PrivilegeService._();
  static final PrivilegeService instance = PrivilegeService._();

  final _api = ApiClient();

  /// GET /privilege/partners
  ///
  /// [sort] is one of "distance", "discount", "location" — the three filter
  /// chips on the category screen.
  Future<PartnerPage> fetchPartners({
    String? category,
    String? search,
    String sort = 'distance',
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final params = <String, dynamic>{
        'sort': sort,
        'skip': skip,
        'limit': limit,
      };
      if (category != null && category.isNotEmpty) params['category'] = category;
      if (search != null && search.trim().isNotEmpty) {
        params['search'] = search.trim();
      }
      // The location the user picked drives this screen like every other one.
      params.addAll(LocationService.geoParams);

      final resp = await _api.get(AppConstants.privilegePartners,
          queryParams: params);
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = (resp.data['partners'] as List?) ?? [];
        return (
          partners: list
              .whereType<Map<String, dynamic>>()
              .map(PrivilegePartner.fromJson)
              .toList(),
          hasMore: resp.data['has_more'] == true,
          showingNearest: resp.data['showing_nearest'] == true,
        );
      }
    } catch (e) {
      debugPrint('PrivilegeService.fetchPartners error: $e');
    }
    return (partners: <PrivilegePartner>[], hasMore: false, showingNearest: false);
  }

  /// GET /privilege/partners/{id}
  Future<PrivilegePartner?> fetchPartner(String id) async {
    try {
      final resp = await _api.get('${AppConstants.privilegePartners}/$id');
      if (resp.statusCode == 200 && resp.data is Map) {
        final p = resp.data['partner'];
        if (p is Map<String, dynamic>) return PrivilegePartner.fromJson(p);
      }
    } catch (e) {
      debugPrint('PrivilegeService.fetchPartner error: $e');
    }
    return null;
  }

  /// GET /privilege/coverage — how many partners per category in a city.
  Future<Map<String, int>> fetchCoverage(String city) async {
    try {
      final resp = await _api.get(AppConstants.privilegeCoverage,
          queryParams: {'city': city.trim()});
      if (resp.statusCode == 200 && resp.data is Map) {
        final out = <String, int>{};
        for (final c in ((resp.data['categories'] as List?) ?? [])) {
          if (c is Map) {
            out[(c['id'] ?? '').toString()] =
                (c['count'] as num?)?.toInt() ?? 0;
          }
        }
        return out;
      }
    } catch (e) {
      debugPrint('PrivilegeService.fetchCoverage error: $e');
    }
    return {};
  }

  /// POST /privilege/pass — issue a 10-minute eligibility pass.
  ///
  /// Returns (pass, error). Exactly one is non-null. The error is surfaced to
  /// the user because this happens at a counter: silently doing nothing is the
  /// worst possible outcome there.
  Future<({PrivilegePass? pass, String? error})> issuePass(String partnerId) async {
    try {
      final resp = await _api.post(AppConstants.privilegePass,
          data: {'partner_id': partnerId});
      if (resp.statusCode == 200 && resp.data is Map) {
        final p = resp.data['pass'];
        if (p is Map<String, dynamic>) {
          return (pass: PrivilegePass.fromJson(p), error: null);
        }
      }
      return (pass: null, error: 'Could not open your privilege. Please try again.');
    } catch (e) {
      debugPrint('PrivilegeService.issuePass error: $e');
      return (pass: null, error: _friendly(e));
    }
  }

  /// POST /privilege/pass/{reference}/approve
  Future<({PrivilegePass? pass, String? error})> approvePass(String reference) async {
    try {
      final resp = await _api.post(
          '${AppConstants.privilegePass}/$reference/approve');
      if (resp.statusCode == 200 && resp.data is Map) {
        final p = resp.data['pass'];
        if (p is Map<String, dynamic>) {
          return (pass: PrivilegePass.fromJson(p), error: null);
        }
      }
      return (pass: null, error: 'Could not approve. Please try again.');
    } catch (e) {
      debugPrint('PrivilegeService.approvePass error: $e');
      return (pass: null, error: _friendly(e));
    }
  }

  /// GET /privilege/history — this user's approved discounts, newest first.
  Future<List<PrivilegePass>> fetchHistory({int skip = 0, int limit = 50}) async {
    try {
      final resp = await _api.get(AppConstants.privilegeHistory,
          queryParams: {'skip': skip, 'limit': limit});
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = (resp.data['history'] as List?) ?? [];
        return list
            .whereType<Map<String, dynamic>>()
            .map(PrivilegePass.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('PrivilegeService.fetchHistory error: $e');
    }
    return [];
  }

  /// POST /privilege/partners/self — a user lists their own business.
  Future<({bool ok, String message})> createOwnPartner(
      Map<String, dynamic> body) async {
    try {
      final resp = await _api.post(
          '${AppConstants.privilegePartners}/self', data: body);
      if (resp.statusCode == 200 && resp.data is Map) {
        return (
          ok: true,
          message: (resp.data['message'] ??
                  'Submitted for review. It goes live once approved.')
              .toString(),
        );
      }
      return (ok: false, message: 'Could not submit. Please try again.');
    } catch (e) {
      debugPrint('PrivilegeService.createOwnPartner error: $e');
      return (ok: false, message: _friendly(e));
    }
  }

  /// Pulls the server's own `detail` out of a Dio error when there is one —
  /// "This pass has expired" is far more useful than "request failed".
  String _friendly(Object e) {
    try {
      final dynamic err = e;
      final data = err.response?.data;
      if (data is Map && data['detail'] is String) return data['detail'] as String;
    } catch (_) {}
    return 'Something went wrong. Please check your connection and try again.';
  }
}

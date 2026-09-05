import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/location_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The one location the whole app searches around.
//
// The client's brief turns on a single idea: "nearby" must mean near the
// SELECTED location, not near the phone. A customer sitting in Chennai who
// picks Madurai should see Madurai's shops, 5 km around Madurai.
//
// So the selected location lives here, once, and every screen reads it. When
// it changes, everything listening rebuilds — which is what "changing the
// location refreshes the entire app" means in practice.
//
// Two modes, exactly as the brief asks:
//   nearMe          — follow the phone's GPS
//   anotherLocation — a place the user chose by hand, GPS ignored
// ─────────────────────────────────────────────────────────────────────────────

enum LocationMode { nearMe, anotherLocation }

/// A place the user can search around.
class ClaimitPlace {
  final String label;      // "Anna Nagar"
  final String subLabel;   // "Chennai, Tamil Nadu"
  final String pincode;
  final double lat;
  final double lng;

  const ClaimitPlace({
    required this.label,
    this.subLabel = '',
    this.pincode = '',
    required this.lat,
    required this.lng,
  });

  /// What to show in the header: "Anna Nagar, Chennai" or with the PIN when
  /// the user searched by one, since that is what they typed.
  String get display {
    final parts = <String>[
      if (label.trim().isNotEmpty) label.trim(),
      if (subLabel.trim().isNotEmpty) subLabel.trim(),
    ];
    final base = parts.join(', ');
    if (pincode.isNotEmpty && !base.contains(pincode)) {
      return base.isEmpty ? pincode : '$base, $pincode';
    }
    return base.isEmpty ? 'Selected location' : base;
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'subLabel': subLabel,
        'pincode': pincode,
        'lat': lat,
        'lng': lng,
      };

  factory ClaimitPlace.fromJson(Map<String, dynamic> j) => ClaimitPlace(
        label: j['label'] as String? ?? '',
        subLabel: j['subLabel'] as String? ?? '',
        pincode: j['pincode'] as String? ?? '',
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
      );

  /// Two places are "the same" when they sit within ~100 m of each other.
  /// Used so the Recent list doesn't fill up with near-identical entries.
  bool isSameAs(ClaimitPlace o) =>
      (lat - o.lat).abs() < 0.001 && (lng - o.lng).abs() < 0.001;
}

class LocationProvider extends ChangeNotifier {
  // ── Constants from the brief ──────────────────────────────────────────────
  static const double kDefaultRadiusKm = 5.0;   // "default 5 km" everywhere
  static const double kExpandedRadiusKm = 10.0; // offered, never automatic

  static const _kSelected = 'claimit_selected_place';
  static const _kMode = 'claimit_location_mode';
  static const _kRadius = 'claimit_radius_km';
  static const _kRecent = 'claimit_recent_places';
  static const _kSaved = 'claimit_saved_places';
  static const int _kMaxRecent = 8;

  ClaimitPlace? _selected;
  ClaimitPlace? _gpsPlace;             // where the phone actually is
  LocationMode _mode = LocationMode.nearMe;
  double _radiusKm = kDefaultRadiusKm;
  List<ClaimitPlace> _recent = [];
  List<ClaimitPlace> _saved = [];
  bool _loading = false;
  bool _ready = false;

  // ── Reads ─────────────────────────────────────────────────────────────────
  ClaimitPlace? get selected => _selected;
  ClaimitPlace? get gpsPlace => _gpsPlace;
  LocationMode get mode => _mode;
  double get radiusKm => _radiusKm;
  List<ClaimitPlace> get recent => List.unmodifiable(_recent);
  List<ClaimitPlace> get saved => List.unmodifiable(_saved);
  bool get isLoading => _loading;
  bool get isReady => _ready;
  bool get hasLocation => _selected != null;

  double? get lat => _selected?.lat;
  double? get lng => _selected?.lng;

  /// "Anna Nagar, Chennai · Within 5 km" — the header the brief asks for.
  String get headerText => _selected == null
      ? 'Select a location'
      : '${_selected!.display} · Within ${_radiusKm.toStringAsFixed(0)} km';

  /// True when the user is browsing somewhere they are not. The UI uses this
  /// to also show "Your current location: Chennai", so nobody confuses the
  /// place they are with the place they are searching.
  bool get isSearchingElsewhere {
    if (_mode != LocationMode.anotherLocation) return false;
    if (_selected == null || _gpsPlace == null) return false;
    return !_selected!.isSameAs(_gpsPlace!);
  }

  // ── Start-up ──────────────────────────────────────────────────────────────
  /// Restore the last selection, then quietly try GPS.
  ///
  /// Restoring first matters: the app opens showing the place the user last
  /// chose, rather than a blank screen while a GPS fix is attempted. GPS is
  /// then only used if they are in Near Me mode.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _mode = (prefs.getString(_kMode) == 'another')
          ? LocationMode.anotherLocation
          : LocationMode.nearMe;
      _radiusKm = prefs.getDouble(_kRadius) ?? kDefaultRadiusKm;
      _selected = _readPlace(prefs.getString(_kSelected));
      _recent = _readList(prefs.getStringList(_kRecent));
      _saved = _readList(prefs.getStringList(_kSaved));
    } catch (e) {
      debugPrint('LocationProvider.init restore failed: $e');
    }

    // Publish the restored selection immediately, so the very first screen
    // load after a cold start already searches the right 5 km — rather than
    // waiting for a GPS fix that may never come.
    _publish();

    _ready = true;
    notifyListeners();

    // GPS is optional and never blocks start-up.
    if (_mode == LocationMode.nearMe || _selected == null) {
      unawaited(useCurrentLocation(silent: true));
    } else {
      unawaited(_refreshGpsPlaceQuietly());
    }
  }

  // ── Changing the location ─────────────────────────────────────────────────

  /// Switch to GPS. Falls back silently when location is unavailable — the
  /// user may simply have declined the permission, which is allowed.
  Future<bool> useCurrentLocation({bool silent = false}) async {
    _loading = true;
    if (!silent) notifyListeners();
    try {
      final pos = await LocationService.getPosition();
      if (pos == null) {
        _loading = false;
        notifyListeners();
        return false;
      }
      final place = await _describe(pos.latitude, pos.longitude);
      _gpsPlace = place;
      _selected = place;
      _mode = LocationMode.nearMe;
      _publish();
      await _persist();
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('useCurrentLocation failed: $e');
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Search somewhere else. This is the heart of brief 2 — the radius now
  /// applies around [place], however far away the user physically is.
  Future<void> setPlace(ClaimitPlace place,
      {LocationMode mode = LocationMode.anotherLocation}) async {
    _selected = place;
    _mode = mode;
    _addRecent(place);
    _publish();
    await _persist();
    notifyListeners();
  }

  Future<void> setRadiusKm(double km) async {
    _radiusKm = km.clamp(0.5, 50.0);
    _publish();
    await _persist();
    notifyListeners();
  }

  /// Widen to 10 km. Only ever called from the button the user taps after
  /// being told there was nothing within 5 km — never automatically.
  Future<void> expandRadius() => setRadiusKm(kExpandedRadiusKm);

  Future<void> resetRadius() => setRadiusKm(kDefaultRadiusKm);

  // ── Saved places ──────────────────────────────────────────────────────────
  Future<void> toggleSaved(ClaimitPlace place) async {
    final i = _saved.indexWhere((p) => p.isSameAs(place));
    if (i >= 0) {
      _saved.removeAt(i);
    } else {
      _saved.insert(0, place);
      if (_saved.length > 20) _saved = _saved.sublist(0, 20);
    }
    await _persist();
    notifyListeners();
  }

  bool isSaved(ClaimitPlace place) => _saved.any((p) => p.isSameAs(place));

  Future<void> clearRecent() async {
    _recent = [];
    await _persist();
    notifyListeners();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  /// Mirror the selection into LocationService's statics.
  ///
  /// The feature services (deals, reels, classifieds, shops) are context-free
  /// singletons that already read LocationService.lastArea. Publishing the
  /// point in the same place means every one of those screens searches the
  /// selected 5 km without a single screen having to change — and the moment
  /// the user picks a new location, they all follow.
  void _publish() {
    if (_selected != null) {
      LocationService.lastArea = _selected!.label;
      LocationService.lastPincode = _selected!.pincode;
      LocationService.selectedLat = _selected!.lat;
      LocationService.selectedLng = _selected!.lng;
    }
    LocationService.radiusKm = _radiusKm;
  }

  void _addRecent(ClaimitPlace place) {
    _recent.removeWhere((p) => p.isSameAs(place));
    _recent.insert(0, place);
    if (_recent.length > _kMaxRecent) {
      _recent = _recent.sublist(0, _kMaxRecent);
    }
  }

  /// Turn coordinates into a readable place name. If reverse geocoding fails
  /// the coordinates still work for searching — only the label suffers — so
  /// this never throws.
  Future<ClaimitPlace> _describe(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isNotEmpty) {
        final m = marks.first;
        final area = (m.subLocality?.trim().isNotEmpty == true)
            ? m.subLocality!.trim()
            : (m.locality?.trim() ?? '');
        final city = (m.locality?.trim() ?? '');
        return ClaimitPlace(
          label: area.isNotEmpty ? area : (city.isNotEmpty ? city : 'My location'),
          subLabel: (city.isNotEmpty && city != area) ? city : (m.administrativeArea ?? ''),
          pincode: m.postalCode?.trim() ?? '',
          lat: lat,
          lng: lng,
        );
      }
    } catch (e) {
      debugPrint('reverse geocode failed: $e');
    }
    return ClaimitPlace(label: 'My location', lat: lat, lng: lng);
  }

  /// Keep a note of where the phone is, without changing what is being
  /// searched — used for the "Your current location: Chennai" line.
  Future<void> _refreshGpsPlaceQuietly() async {
    try {
      final pos = await LocationService.getPosition();
      if (pos == null) return;
      _gpsPlace = await _describe(pos.latitude, pos.longitude);
      notifyListeners();
    } catch (_) {
      // Not important enough to surface.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_selected != null) {
        await prefs.setString(_kSelected, jsonEncode(_selected!.toJson()));
      }
      await prefs.setString(
          _kMode, _mode == LocationMode.anotherLocation ? 'another' : 'near');
      await prefs.setDouble(_kRadius, _radiusKm);
      await prefs.setStringList(
          _kRecent, _recent.map((p) => jsonEncode(p.toJson())).toList());
      await prefs.setStringList(
          _kSaved, _saved.map((p) => jsonEncode(p.toJson())).toList());
    } catch (e) {
      debugPrint('LocationProvider persist failed: $e');
    }
  }

  ClaimitPlace? _readPlace(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return ClaimitPlace.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  List<ClaimitPlace> _readList(List<String>? raw) {
    if (raw == null) return [];
    final out = <ClaimitPlace>[];
    for (final s in raw) {
      final p = _readPlace(s);
      if (p != null) out.add(p);
    }
    return out;
  }
}

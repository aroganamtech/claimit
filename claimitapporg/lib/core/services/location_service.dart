import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Robust GPS utility used everywhere in the app.
///
/// Call [LocationService.getPosition] to get the device's current position.
/// It handles the full lifecycle:
///   1. Location services enabled?       → prompt user to turn on GPS
///   2. Permission denied?               → request it
///   3. Permission denied forever?       → open app settings dialog
///   4. getCurrentPosition with timeout  → 10 s before falling back
///   5. Fallback to getLastKnownPosition → works offline / weak signal
///
/// Returns null only when absolutely nothing is available (user refused
/// all permission or GPS is completely unavailable).
class LocationService {
  LocationService._();

  /// Last reverse-geocoded area name (e.g. "Kovilpatti") and pincode.
  /// Set by the dashboard after a successful GPS + geocode; read by
  /// DealService / ReelService / banner fetch so ads and deals from the
  /// user's own area are shown FIRST (server-side prioritization).
  static String lastArea = '';
  static String lastPincode = '';

  /// The SELECTED location — the point every feature searches around, and the
  /// radius to search within.
  ///
  /// LocationProvider is the owner and keeps these in step whenever the user
  /// changes location. They are mirrored here as plain statics for the same
  /// reason lastArea is: the feature services (deals, reels, classifieds) are
  /// context-free singletons, so this is how they reach the selection without
  /// every screen having to pass it down.
  ///
  /// Null coordinates mean "not chosen yet" — every endpoint treats that as
  /// "no radius filter" and behaves exactly as it did before, so nothing can
  /// break while the user has not picked a location.
  static double? selectedLat;
  static double? selectedLng;
  static double radiusKm = 5.0;

  /// Query parameters for any endpoint that accepts a radius. Empty when no
  /// location is selected, which is what keeps the fallback automatic.
  static Map<String, dynamic> get geoParams => (selectedLat == null || selectedLng == null)
      ? const {}
      : {'lat': selectedLat, 'lng': selectedLng, 'radius_km': radiusKm};

  /// Timeout for a fresh GPS fix. After this we fall back to last-known.
  static const _timeout = Duration(seconds: 10);

  /// Desired accuracy for all location requests.
  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.medium, // ≈100 m — enough for 4 km radius
    timeLimit: Duration(seconds: 10),
  );

  // ── Concurrency guard ──────────────────────────────────────────────────────
  // Android throws "Can request only one set of permissions at a time" when
  // multiple widgets call getPosition() simultaneously. We serialise all
  // calls behind a single in-flight request so the OS only sees one
  // permission dialog at a time.
  static bool _requesting = false;
  static Completer<Position?>? _inFlight;

  // ─────────────────────────────────────────────────────────────────────────
  /// Main entry point.
  ///
  /// [context] — optional, kept for callers that still pass it.
  ///
  /// [promptIfNeeded] — whether this call may show the SYSTEM permission
  /// sheet. Defaults to **false**, which is the important part.
  ///
  /// Background callers (the dashboard warming up nearby shops on open, a
  /// list refreshing itself) must never trigger that sheet: being asked for
  /// GPS the instant the app opens, before doing anything, is exactly what
  /// the client asked us to stop. Those callers get whatever permission is
  /// ALREADY granted, and null otherwise — the app then falls back to the
  /// location the user picked by hand.
  ///
  /// Only a deliberate "Use my current location" tap passes true.
  ///
  /// Returns a [Position] or `null` if unavailable.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Position?> getPosition({
    BuildContext? context,
    bool promptIfNeeded = false,
  }) async {
    // If a request is already in flight, piggyback on it instead of making
    // a second concurrent permission request (which Android rejects).
    if (_requesting && _inFlight != null) {
      return _inFlight!.future;
    }

    _requesting = true;
    _inFlight = Completer<Position?>();

    try {
      final result = await _doGetPosition(
          context: context, promptIfNeeded: promptIfNeeded);
      _inFlight!.complete(result);
      return result;
    } catch (e) {
      _inFlight!.complete(null);
      return null;
    } finally {
      _requesting = false;
      _inFlight = null;
    }
  }

  /// Internal implementation — called only when no request is in flight.
  ///
  /// GPS is now OPTIONAL, never demanded.
  ///
  /// This used to interrupt the user with a "turn on location" dialog and a
  /// "go to app settings" dialog. The client asked for those to go: a customer
  /// who doesn't want to share GPS should still be able to use Claimit by
  /// typing an area or PIN code instead.
  ///
  /// So every failure path here now returns quietly. The caller gets null, and
  /// the app falls back to the location the user picked by hand.
  static Future<Position?> _doGetPosition({
    BuildContext? context,
    bool promptIfNeeded = false,
  }) async {
    // 1 ── Are location services turned on at the device level? ──────────────
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Was: _showServiceDialog(context) — removed, see note above.
      // Last-known can still be non-null even with services off (cached from
      // an earlier session on some devices), so it's worth asking.
      return _lastKnown();
    }

    // 2 ── Check / request permission ────────────────────────────────────────
    //
    // The system sheet is shown ONLY when the caller asked for it — i.e. the
    // user tapped "Use my current location". A background caller that finds
    // permission not yet granted gives up here and returns whatever is
    // cached, so opening the app never produces a permission prompt.
    LocationPermission perm = await Geolocator.checkPermission();

    if (perm == LocationPermission.denied) {
      if (!promptIfNeeded) return _lastKnown();
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.deniedForever) {
      // Was: _showSettingsDialog(context) — removed. Never push the user
      // into Android settings; manual location entry covers this case.
      return _lastKnown();
    }

    if (perm != LocationPermission.whileInUse &&
        perm != LocationPermission.always) {
      // Still denied after request (e.g. user dismissed the dialog)
      return _lastKnown();
    }

    // 3 ── Try fresh fix with timeout ────────────────────────────────────────
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: _settings,
      ).timeout(_timeout);
      return pos;
    } catch (_) {
      // Timeout, PlatformException, etc. — fall through to last-known
    }

    // 4 ── Fallback: last known position ─────────────────────────────────────
    return _lastKnown();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Future<Position?> _lastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  // ── The two dialogs below are no longer called ──────────────────────────
  //
  // They interrupted the user with "turn on location" and "open app settings"
  // prompts. The client asked for GPS to be optional, so _doGetPosition now
  // returns quietly instead and the user picks a location by hand.
  //
  // Kept, not deleted, so they can be switched back on for a screen that
  // genuinely cannot work without GPS — the bill-scan redeem flow, say —
  // by calling them from that screen rather than from every location lookup.

  /// Shown when device-level location services are OFF. Currently unused.
  // ignore: unused_element
  static void _showServiceDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      // Use the dialog's own BuildContext (dlgCtx) — not the outer `context` —
      // so that Navigator.pop() closes the dialog and not a go_router page.
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Location Off'),
        content: const Text(
          'Please turn on your device location (GPS) to find shops near you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dlgCtx).pop();
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Shown when the user has permanently denied location permission.
  // ignore: unused_element
  static void _showSettingsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      // Use the dialog's own BuildContext (dlgCtx) — not the outer `context` —
      // so that Navigator.pop() closes the dialog and not a go_router page.
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission was denied. '
          'Please enable it in App Settings to use nearby features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dlgCtx).pop();
              Geolocator.openAppSettings();
            },
            child: const Text('Open App Settings'),
          ),
        ],
      ),
    );
  }
}

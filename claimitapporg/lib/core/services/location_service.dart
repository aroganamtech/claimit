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
  /// [context] — optional. Pass it to show a "Go to Settings" dialog when
  /// the user has permanently denied location permission.
  ///
  /// Returns a [Position] or `null` if unavailable.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Position?> getPosition({BuildContext? context}) async {
    // If a request is already in flight, piggyback on it instead of making
    // a second concurrent permission request (which Android rejects).
    if (_requesting && _inFlight != null) {
      return _inFlight!.future;
    }

    _requesting = true;
    _inFlight = Completer<Position?>();

    try {
      final result = await _doGetPosition(context: context);
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
  static Future<Position?> _doGetPosition({BuildContext? context}) async {
    // 1 ── Are location services turned on at the device level? ──────────────
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context != null && context.mounted) {
        _showServiceDialog(context);
      }
      // Try last-known before giving up; it might be non-null even when
      // services are off (cached from a previous session on some devices).
      return _lastKnown();
    }

    // 2 ── Check / request permission ────────────────────────────────────────
    LocationPermission perm = await Geolocator.checkPermission();

    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.deniedForever) {
      if (context != null && context.mounted) {
        _showSettingsDialog(context);
      }
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

  /// Shown when device-level location services are OFF.
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

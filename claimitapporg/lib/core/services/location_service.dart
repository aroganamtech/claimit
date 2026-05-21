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

  /// Timeout for a fresh GPS fix. After this we fall back to last-known.
  static const _timeout = Duration(seconds: 10);

  /// Desired accuracy for all location requests.
  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.medium, // ≈100 m — enough for 4 km radius
    timeLimit: Duration(seconds: 10),
  );

  // ─────────────────────────────────────────────────────────────────────────
  /// Main entry point.
  ///
  /// [context] — optional. Pass it to show a "Go to Settings" dialog when
  /// the user has permanently denied location permission.
  ///
  /// Returns a [Position] or `null` if unavailable.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Position?> getPosition({BuildContext? context}) async {
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

  // ── Helpers ────────────────────────────────────────────────────────────────

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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Location Off'),
        content: const Text(
          'Please turn on your device location (GPS) to find shops near you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission was denied. '
          'Please enable it in App Settings to use nearby features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openAppSettings();
            },
            child: const Text('Open App Settings'),
          ),
        ],
      ),
    );
  }
}

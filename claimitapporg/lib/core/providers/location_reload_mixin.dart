import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'location_provider.dart';

/// Makes a screen refetch when the user changes the location.
///
/// Why this exists
/// ---------------
/// Every feature screen was written the same way: `initState` calls `_load()`
/// once, and `_load()` reads `LocationService.selectedLat/Lng/radiusKm`. Those
/// statics are a snapshot taken at the moment of the call.
///
/// `LocationProvider` does its half correctly — it updates the statics and
/// calls `notifyListeners()`. But nothing was listening, so changing the
/// location updated the header and left the list underneath showing the
/// previous place's results. That is the bug behind "I changed the location
/// and the professionals below didn't change", and the identical complaint in
/// Privilege and Reward Zone.
///
/// How to use it
/// -------------
/// ```dart
/// class _MyScreenState extends State<MyScreen> with LocationReloadMixin {
///   @override
///   void initState() {
///     super.initState();
///     _load();
///   }
///
///   @override
///   void onLocationChanged() => _load();   // that's the whole change
/// }
/// ```
///
/// The mixin does NOT load on first build — `initState` already did that.
/// It only fires on an actual change, so a screen never fetches twice on open.
mixin LocationReloadMixin<T extends StatefulWidget> on State<T> {
  String? _lastLocationKey;

  /// Refetch whatever this screen shows. Usually one line: `_load();`
  void onLocationChanged();

  /// The selected point, for building a request. Null when nothing is picked
  /// yet, which every backend treats as "no radius filter".
  double? get selectedLat =>
      Provider.of<LocationProvider>(context, listen: false).lat;
  double? get selectedLng =>
      Provider.of<LocationProvider>(context, listen: false).lng;
  double get selectedRadiusKm =>
      Provider.of<LocationProvider>(context, listen: false).radiusKm;

  /// City name for the endpoints that filter by city rather than coordinates.
  String get selectedCity =>
      Provider.of<LocationProvider>(context, listen: false).cityLabel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // listen: true on purpose — this is what subscribes the element to the
    // provider, so didChangeDependencies runs again on every notifyListeners.
    // Doing it here rather than in build keeps the fetch out of the build
    // phase, where calling setState is illegal.
    final key = Provider.of<LocationProvider>(context).locationKey;

    if (_lastLocationKey == null) {
      _lastLocationKey = key;      // first pass: initState has already loaded
      return;
    }
    if (_lastLocationKey == key) return;

    _lastLocationKey = key;

    // Deferred to the next frame. didChangeDependencies can run mid-build of
    // an ancestor, and a synchronous setState from a fetch started here would
    // throw "setState() called during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onLocationChanged();
    });
  }
}

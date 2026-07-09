import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/services/location_service.dart';
import '../../auth/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LocationScreen
//  • Previously-selected location shown highlighted at the top
//  • Real-time Nominatim search (OpenStreetMap — free, no API key)
//  • Manual text entry for anything not found via search
//  • Popular location chips as fallback
// ─────────────────────────────────────────────────────────────────────────────

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  static const _blue       = Color(0xFF2563EB);
  static const _blueLight  = Color(0xFFEFF6FF);

  final _searchCtrl = TextEditingController();
  Timer?  _debounce;

  bool _showManual   = false;
  bool _isSearching  = false;
  bool _isGpsLoading = false;
  bool _isSaving     = false;

  String? _selectedLocation;
  List<Map<String, dynamic>> _results = [];

  final List<Map<String, dynamic>> _popularLocations = const [
    {'name': 'Anna Nagar',      'count': 24},
    {'name': 'Thoraipakkam',    'count': 23},
    {'name': 'Sholinganallur',  'count': 41},
    {'name': 'OMR',             'count': 12},
    {'name': 'Guindy',          'count': 2},
    {'name': 'Padi',            'count': 30},
    {'name': 'Nungambakkam',    'count': 27},
    {'name': 'Kotturpuram',     'count': 25},
    {'name': 'Velachery',       'count': 22},
    {'name': 'Besant Nagar',    'count': 30},
    {'name': 'Kodambakkam',     'count': 29},
    {'name': 'Thiruvanmiyur',   'count': 28},
    {'name': 'Mylapore',        'count': 35},
    {'name': 'Choolaimedu',     'count': 21},
    {'name': 'T. Nagar',        'count': 38},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = context.read<AuthProvider>().user?.location;
      if (saved != null && saved.isNotEmpty) {
        setState(() => _selectedLocation = saved);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Nominatim search (debounced 500 ms) ───────────────────────────────────
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    final q = query.trim();
    if (q.length < 2) {
      setState(() { _results = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () => _doSearch(q));
  }

  Future<void> _doSearch(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&limit=6&addressdetails=1&countrycodes=in',
      );
      final res = await http.get(uri, headers: {
        'Accept-Language': 'en',
        'User-Agent': 'ClaimitApp/1.0',
      }).timeout(const Duration(seconds: 8));

      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() { _results = []; _isSearching = false; });
        return;
      }

      final list = jsonDecode(res.body) as List<dynamic>;
      final parsed = <Map<String, dynamic>>[];
      for (final e in list) {
        final addr = (e['address'] as Map<String, dynamic>?) ?? {};
        final parts = <String>[];
        final suburb   = addr['suburb']   as String?;
        final locality = addr['locality'] as String?;
        final city     = addr['city']     as String?
                      ?? addr['town']     as String?
                      ?? addr['county']   as String?;
        final state    = addr['state']    as String?;

        if (suburb?.isNotEmpty   == true) parts.add(suburb!);
        if (locality?.isNotEmpty == true && locality != suburb) parts.add(locality!);
        if (city?.isNotEmpty     == true && city != suburb)     parts.add(city!);
        if (state?.isNotEmpty    == true)                       parts.add(state!);

        final label = parts.isNotEmpty
            ? parts.take(3).join(', ')
            : (e['display_name'] as String);
        parsed.add({'label': label});
      }
      setState(() { _results = parsed; _isSearching = false; });
    } catch (_) {
      if (mounted) setState(() { _results = []; _isSearching = false; });
    }
  }

  // ── Confirm selection ─────────────────────────────────────────────────────
  Future<void> _selectLocation(String location) async {
    if (_isSaving) return;
    setState(() { _selectedLocation = location; _isSaving = true; });
    await context.read<AuthProvider>().updateLocation(location);
    // Selected app-bar location drives deal/banner/reel ordering — takes
    // effect immediately (area = first part before the comma, e.g.
    // "Mudukulathur, Tamil Nadu" → "Mudukulathur").
    LocationService.lastArea = location.split(',').first.trim();
    LocationService.lastPincode = '';
    if (!mounted) return;
    setState(() => _isSaving = false);
    context.go('/home');
  }

  // ── GPS ───────────────────────────────────────────────────────────────────
  Future<void> _useCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isGpsLoading = true);
    try {
      // ── GPS service check ────────────────────────────────────────────────
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        // GPS off → close the screen; user must enable it first
        _exitScreen();
        return;
      }

      // ── Permission ───────────────────────────────────────────────────────
      LocationPermission perm = await Geolocator.checkPermission();

      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        // After the system dialog closes, Android fires a flood of IME-hide
        // events. Do NOT call setState/ScaffoldMessenger here — just leave.
        if (!mounted) return;
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          _exitScreen();
          return;
        }
      }

      if (!mounted) return;
      if (perm == LocationPermission.deniedForever) {
        _exitScreen();
        return;
      }

      // ── Get position ─────────────────────────────────────────────────────
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;

      // ── Reverse-geocode ───────────────────────────────────────────────────
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (!mounted) return;

      String area = 'Current Location';
      if (marks.isNotEmpty) {
        final p = marks.first;
        area = p.subLocality?.isNotEmpty == true
            ? p.subLocality!
            : p.locality?.isNotEmpty == true
                ? p.locality!
                : 'Current Location';
      }
      await _selectLocation(area);
    } catch (_) {
      if (mounted) _exitScreen();
    }
  }

  /// Close the location screen — used when permission is denied or GPS fails.
  /// Goes home if we can't pop (i.e. location screen was the root route).
  void _exitScreen() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 26, color: _blue),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Select Your Location',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _blue,
                    ),
                  ),
                ],
              ),
            ),

            // ── Search bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search area, city or address…',
                  hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF9CA3AF), size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF9CA3AF), size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(
                                () { _results = []; _isSearching = false; });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide:
                        const BorderSide(color: _blue, width: 1.5),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── GPS button ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _isGpsLoading ? null : _useCurrentLocation,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _blueLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _isGpsLoading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _blue),
                            )
                          : const Icon(Icons.my_location_rounded,
                              color: _blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _isGpsLoading
                            ? 'Detecting location…'
                            : 'Use Current Location',
                        style: const TextStyle(
                          color: _blue,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Manual entry toggle ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () =>
                    setState(() => _showManual = !_showManual),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showManual
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.edit_location_alt_outlined,
                      color: const Color(0xFF6B7280),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showManual
                          ? 'Hide manual entry'
                          : 'Enter location manually',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_showManual) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ManualEntry(onConfirm: _selectLocation),
              ),
            ],

            const SizedBox(height: 10),

            // ── Main body ─────────────────────────────────────────────────
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final q = _searchCtrl.text.trim();

    // Searching spinner
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _blue, strokeWidth: 2),
            SizedBox(height: 12),
            Text('Searching…',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
          ],
        ),
      );
    }

    // Nominatim results
    if (q.length >= 2 && _results.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _results.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
        itemBuilder: (ctx, i) {
          final label = _results[i]['label'] as String;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.location_on_rounded,
                color: _blue, size: 22),
            title: Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            onTap: () => _selectLocation(label),
          );
        },
      );
    }

    // No search results
    if (q.length >= 2 && _results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                color: Color(0xFFD1D5DB), size: 48),
            const SizedBox(height: 12),
            const Text(
              'No locations found.\nTry a different name or enter manually.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => setState(() { _showManual = true; }),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Enter manually'),
              style: TextButton.styleFrom(foregroundColor: _blue),
            ),
          ],
        ),
      );
    }

    // Default: previous + popular chips
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Previously selected location
          if (_selectedLocation != null) ...[
            const Text(
              'Your current area',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectLocation(_selectedLocation!),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: _blue.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 15),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _selectedLocation!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white70, size: 15),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Popular locations
          const Text(
            'Popular locations',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _popularLocations.map((loc) {
              final name     = loc['name'] as String;
              final count    = loc['count'] as int;
              final isActive = _selectedLocation == name;
              return GestureDetector(
                onTap: _isSaving ? null : () => _selectLocation(name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? _blue : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? _blue : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: _isSaving && isActive
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          '$name ($count)',
                          style: TextStyle(
                            fontSize: 13,
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Stateful manual entry row ─────────────────────────────────────────────────
class _ManualEntry extends StatefulWidget {
  final void Function(String) onConfirm;
  const _ManualEntry({required this.onConfirm});

  @override
  State<_ManualEntry> createState() => _ManualEntryState();
}

class _ManualEntryState extends State<_ManualEntry> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          // autofocus removed — setting focus mid-layout triggers
          // setState during layout phase → !_debugDoingThisLayout assertion
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Anna Nagar, Chennai',
            hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
          onSubmitted: (v) {
            final loc = v.trim();
            if (loc.isNotEmpty) widget.onConfirm(loc);
          },
        ),
        const SizedBox(height: 8),
        // Full-width button in Column avoids the unconstrained-width
        // layout error that ElevatedButton gets inside an unbounded Row
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              final loc = _ctrl.text.trim();
              if (loc.isNotEmpty) widget.onConfirm(loc);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: const Text('Set Location',
                style: TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _searchController = TextEditingController();
  String? _selectedLocation;
  bool _isLoading = false;
  bool _isGpsLoading = false;

  final List<Map<String, dynamic>> _popularLocations = const [
    {'name': 'Anna Nagar', 'count': 24},
    {'name': 'Thoraipakkam', 'count': 23},
    {'name': 'Sholinganallur', 'count': 41},
    {'name': 'OMR', 'count': 12},
    {'name': 'Guindy', 'count': 2},
    {'name': 'Padi', 'count': 30},
    {'name': 'Nungambakkam', 'count': 27},
    {'name': 'Kotturpuram', 'count': 25},
    {'name': 'Velachery', 'count': 22},
    {'name': 'Besant Nagar', 'count': 30},
    {'name': 'Kodambakkam', 'count': 29},
    {'name': 'Thiruvanmiyur', 'count': 28},
    {'name': 'Mylapore', 'count': 35},
    {'name': 'Choolaimedu', 'count': 21},
    {'name': 'T. Nagar', 'count': 38},
  ];

  List<Map<String, dynamic>> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _popularLocations;
    return _popularLocations
        .where((l) => (l['name'] as String).toLowerCase().contains(q))
        .toList();
  }

  // ── Save location to backend + navigate home ──────────────────────────────
  Future<void> _selectLocation(String location) async {
    setState(() {
      _selectedLocation = location;
      _isLoading = true;
    });
    // Save via AuthProvider — updates backend + local user object atomically
    await context.read<AuthProvider>().updateLocation(location);
    if (!mounted) return;
    setState(() => _isLoading = false);
    context.go('/home');
  }

  // ── Real GPS → reverse geocode → save ────────────────────────────────────
  Future<void> _useCurrentLocation() async {
    setState(() => _isGpsLoading = true);

    try {
      // 1. Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Please enable location services on your device');
        setState(() => _isGpsLoading = false);
        return;
      }

      // 2. Request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permission denied');
          setState(() => _isGpsLoading = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack('Location permission permanently denied — enable it in Settings');
        setState(() => _isGpsLoading = false);
        return;
      }

      // 3. Get position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // 4. Reverse geocode to a readable area name
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String areaName = 'Current Location';
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        // Try subLocality first (e.g. "Anna Nagar"), then locality (city)
        areaName = p.subLocality?.isNotEmpty == true
            ? p.subLocality!
            : p.locality?.isNotEmpty == true
                ? p.locality!
                : 'Current Location';
      }

      await _selectLocation(areaName);
    } catch (e) {
      if (mounted) {
        _showSnack('Could not get location. Please select manually.');
        setState(() => _isGpsLoading = false);
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.canPop() ? context.pop() : context.go('/home'),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 22, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Select Your Location',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),

            // ── Search bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search for area',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF9CA3AF), size: 20),
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
                        const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Use Current Location ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _isGpsLoading ? null : _useCurrentLocation,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isGpsLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF2563EB)),
                        )
                      else
                        const Icon(Icons.my_location_rounded,
                            color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _isGpsLoading ? 'Detecting location...' : 'Use Current Location',
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Popular locations label ──────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Popular locations',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Chips ────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _filtered.map((loc) {
                    final name = loc['name'] as String;
                    final count = loc['count'] as int;
                    final isSelected = _selectedLocation == name;

                    return GestureDetector(
                      onTap: () => _selectLocation(name),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: _isLoading && isSelected
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                '$name ($count)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF374151),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

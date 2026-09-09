import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/location_service.dart';
import '../models/select_category.dart';
import '../models/select_coverage.dart';
import '../services/select_service.dart';
import '../widgets/select_common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Claimit Select — "Who's here?"
//
// Opened from the location chip on the Select home. Answers the one question
// the 12-tile category grid cannot: is it worth looking in this city at all?
// Without this the user taps twelve categories to discover eleven are empty.
//
// Three sections, in the order the question is actually asked:
//   1. the total for the city
//   2. the category-by-category breakdown (zeros included — a zero is the
//      most useful number on this screen, so it is shown, not hidden)
//   3. nearby cities that DO have people, nearest first
//
// Typing in the city field re-runs the query, debounced, so this doubles as a
// way to check any city, not just the selected one.
//
// Overflow safety: every city/category name is Expanded + maxLines + ellipsis,
// and the counts are fixed-width chips, so a long name or a large system font
// cannot produce a RenderFlex overflow.
// ─────────────────────────────────────────────────────────────────────────────

class SelectCoverageScreen extends StatefulWidget {
  /// City to show on open — normally the user's selected location.
  final String initialCity;

  const SelectCoverageScreen({super.key, this.initialCity = ''});

  @override
  State<SelectCoverageScreen> createState() => _SelectCoverageScreenState();
}

class _SelectCoverageScreenState extends State<SelectCoverageScreen> {
  late final TextEditingController _cityCtrl =
      TextEditingController(text: widget.initialCity.trim());

  Timer? _debounce;
  bool _loading = true;
  SelectCoverage _data = SelectCoverage.empty;

  /// Coordinates are only meaningful for the city the app actually selected.
  /// Once the user types a different city name, sending the old point would
  /// list "nearby" cities around the wrong place — so it is dropped.
  bool get _cityIsSelectedOne =>
      _cityCtrl.text.trim().toLowerCase() ==
      widget.initialCity.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final usePoint = _cityIsSelectedOne;
    final res = await SelectService.instance.fetchCoverage(
      city: _cityCtrl.text,
      lat: usePoint ? LocationService.selectedLat : null,
      lng: usePoint ? LocationService.selectedLng : null,
    );
    if (!mounted) return;
    setState(() {
      _data = res;
      _loading = false;
    });
  }

  void _onCityChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _load);
  }

  void _openCity(String city) {
    _cityCtrl.text = city;
    _load();
  }

  void _openCategory(String id) {
    context.push('/select/list', extra: {'category': selectCategoryById(id)});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSelBg,
      appBar: AppBar(
        backgroundColor: kSelYellow,
        foregroundColor: kSelOnYellow,
        elevation: 0,
        title: const Text(
          "Who's here?",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          // The Select location chip now opens this screen, so the shared
          // location picker keeps a one-tap route from here — otherwise
          // changing location would only be possible from the dashboard.
          IconButton(
            tooltip: 'Change location',
            icon: const Icon(Icons.my_location_rounded, size: 20),
            onPressed: () => context.push('/location'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          // Always scrollable, so pull-to-refresh still works on a short page
          // (a city with two categories would otherwise not scroll at all).
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [
            _cityField(),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _totalCard(),
              const SizedBox(height: 18),
              _sectionTitle('By category'),
              const SizedBox(height: 8),
              _categoryList(),
              const SizedBox(height: 22),
              _sectionTitle('Nearby cities'),
              const SizedBox(height: 8),
              _nearbyList(),
            ],
          ],
        ),
      ),
    );
  }

  // ── City input ────────────────────────────────────────────────────────────
  Widget _cityField() {
    return TextField(
      controller: _cityCtrl,
      onChanged: _onCityChanged,
      onSubmitted: (_) => _load(),
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14.5, color: kSelInk),
      decoration: InputDecoration(
        hintText: 'Enter a city — e.g. Chennai',
        prefixIcon: const Icon(Icons.location_city_rounded,
            size: 20, color: kSelAccent),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kSelLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kSelLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kSelAccent, width: 1.4),
        ),
      ),
    );
  }

  // ── Total ─────────────────────────────────────────────────────────────────
  Widget _totalCard() {
    final n = _data.total;
    // With no city typed the backend counts everywhere, so the sentence has to
    // change rather than read "professionals in everywhere".
    final where = _data.city.isEmpty ? 'listed' : 'in ${_data.city}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD233), kSelYellow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$n',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: kSelOnYellow,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            n == 1 ? 'professional $where' : 'professionals $where',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: kSelOnYellow,
            ),
          ),
          if (n == 0) ...[
            const SizedBox(height: 8),
            const Text(
              'Nothing listed here yet — try a nearby city below.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Color(0xFF6B5800)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: kSelInk,
        ),
      );

  // ── Category breakdown ────────────────────────────────────────────────────
  Widget _categoryList() {
    if (_data.categories.isEmpty) {
      return _emptyNote('No categories to show.');
    }
    // Busiest first — the user is looking for where the people are. Ties keep
    // the backend's display order, which List.sort preserves for equal keys
    // closely enough here (a stable order is not required for correctness).
    final rows = [..._data.categories]
      ..sort((a, b) => b.count.compareTo(a.count));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kSelLine),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            _categoryRow(rows[i], isLast: i == rows.length - 1),
        ],
      ),
    );
  }

  Widget _categoryRow(SelectCategoryCount c, {required bool isLast}) {
    final empty = c.count == 0;
    return InkWell(
      // An empty category has nothing to open, so it is not tappable — a tap
      // that leads to a blank list is worse than no tap at all.
      onTap: empty ? null : () => _openCategory(c.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: kSelLine)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                c.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: empty ? kSelMuted : kSelInk,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _countChip(c.count),
            if (!empty) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: kSelMuted),
            ] else
              const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }

  Widget _countChip(int n) {
    final empty = n == 0;
    return Container(
      constraints: const BoxConstraints(minWidth: 34),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: empty ? const Color(0xFFF1F5F9) : const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$n',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: empty ? kSelMuted : kSelAccent,
        ),
      ),
    );
  }

  // ── Nearby cities ─────────────────────────────────────────────────────────
  Widget _nearbyList() {
    if (!_data.located) {
      return _emptyNote(
        "Couldn't work out where this city is, so nearby cities aren't "
        'available. Try selecting the location from the map instead.',
      );
    }
    if (_data.nearby.isEmpty) {
      return _emptyNote(
        'No other cities with listings within '
        '${_data.radiusKm.toStringAsFixed(0)} km.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kSelLine),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _data.nearby.length; i++)
            _nearbyRow(_data.nearby[i], isLast: i == _data.nearby.length - 1),
        ],
      ),
    );
  }

  Widget _nearbyRow(SelectNearbyCity c, {required bool isLast}) {
    return InkWell(
      onTap: () => _openCity(c.city),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: kSelLine)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    c.city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kSelInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${c.distanceKm.toStringAsFixed(1)} km away',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: kSelMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _countChip(c.count),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20, color: kSelMuted),
          ],
        ),
      ),
    );
  }

  Widget _emptyNote(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kSelLine),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: kSelMuted, height: 1.4),
        ),
      );
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/providers/location_provider.dart';
import '../../search/services/claimit_search_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Choose the location the whole app searches around.
//
// The client's brief asks for exactly two ways in:
//
//   Near Me                — use the phone's GPS
//   Search Another Location — type any area, city or PIN code
//
// plus Recent and Saved lists so a regular trip (home ↔ office ↔ parents'
// town) is one tap, not a re-typed search every time.
//
// Two things this screen is careful about:
//
//   • GPS is never demanded. Everything on this screen works with location
//     switched off — typing an area gives real coordinates, so the 5 km search
//     behaves identically. The manual route is the FIRST thing offered, not a
//     hidden fallback.
//   • Whatever is picked here becomes the one location for every feature. It
//     is written to LocationProvider, which every screen listens to, so
//     changing it here refreshes the entire app.
// ─────────────────────────────────────────────────────────────────────────────

const Color _blue = Color(0xFF1565C0);
const Color _ink = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const Color _gold = Color(0xFFF4B400);

class ClaimitLocationPicker extends StatefulWidget {
  const ClaimitLocationPicker({super.key});

  @override
  State<ClaimitLocationPicker> createState() => _ClaimitLocationPickerState();
}

class _ClaimitLocationPickerState extends State<ClaimitLocationPicker> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  List<PlaceSuggestion> _results = [];
  bool _searching = false;
  bool _gpsBusy = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // ── Typing an area, city or PIN code ─────────────────────────────────────
  void _onChanged(String q) {
    _debounce?.cancel();
    final text = q.trim();
    if (text.length < 2) {
      setState(() {
        _results = [];
        _searching = false;
        _searched = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 450), () => _lookup(text));
  }

  /// Claimit's own places first, then the map as a backstop.
  ///
  /// Our own data is preferred because every place it offers is somewhere with
  /// listings — the user cannot pick a location that is empty by definition.
  /// The map lookup only fills in places Claimit hasn't reached yet, so the
  /// user is never told "not found" for a real town.
  Future<void> _lookup(String text) async {
    final mine = await ClaimitSearchService.instance.places(text);
    if (!mounted) return;

    if (mine.isNotEmpty) {
      setState(() {
        _results = mine;
        _searching = false;
        _searched = true;
      });
      return;
    }

    final osm = await _lookupOpenStreetMap(text);
    if (!mounted) return;
    setState(() {
      _results = osm;
      _searching = false;
      _searched = true;
    });
  }

  Future<List<PlaceSuggestion>> _lookupOpenStreetMap(String text) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(text)}'
        '&format=json&limit=6&addressdetails=1&countrycodes=in',
      );
      final res = await http.get(uri, headers: {
        'Accept-Language': 'en',
        'User-Agent': 'ClaimitApp/1.0',
      }).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];

      final list = jsonDecode(res.body) as List<dynamic>;
      final out = <PlaceSuggestion>[];
      for (final e in list) {
        final lat = double.tryParse('${e['lat']}');
        final lng = double.tryParse('${e['lon']}');
        if (lat == null || lng == null) continue;

        final addr = (e['address'] as Map<String, dynamic>?) ?? {};
        final area = (addr['suburb'] ?? addr['neighbourhood'] ?? addr['village'])
            as String?;
        final city =
            (addr['city'] ?? addr['town'] ?? addr['county']) as String?;
        final state = addr['state'] as String?;

        final label = (area?.trim().isNotEmpty == true)
            ? area!.trim()
            : (city?.trim().isNotEmpty == true
                ? city!.trim()
                : ('${e['display_name']}').split(',').first.trim());

        out.add(PlaceSuggestion(
          label: label,
          subLabel: [
            if (city != null && city.trim().isNotEmpty && city.trim() != label)
              city.trim(),
            if (state != null && state.trim().isNotEmpty) state.trim(),
          ].join(', '),
          pincode: (addr['postcode'] as String?)?.trim() ?? '',
          lat: lat,
          lng: lng,
        ));
      }
      return out;
    } catch (_) {
      // The map service being unreachable must never break the screen — the
      // user can still use Near Me, Recent or Saved.
      return const [];
    }
  }

  // ── Committing a choice ──────────────────────────────────────────────────
  Future<void> _choose(ClaimitPlace place) async {
    await context.read<LocationProvider>().setPlace(place);
    if (!mounted) return;
    _close();
  }

  Future<void> _useGps() async {
    setState(() => _gpsBusy = true);
    final ok = await context.read<LocationProvider>().useCurrentLocation();
    if (!mounted) return;
    setState(() => _gpsBusy = false);

    if (ok) {
      _close();
      return;
    }
    // Declining the permission is a legitimate choice, so this is information,
    // not an error, and the typing field above stays ready.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          "Couldn't read your location. Type your area or PIN code instead — "
          'it works exactly the same.'),
      duration: Duration(seconds: 4),
    ));
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _blue, size: 20),
          onPressed: _close,
        ),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Choose Location',
              maxLines: 1,
              style: TextStyle(
                  color: _blue, fontWeight: FontWeight.w700, fontSize: 18)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _field(),
            Expanded(
              child: _searching
                  ? const Center(
                      child: CircularProgressIndicator(color: _blue))
                  : (_ctrl.text.trim().length >= 2
                      ? _resultList()
                      : _defaultList(loc)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _ctrl,
          onChanged: _onChanged,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Type an area, city or PIN code',
            hintStyle: const TextStyle(color: _muted, fontSize: 13.5),
            prefixIcon:
                const Icon(Icons.search_rounded, color: _muted, size: 20),
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: _muted),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() {
                        _results = [];
                        _searched = false;
                      });
                    },
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(26),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(26),
              borderSide: const BorderSide(color: _blue, width: 1.4),
            ),
          ),
        ),
      );

  Widget _resultList() {
    if (_searched && _results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(28, 50, 28, 24),
        children: [
          Icon(Icons.location_off_rounded, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            "We couldn't find that place. Try the PIN code, or a nearby town.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: _muted, height: 1.4),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (_, i) {
        final p = _results[i];
        return ListTile(
          leading: const Icon(Icons.place_rounded, color: _blue, size: 22),
          title: Text(p.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w600, color: _ink)),
          subtitle: (p.subLabel.isEmpty && p.pincode.isEmpty)
              ? null
              : Text(
                  [p.subLabel, p.pincode].where((s) => s.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
          // Capped so a large system font can't push the count into the
          // title and overflow the row.
          trailing: p.listingCount > 0
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 78),
                  child: Text('${p.listingCount} listings',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, color: _muted)),
                )
              : null,
          onTap: () => _choose(ClaimitPlace(
            label: p.label,
            subLabel: p.subLabel,
            pincode: p.pincode,
            lat: p.lat,
            lng: p.lng,
          )),
        );
      },
    );
  }

  /// What the user sees before typing: the two ways in, then their own lists.
  Widget _defaultList(LocationProvider loc) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _bigButton(
            icon: Icons.my_location_rounded,
            label: _gpsBusy ? 'Finding you…' : 'Use My Current Location',
            background: const Color(0xFFEFF6FF),
            border: const Color(0xFFBFDBFE),
            foreground: _blue,
            busy: _gpsBusy,
            onTap: _gpsBusy ? null : _useGps,
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Location does not have to be switched on. Typing your area or '
              'PIN code above works exactly the same.',
              style: TextStyle(fontSize: 12, height: 1.35, color: _muted),
            ),
          ),
          if (loc.selected != null) ...[
            const SizedBox(height: 18),
            _sectionTitle('Currently searching'),
            _placeTile(
              place: loc.selected!,
              icon: Icons.check_circle_rounded,
              iconColour: const Color(0xFF16A34A),
              trailingText: 'Within ${loc.radiusKm.toStringAsFixed(0)} km',
              onTap: _close,
              loc: loc,
            ),
          ],
          if (loc.saved.isNotEmpty) ...[
            const SizedBox(height: 18),
            _sectionTitle('Saved places'),
            ...loc.saved.map((p) => _placeTile(
                  place: p,
                  icon: Icons.bookmark_rounded,
                  iconColour: _gold,
                  onTap: () => _choose(p),
                  loc: loc,
                )),
          ],
          if (loc.recent.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _sectionTitle('Recent')),
                TextButton(
                  onPressed: loc.clearRecent,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Clear',
                      style: TextStyle(fontSize: 12, color: _muted)),
                ),
              ],
            ),
            ...loc.recent.map((p) => _placeTile(
                  place: p,
                  icon: Icons.history_rounded,
                  iconColour: _muted,
                  onTap: () => _choose(p),
                  loc: loc,
                )),
          ],
          const SizedBox(height: 18),
          _sectionTitle('Search radius'),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'How far around the selected place to look.',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [2.0, 5.0, 10.0, 25.0]
                .map((km) => _radiusChip(km, loc))
                .toList(),
          ),
        ],
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w800, color: _ink)),
      );

  Widget _radiusChip(double km, LocationProvider loc) {
    final on = (loc.radiusKm - km).abs() < 0.01;
    return Material(
      color: on ? _blue : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => loc.setRadiusKm(km),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? _blue : const Color(0xFFE2E8F0)),
          ),
          child: Text('${km.toStringAsFixed(0)} km',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: on ? Colors.white : _ink)),
        ),
      ),
    );
  }

  Widget _placeTile({
    required ClaimitPlace place,
    required IconData icon,
    required Color iconColour,
    required VoidCallback onTap,
    required LocationProvider loc,
    String? trailingText,
  }) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Icon(icon, color: iconColour, size: 22),
        title: Text(place.display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
        subtitle: trailingText == null
            ? null
            : Text(trailingText,
                style: const TextStyle(fontSize: 11.5, color: _muted)),
        trailing: IconButton(
          tooltip: loc.isSaved(place) ? 'Remove from saved' : 'Save this place',
          icon: Icon(
            loc.isSaved(place)
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            size: 20,
            color: loc.isSaved(place) ? _gold : _muted,
          ),
          onPressed: () => loc.toggleSaved(place),
        ),
        onTap: onTap,
      );

  Widget _bigButton({
    required IconData icon,
    required String label,
    required Color background,
    required Color border,
    required Color foreground,
    required VoidCallback? onTap,
    bool busy = false,
  }) =>
      Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: foreground),
                      )
                    : Icon(icon, color: foreground, size: 21),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: foreground)),
                ),
              ],
            ),
          ),
        ),
      );
}

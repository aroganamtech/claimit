import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/location_provider.dart';
import '../services/claimit_search_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// One search across the whole of Claimit.
//
// The brief's point 5: search must work by shop name, category, product,
// service, profession, brand, offer, locality or PIN code — not just by shop
// name. All of that is handled server-side; this screen sends the text and
// renders what comes back.
//
// Everything here is measured from the SELECTED location, which comes from
// LocationProvider. Change the location and this screen re-searches.
// ─────────────────────────────────────────────────────────────────────────────

const Color _blue = Color(0xFF1565C0);
const Color _ink = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const Color _gold = Color(0xFFF4B400);

class ClaimitSearchScreen extends StatefulWidget {
  /// Opens already limited to one feature, for "see all" from a home section.
  final String? initialFeature;
  final String? initialQuery;

  const ClaimitSearchScreen({super.key, this.initialFeature, this.initialQuery});

  @override
  State<ClaimitSearchScreen> createState() => _ClaimitSearchScreenState();
}

class _ClaimitSearchScreenState extends State<ClaimitSearchScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  List<SearchCard> _cards = [];
  String? _feature;
  String _sort = 'relevance';
  bool _openNow = false;
  bool _hasReward = false;
  bool _hasDiscount = false;

  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String _message = '';
  double? _suggestRadius;
  int _hiddenUnknownHours = 0;
  bool _autoExpanded = false;
  double _radiusUsedKm = 5.0;

  @override
  void initState() {
    super.initState();
    _feature = widget.initialFeature;
    if (widget.initialQuery != null) _ctrl.text = widget.initialQuery!;
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run(reset: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loadingMore || !_hasMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 320) {
      _run();
    }
  }

  void _onTextChanged(String _) {
    _debounce?.cancel();
    // Rebuild now so the clear (×) button appears as soon as there is text,
    // rather than only after the debounced search comes back.
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 450),
        () => _run(reset: true));
  }

  /// Run the search. [reset] starts a fresh first page; otherwise it appends
  /// the next page for infinite scroll.
  Future<void> _run({bool reset = false}) async {
    final loc = context.read<LocationProvider>();
    if (loc.lat == null || loc.lng == null) {
      setState(() {
        _cards = [];
        _message = 'Choose a location to search around.';
        _loading = false;
      });
      return;
    }

    if (reset) {
      setState(() {
        _loading = true;
        _page = 1;
        _suggestRadius = null;
        _message = '';
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final res = await ClaimitSearchService.instance.search(
      lat: loc.lat!,
      lng: loc.lng!,
      radiusKm: loc.radiusKm,
      query: _ctrl.text,
      feature: _feature,
      openNow: _openNow,
      hasReward: _hasReward,
      hasDiscount: _hasDiscount,
      sort: _sort,
      page: reset ? 1 : _page + 1,
    );
    if (!mounted) return;

    setState(() {
      if (reset) {
        _cards = res.results;
        _page = 1;
      } else {
        _cards = [..._cards, ...res.results];
        _page += 1;
      }
      _hasMore = res.hasMore;
      _message = res.message;
      _suggestRadius = res.suggestRadiusKm;
      _hiddenUnknownHours = res.hiddenUnknownHours;
      _autoExpanded = res.autoExpanded;
      _radiusUsedKm = res.radiusUsedKm;
      _loading = false;
      _loadingMore = false;
    });
  }

  Future<void> _expandRadius() async {
    final loc = context.read<LocationProvider>();
    await loc.expandRadius();
    if (mounted) _run(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    // Watching the provider is what makes "changing the location refreshes
    // the app" true for this screen.
    final loc = context.watch<LocationProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _blue, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Search Claimit',
              maxLines: 1,
              style: TextStyle(
                  color: _blue, fontWeight: FontWeight.w700, fontSize: 18)),
        ),
      ),
      body: Column(
        children: [
          _locationBar(loc),
          _searchField(),
          _featureChips(),
          _filterRow(),
          Expanded(child: _body(loc)),
        ],
      ),
    );
  }

  // ── The location this search is measured from ───────────────────────────
  // The brief asks for this to be unmistakable, so the user never confuses
  // where they are with where they are searching.
  Widget _locationBar(LocationProvider loc) => Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => context.push('/location/pick'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.place_rounded, size: 18, color: _gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc.headerText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _ink),
                      ),
                      if (loc.isSearchingElsewhere)
                        Text(
                          'You are in ${loc.gpsPlace!.display}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                    ],
                  ),
                ),
                const Text('Change',
                    style: TextStyle(
                        fontSize: 12.5, color: _blue, fontWeight: FontWeight.w700)),
                const Icon(Icons.chevron_right_rounded, size: 18, color: _blue),
              ],
            ),
          ),
        ),
      );

  Widget _searchField() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: TextField(
          controller: _ctrl,
          onChanged: _onTextChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _run(reset: true),
          decoration: InputDecoration(
            hintText: 'Shop, category, product, service, doctor, offer…',
            hintStyle: const TextStyle(color: _muted, fontSize: 13.5),
            prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 20),
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: _muted),
                    onPressed: () {
                      _ctrl.clear();
                      _run(reset: true);
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

  // ── Feature chips ────────────────────────────────────────────────────────
  Widget _featureChips() => SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            _chip(
              label: 'All',
              selected: _feature == null,
              onTap: () {
                setState(() => _feature = null);
                _run(reset: true);
              },
            ),
            ...ClaimitSearchService.defaultFeatures.map((f) => _chip(
                  label: f['label']!,
                  selected: _feature == f['key'],
                  onTap: () {
                    setState(() => _feature = f['key']);
                    _run(reset: true);
                  },
                )),
          ],
        ),
      );

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Material(
          color: selected ? _blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected ? _blue : const Color(0xFFE2E8F0)),
              ),
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _ink,
                ),
              ),
            ),
          ),
        ),
      );

  // ── Filters and sorting ──────────────────────────────────────────────────
  Widget _filterRow() => SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            _toggle('Open Now', _openNow, (v) => setState(() => _openNow = v)),
            _toggle('Rewards', _hasReward, (v) => setState(() => _hasReward = v)),
            _toggle('Discounts', _hasDiscount,
                (v) => setState(() => _hasDiscount = v)),
            _sortButton(),
          ],
        ),
      );

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Material(
          color: value ? const Color(0xFFFFF4D6) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              onChanged(!value);
              _run(reset: true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: value ? _gold : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(value ? Icons.check_rounded : Icons.add_rounded,
                      size: 14, color: value ? const Color(0xFF8A5A00) : _muted),
                  const SizedBox(width: 4),
                  Text(label,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: value ? const Color(0xFF8A5A00) : _ink)),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _sortButton() {
    final current = ClaimitSearchService.sortOptions
        .firstWhere((s) => s['key'] == _sort,
            orElse: () => ClaimitSearchService.sortOptions.first);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _pickSort,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_vert_rounded, size: 15, color: _blue),
                const SizedBox(width: 4),
                Text(current['label']!,
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pickSort() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Sort by',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 8),
              ...ClaimitSearchService.sortOptions.map((s) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(s['label']!,
                        style: const TextStyle(fontSize: 14, color: _ink)),
                    trailing: _sort == s['key']
                        ? const Icon(Icons.check_rounded, color: _blue, size: 20)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() => _sort = s['key']!);
                      _run(reset: true);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ── Results ──────────────────────────────────────────────────────────────
  Widget _body(LocationProvider loc) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }
    if (_cards.isEmpty) return _empty(loc);

    // When the server widened the radius by itself, that must be visible —
    // the customer asked for 5 km and these results are from 10 km.
    final banner = _autoExpanded ? 1 : 0;

    return RefreshIndicator(
      color: _blue,
      onRefresh: () => _run(reset: true),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: banner + _cards.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, rawIndex) {
          if (_autoExpanded && rawIndex == 0) return _expandedBanner(loc);
          final i = rawIndex - banner;
          if (i == _cards.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _blue))),
            );
          }
          return _card(_cards[i]);
        },
      ),
    );
  }

  /// "Nothing within 5 km — showing 10 km." The radius does get widened
  /// automatically, but the customer is always told, and can go back to a
  /// strict 5 km in one tap.
  Widget _expandedBanner(LocationProvider loc) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF4C430)),
        ),
        child: Row(
          children: [
            const Icon(Icons.zoom_out_map_rounded,
                size: 18, color: Color(0xFF8A5A00)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nothing within ${loc.radiusKm.toStringAsFixed(0)} km — '
                'showing results within ${_radiusUsedKm.toStringAsFixed(0)} km.',
                style: const TextStyle(
                    fontSize: 12.5, height: 1.3, color: Color(0xFF8A5A00)),
              ),
            ),
          ],
        ),
      );

  /// Nothing found even at the wider radius. Say so, then offer the only
  /// things left: a different location, or a different feature.
  Widget _empty(LocationProvider loc) => ListView(
        padding: const EdgeInsets.fromLTRB(28, 60, 28, 24),
        children: [
          Icon(Icons.search_off_rounded, size: 58, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(
            _message.isNotEmpty
                ? _message
                : 'No results found within '
                    '${loc.radiusKm.toStringAsFixed(0)} km of the selected location.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _muted, height: 1.4),
          ),
          // Open Now hid some results because those merchants never recorded
          // their opening hours. Say so, and offer the one-tap way out —
          // otherwise the screen just looks broken.
          if (_openNow && _hiddenUnknownHours > 0) ...[
            const SizedBox(height: 14),
            Text(
              '$_hiddenUnknownHours nearby ${_hiddenUnknownHours == 1 ? "listing has" : "listings have"} '
              'not listed their opening hours, so they are hidden by the '
              '"Open Now" filter.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: _muted, height: 1.4),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _openNow = false);
                  _run(reset: true);
                },
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: const Text('Show them anyway'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (_suggestRadius != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _expandRadius,
                icon: const Icon(Icons.zoom_out_map_rounded, size: 18),
                label: Text(
                    'Expand to ${_suggestRadius!.toStringAsFixed(0)} km'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/location/pick'),
              icon: const Icon(Icons.place_outlined, size: 18),
              label: const Text('Change location'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (_feature != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  setState(() => _feature = null);
                  _run(reset: true);
                },
                child: const Text('Search all of Claimit instead'),
              ),
            ),
          ],
        ],
      );

  /// One result card — the fields the brief's question 16 asks for.
  Widget _card(SearchCard c) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openCard(c),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9EEF5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: c.image.startsWith('http')
                          ? Image.network(c.image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _thumbFallback())
                          : _thumbFallback(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: _ink)),
                            ),
                            if (c.sponsored)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Sponsored',
                                    style: TextStyle(
                                        fontSize: 9, color: _muted)),
                              ),
                          ],
                        ),
                        if (c.benefit.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(c.benefit,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _blue)),
                        ],
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            // Both halves are Flexible so a long locality on a
                            // narrow phone, or a large system font, shrinks
                            // the text rather than overflowing the card.
                            if (c.distanceText.isNotEmpty) ...[
                              const Icon(Icons.near_me_rounded,
                                  size: 12, color: _muted),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(c.distanceText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11.5, color: _muted)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(c.locality,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11.5, color: _muted)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // A merchant in several features shows all its badges
                        // on this one card — never repeated rows. Open/Closed
                        // rides in the same Wrap so it can never overflow, and
                        // is omitted entirely when the hours aren't known
                        // rather than guessing.
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            if (c.isOpen != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: c.isOpen!
                                      ? const Color(0xFFE8F7EE)
                                      : const Color(0xFFFDECEC),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  c.isOpen! ? 'Open Now' : 'Closed',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: c.isOpen!
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ...c.featureLabels
                              .take(3)
                              .map((l) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF4FB),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(l,
                                        style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: _blue)),
                                  )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _thumbFallback() => Container(
        color: const Color(0xFFF1F5F9),
        alignment: Alignment.center,
        child: const Icon(Icons.storefront_rounded,
            color: Color(0xFFB6C2D3), size: 28),
      );

  /// Send the user to the right screen for whichever feature this card came
  /// from. Falls back to the search screen itself rather than a dead tap.
  void _openCard(SearchCard c) {
    final f = c.features.isNotEmpty ? c.features.first : '';
    switch (f) {
      case 'local_classifieds':
      case 'local_finder':
        context.push('/classified/ads');
        return;
      case 'claimit_select':
        context.push('/select');
        return;
      case 'promo_reelz':
        context.push('/reelz');
        return;
      case 'brand_deals':
        context.push('/brands');
        return;
      case 'nearby_deals':
        context.push('/nearby-deals');
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(c.name), duration: const Duration(seconds: 1)),
        );
    }
  }
}

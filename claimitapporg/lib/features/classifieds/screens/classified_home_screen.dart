import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/location_provider.dart';
import '../../../core/widgets/claimit_bottom_bar.dart';
import '../../home/screens/home_screen.dart';

import '../data/classified_categories.dart';
import '../models/classified_post.dart';
import '../services/classified_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Local Classifieds home. Categories grid (search + See All), a "Find anything
// you want" banner with Create Your Ad, and a Recent Classifieds list.
// ─────────────────────────────────────────────────────────────────────────────

const Color _blue = Color(0xFF1565C0);
const Color _ink = Color(0xFF1E293B);
const Color _muted = Color(0xFF64748B);
const Color _gold = Color(0xFFF4B400);
const Color _banner = Color(0xFFE8F0FE);

/// Display label for a stored classifieds `category` value.
String classifiedCategoryLabel(String value) {
  for (final c in localClassifiedCategories) {
    if (c.category == value) return c.name;
  }
  // An ad posted before the list was cut to five still needs a readable name
  // on its card, so fall back to the retired set rather than showing the raw
  // stored value.
  for (final c in classifiedLegacyCategories) {
    if (c.category == value) return c.name;
  }
  return value.isEmpty ? 'Classifieds' : value;
}

class ClassifiedHomeScreen extends StatefulWidget {
  const ClassifiedHomeScreen({super.key});

  @override
  State<ClassifiedHomeScreen> createState() => _ClassifiedHomeScreenState();
}

class _ClassifiedHomeScreenState extends State<ClassifiedHomeScreen> {
  List<ClassifiedPost> _recent = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await ClassifiedService.instance
        .fetchClassifieds(listingType: 'classified');
    if (mounted) setState(() { _recent = list; _loading = false; });
  }

  void _openAll() => context.push('/classified/list',
      extra: {'category': '', 'subcategory': '', 'title': 'All Classifieds'});

  /// Ads matching the search box. Scoped to Local Classifieds by construction:
  /// it filters the list this screen already loaded with
  /// `listingType: 'classified'`, so it can never return a Local Finder
  /// business or anything from the app-wide search.
  List<ClassifiedPost> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _recent;
    return _recent.where((b) {
      final hay = [
        b.title,
        b.description,
        b.category,
        b.subcategory,
        b.userName,
        b.area,
        b.address,
        classifiedCategoryLabel(b.category),
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  void _openCategory(ClassifiedTopCategory c) => context.push(
        '/classified/list',
        extra: {
          'category': c.category,
          'subcategory': c.subcategory,
          'title': c.name
        },
      );

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: Colors.white,
      // The same header Local Finder, Select and Privilege use.
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _blue, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/images/home_main_logo.png',
              height: 30,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('claimit',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: _blue)),
            ),
            const SizedBox(width: 8),
            Container(width: 1.5, height: 20, color: const Color(0xFFD7DEE8)),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Local Classifieds',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: _ink, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'My Ads',
            icon: const Icon(Icons.list_alt_rounded, color: _blue, size: 22),
            onPressed: () => context.push('/classified/mine'),
          ),
        ],
      ),
      // The dashboard's centre button, docked into the shared bar's notch.
      floatingActionButton:
          ClaimitCenterFab(onTap: () => showClaimitFeaturedZones(context)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const ClaimitBottomBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _locationField(),
            const SizedBox(height: 6),
            _searchField(),
            const SizedBox(height: 14),
            _homeGrid(),
            const SizedBox(height: 18),
            _latestHeader(),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator(color: _blue)))
            else if (visible.isEmpty)
              _query.trim().isEmpty ? _emptyRecent() : _emptySearch()
            else
              ...visible.map(_recentCard),
          ],
        ),
      ),
    );
  }

  // ── Location ──────────────────────────────────────────────────────────────
  // The app-wide selected location, identical to the other three features.
  Widget _locationField() {
    final label = context.select<LocationProvider, String>(
      (l) => l.selected?.display ?? 'Select location',
    );
    return InkWell(
      onTap: () => context.push('/location/pick'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD7DEE8)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded, size: 18, color: _blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, color: _ink, fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: _muted),
          ],
        ),
      ),
    );
  }

  // ── Search — Local Classifieds only ───────────────────────────────────────
  Widget _searchField() => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD7DEE8)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 19, color: _muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText:
                      'Search Buy & Sell, Jobs, Services, Property or Community',
                  hintStyle: TextStyle(fontSize: 12.5, color: _muted),
                ),
                style: const TextStyle(fontSize: 14, color: _ink),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
                child: const Icon(Icons.close_rounded, size: 18, color: _muted),
              ),
          ],
        ),
      );

  // ── Category row ──────────────────────────────────────────────────────────
  /// Icon + label, one column per category — the same grid the other three
  /// features draw. More categories are coming; this row renders whatever
  /// `localClassifiedHomeCategories` holds, so adding one is a data change
  /// here and nothing else.
  Widget _homeGrid() {
    final cats = localClassifiedHomeCategories;
    final iconSize = (MediaQuery.of(context).size.width / (cats.length + 1))
        .clamp(52.0, 80.0);
    return GridView.count(
      crossAxisCount: cats.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 18,
      crossAxisSpacing: 8,
      childAspectRatio: 0.80,
      children: cats
          .map((c) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openCategory(c),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    c.iconAsset != null
                        ? Image.asset(c.iconAsset!,
                            width: iconSize,
                            height: iconSize,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                _iconFallback(c, iconSize))
                        : _iconFallback(c, iconSize),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _ink)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  /// "Latest Ads" on the left, the POST button on the right, as in the design.
  Widget _latestHeader() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _openAll,
            child: const Text('Latest Ads',
                style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800, color: _blue)),
          ),
          GestureDetector(
            onTap: () => context.push('/classified/add'),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                const Text('POST',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _ink)),
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 30,
                  decoration:
                      const BoxDecoration(color: _gold, shape: BoxShape.circle),
                  child: const Icon(Icons.add_rounded,
                      size: 20, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _emptySearch() => Container(
        padding: const EdgeInsets.symmetric(vertical: 26),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 34, color: _muted),
            const SizedBox(height: 8),
            Text('No ad matches "${_query.trim()}"',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: _muted)),
          ],
        ),
      );

  Widget _iconFallback(ClassifiedTopCategory c, double size) => Container(
        width: size, height: size,
        decoration: const BoxDecoration(color: _banner, shape: BoxShape.circle),
        child: Icon(c.icon, size: size * 0.5, color: _blue),
      );

  // ── "Latest Ads" card ─────────────────────────────────────────────────────
  // Photo, headline, asking price, area and category. The old card showed the
  // seller's phone number where the price belongs, which told a browsing user
  // nothing about what was for sale or what it costs.
  Widget _recentCard(ClassifiedPost b) {
    final heading = b.title.isNotEmpty ? b.title : b.userName;
    final phone = b.whatsapp.isNotEmpty ? b.whatsapp : b.userPhone;
    final hasPrice = b.price > 0;
    final tag = b.subcategory.isNotEmpty
        ? b.subcategory
        : classifiedCategoryLabel(b.category);

    // The gap between cards is Padding on the OUTSIDE of the Material. As a
    // margin on the inner Container it would sit inside the Material, which
    // would then paint its white rounded background across the gap too.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/classified/detail', extra: b),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9EEF5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          // Photo left, then heading / description / "Call: …" with the
          // category chip sitting at the bottom right, exactly as the design
          // sheet draws it.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 96, height: 112, child: _thumb(b)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(heading,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: _blue,
                            height: 1.25)),
                    const SizedBox(height: 5),
                    // The ad's own words — what the design shows here. Three
                    // lines, then ellipsis; the detail page has the rest.
                    if (b.description.trim().isNotEmpty)
                      Text(b.description.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: _ink, height: 1.35)),
                    const SizedBox(height: 5),
                    // Last line of the block, with the chip beside it. A price
                    // replaces the number only when the seller gave one, so an
                    // ad with no price still shows a way to make contact
                    // rather than an empty row.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            hasPrice
                                ? '₹ ${_money(b.price)}'
                                : (phone.isNotEmpty
                                    ? 'Call: $phone'
                                    : 'Ask for price'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: hasPrice ? 15.5 : 13,
                              fontWeight:
                                  hasPrice ? FontWeight.w800 : FontWeight.w600,
                              color: hasPrice ? _blue : _ink,
                            ),
                          ),
                        ),
                        if (tag.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          // Bounded so a long subcategory shrinks the chip
                          // instead of squeezing the phone number off the row.
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 110),
                            child: _chip(tag),
                          ),
                        ],
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
  }

  /// "68000" → "68,000". Plain grouping, no currency symbol.
  static String _money(double v) {
    final s = v.abs().toStringAsFixed(0);
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF4FB), borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11, color: _blue, fontWeight: FontWeight.w600)),
      );

  Widget _thumb(ClassifiedPost b) {
    if (b.photos.isNotEmpty) {
      final raw = b.photos.first;
      // App posts store base64; bulk-imported rows may arrive as a URL.
      if (raw.startsWith('http')) {
        return Image.network(raw,
            fit: BoxFit.cover, errorBuilder: (_, __, ___) => _thumbFallback());
      }
      try {
        return Image.memory(base64Decode(raw),
            fit: BoxFit.cover, errorBuilder: (_, __, ___) => _thumbFallback());
      } catch (_) {
        // Not decodable — fall through to the placeholder.
      }
    }
    return _thumbFallback();
  }

  Widget _thumbFallback() => Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: const Icon(Icons.image_rounded, color: Color(0xFFB6C2D3), size: 30));

  Widget _emptyRecent() => Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text('No classifieds yet. Be the first to post!',
            style: TextStyle(color: _muted)),
      );
}

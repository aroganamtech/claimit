import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  List<ClassifiedTopCategory> get _filteredCats {
    if (_query.trim().isEmpty) return localClassifiedCategories;
    final q = _query.toLowerCase();
    return localClassifiedCategories
        .where((c) => c.name.toLowerCase().contains(q))
        .toList();
  }

  void _openAll() => context.push('/classified/list',
      extra: {'category': '', 'subcategory': '', 'title': 'All Classifieds'});

  @override
  Widget build(BuildContext context) {
    final cats = _filteredCats;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _blue, size: 20),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        // Two labelled buttons leave the title roughly 130px on a small
        // phone, which "Local Classifieds" at 18pt doesn't fit into.
        // scaleDown shrinks it to fit instead of cutting it to "Local Clas…".
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Local Classifieds',
              maxLines: 1,
              style: TextStyle(
                  color: _blue, fontWeight: FontWeight.w700, fontSize: 18)),
        ),
        actions: [
          // Two solid tiles instead of bare outline icons. Gold is the
          // primary action (post an ad); blue is secondary (see your own
          // ads). Kept icon-sized rather than labelled pills so the row can
          // never overflow the app bar on a narrow phone.
          _appBarButton(
            tooltip: 'Post Ad',
            icon: Icons.add_rounded,
            bg: _gold,
            fg: Colors.black,
            onTap: () => context.push('/classified/add'),
          ),
          _appBarButton(
            tooltip: 'My Ads',
            icon: Icons.list_alt_rounded,
            bg: const Color(0xFFE8F0FE),
            fg: _blue,
            onTap: () => context.push('/classified/mine'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      // ── Posting an ad is the one thing people come here to do, so the call
      // to action now sits at the very top instead of below the whole page,
      // and a floating button keeps it reachable while the list scrolls.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/classified/add'),
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        elevation: 8,
        shape: const StadiumBorder(),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
        icon: const Icon(Icons.add_circle_rounded, size: 24),
        label: const Text('Post Your Ad',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15.5, letterSpacing: 0.2)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        // Bottom padding leaves room for the floating button so it never
        // covers the last card.
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            _findBanner(),
            const SizedBox(height: 22),
            // ── Ads first: the created classifieds with their details ──────────
            _sectionHeader('Latest Ads', _openAll),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: _blue)))
            else if (_recent.isEmpty)
              _emptyRecent()
            else
              ..._recent.map(_recentCard),
            const SizedBox(height: 22),
            // ── Browse by category ─────────────────────────────────────────────
            _sectionHeader('Categories', _openAll),
            const SizedBox(height: 12),
            _searchBar(),
            const SizedBox(height: 18),
            if (cats.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('No categories match your search.',
                    style: TextStyle(color: _muted))),
              )
            else
              _categoriesGrid(cats),
          ],
        ),
      ),
    );
  }

  /// A solid rounded tile for the app bar, with a label underneath so it's
  /// obvious what each one does rather than relying on the icon alone.
  Widget _appBarButton({
    required String tooltip,
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Container(
                width: 62,
                padding: const EdgeInsets.symmetric(vertical: 5),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: fg, size: 18),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(tooltip,
                          maxLines: 1,
                          style: TextStyle(
                              color: fg,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              height: 1.1)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _sectionHeader(String title, VoidCallback onSeeAll) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: _blue)),
          ),
          GestureDetector(
            onTap: onSeeAll,
            child: const Text('See All',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _blue)),
          ),
        ],
      );

  Widget _searchBar() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: _muted, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: "Search for stores, category's",
                  hintStyle: TextStyle(color: _muted, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
            // Icon(Icons.mic_none_rounded, color: _muted.withOpacity(0.7), size: 22),
          ],
        ),
      );

  Widget _categoriesGrid(List<ClassifiedTopCategory> cats) {
    final w = MediaQuery.of(context).size.width;
    final iconSize = (w / 5).clamp(56.0, 84.0);
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 18,
      crossAxisSpacing: 10,
      childAspectRatio: 0.86,
      children: cats.map((c) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/classified/list', extra: {
              'category': c.category,
              'subcategory': c.subcategory,
              'title': c.name,
            }),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                c.iconAsset != null
                    ? Image.asset(c.iconAsset!,
                        width: iconSize, height: iconSize, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _iconFallback(c, iconSize))
                    : _iconFallback(c, iconSize),
                const SizedBox(height: 6),
                Text(c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink)),
              ],
            ),
          )).toList(),
    );
  }

  Widget _iconFallback(ClassifiedTopCategory c, double size) => Container(
        width: size, height: size,
        decoration: const BoxDecoration(color: _banner, shape: BoxShape.circle),
        child: Icon(c.icon, size: size * 0.5, color: _blue),
      );

  Widget _findBanner() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _banner, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📢', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Find anything you want',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _blue)),
                      SizedBox(height: 4),
                      Text("Buy, Sell, Rent or Find — It's simple and secure.",
                          style: TextStyle(fontSize: 12.5, color: _muted, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/classified/add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('Create Your Ad',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    SizedBox(width: 8),
                    CircleAvatar(radius: 11, backgroundColor: _blue,
                        child: Icon(Icons.add, color: Colors.white, size: 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 96, height: 96, child: _thumb(b)),
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
                            color: _ink,
                            height: 1.25)),
                    const SizedBox(height: 5),
                    // Price when there is one. When there isn't, fall back to
                    // the contact number rather than an empty line — that's
                    // what this card showed before and it's still useful.
                    Text(
                      hasPrice
                          ? '₹ ${_money(b.price)}'
                          : (phone.isNotEmpty ? phone : 'Ask for price'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: hasPrice ? 15.5 : 13,
                        fontWeight: hasPrice ? FontWeight.w800 : FontWeight.w600,
                        color: hasPrice
                            ? _blue
                            : (phone.isNotEmpty ? _blue : _muted),
                      ),
                    ),
                    if (b.area.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 13, color: _muted),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(b.area,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: _muted)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (tag.isNotEmpty) _chip(tag),
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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/classified_categories.dart';
import '../models/classified_post.dart';
import '../services/classified_service.dart';
import 'classified_home_screen.dart' show classifiedCategoryLabel;

// ─────────────────────────────────────────────────────────────────────────────
// Local Classifieds — ADS LIST landing page. This is the screen the "Local
// Classifieds" tile in Featured Zones opens (route /classified/ads).
//
// Layout, top to bottom:
//   • app bar with two solid action buttons — gold "Post Ad", blue "My Ads"
//   • a category strip, so the categories are visible BEFORE posting
//   • the ads themselves, as cards
//   • a floating "Post Your Ad" button that stays put while the list scrolls
//
// Posting always begins by choosing a category — that is step 1 of the flow
// at /classified/add (see add_post_flow.dart).
// ─────────────────────────────────────────────────────────────────────────────

const Color _blue = Color(0xFF1565C0);
const Color _ink = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const Color _gold = Color(0xFFF4B400);
const Color _tint = Color(0xFFE8F0FE);

class ClassifiedAdsScreen extends StatefulWidget {
  const ClassifiedAdsScreen({super.key});

  @override
  State<ClassifiedAdsScreen> createState() => _ClassifiedAdsScreenState();
}

class _ClassifiedAdsScreenState extends State<ClassifiedAdsScreen> {
  List<ClassifiedPost> _ads = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ClassifiedService.instance
        .fetchClassifieds(listingType: 'classified');
    if (mounted) setState(() { _ads = list; _loading = false; });
  }

  void _openAdd() => context.push('/classified/add');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _blue, size: 20),
          onPressed: () => context.pop(),
        ),
        // Two labelled buttons leave the title around 130px on a small phone,
        // which this text at 18pt doesn't fit into — scaleDown shrinks it
        // rather than cutting it to "Local Clas…".
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Local Classifieds',
              maxLines: 1,
              style: TextStyle(
                  color: _blue, fontWeight: FontWeight.w700, fontSize: 18)),
        ),
        actions: [
          // Posting lives on the floating button only — one clear place to do
          // it, rather than the same action twice on one screen. This leaves
          // "My Ads" as the single app-bar button.
          _appBarButton(
            label: 'My Ads',
            icon: Icons.list_alt_rounded,
            bg: _tint,
            fg: _blue,
            onTap: () => context.push('/classified/mine'),
          ),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
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
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _blue))
            : ListView(
                // Bottom padding keeps the floating button clear of the last card.
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 96),
                children: [
                  _categoryStrip(),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text('Latest Ads',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _blue)),
                        const Spacer(),
                        if (_ads.isNotEmpty)
                          Text('${_ads.length}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _muted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_ads.isEmpty)
                    _empty()
                  else
                    ..._ads.map((a) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _adCard(a),
                        )),
                ],
              ),
      ),
    );
  }

  /// A solid rounded tile for the app bar — icon over a short label, so it is
  /// obvious what each button does without relying on the icon alone.
  Widget _appBarButton({
    required String label,
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: label,
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
                      child: Text(label,
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

  /// Categories, before the ads and before posting. Tapping one opens that
  /// category's list. Horizontal so all 12 are reachable without pushing the
  /// ads far down the page.
  Widget _categoryStrip() => SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: localClassifiedCategories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (_, i) {
            final c = localClassifiedCategories[i];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/classified/list', extra: {
                'category': c.category,
                'subcategory': c.subcategory,
                'title': c.name,
              }),
              child: SizedBox(
                width: 68,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    c.iconAsset != null
                        ? Image.asset(c.iconAsset!,
                            width: 56, height: 56, fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _catFallback(c))
                        : _catFallback(c),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(c.name,
                          maxLines: 1,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _ink)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

  Widget _catFallback(ClassifiedTopCategory c) => Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(color: _tint, shape: BoxShape.circle),
        child: Icon(c.icon, size: 28, color: _blue),
      );

  // ── Ad card ────────────────────────────────────────────────────────────────
  // Photo, headline, asking price, area and category. The old card put the
  // seller's phone number where the price belongs, which told someone browsing
  // nothing about what was for sale or what it costs.
  Widget _adCard(ClassifiedPost b) {
    final heading = b.title.isNotEmpty ? b.title : b.userName;
    final phone = b.whatsapp.isNotEmpty ? b.whatsapp : b.userPhone;
    final hasPrice = b.price > 0;
    final tag = b.subcategory.isNotEmpty
        ? b.subcategory
        : classifiedCategoryLabel(b.category);

    return Material(
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
                    // Price when there is one; otherwise the contact number,
                    // which is what this card showed before and is still useful.
                    Text(
                      hasPrice
                          ? '₹ ${_money(b.price)}'
                          : (phone.isNotEmpty ? phone : 'Ask for price'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: hasPrice ? 15.5 : 13,
                        fontWeight: hasPrice ? FontWeight.w800 : FontWeight.w600,
                        color: hasPrice ? _blue : (phone.isNotEmpty ? _blue : _muted),
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
      // App-posted ads store base64; bulk-uploaded ones arrive as an S3 URL.
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

  Widget _empty() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Column(
          children: [
            Icon(Icons.newspaper_rounded, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No classifieds yet.',
                style: TextStyle(color: _muted, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Tap "Post Your Ad" to post the first one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 13)),
          ],
        ),
      );
}

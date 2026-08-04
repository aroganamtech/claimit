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
        title: const Text('Local Classifieds',
            style: TextStyle(color: _blue, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'My Listings',
            icon: const Icon(Icons.list_alt_rounded, color: _blue),
            onPressed: () => context.push('/classified/mine'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _sectionHeader('Local Classifieds Categories', _openAll),
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
            const SizedBox(height: 20),
            _findBanner(),
            const SizedBox(height: 22),
            _sectionHeader('Recent Classifieds', _openAll),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: _blue)))
            else if (_recent.isEmpty)
              _emptyRecent()
            else
              ..._recent.take(10).map(_recentCard),
          ],
        ),
      ),
    );
  }

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
            Icon(Icons.mic_none_rounded, color: _muted.withOpacity(0.7), size: 22),
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

  Widget _recentCard(ClassifiedPost b) {
    final phone = b.whatsapp.isNotEmpty ? b.whatsapp : b.userPhone;
    return GestureDetector(
      onTap: () => context.push('/classified/detail', extra: b),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEF1F5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
              child: _thumb(b),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(b.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: _ink, height: 1.25)),
                    const SizedBox(height: 5),
                    if (phone.isNotEmpty)
                      Text(phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: _blue)),
                    const SizedBox(height: 8),
                    _chip(classifiedCategoryLabel(b.category)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF3F8), borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: const TextStyle(fontSize: 11.5, color: _ink, fontWeight: FontWeight.w500)),
      );

  Widget _thumb(ClassifiedPost b) {
    if (b.photos.isNotEmpty) {
      try {
        return Image.memory(base64Decode(b.photos.first),
            width: 104, height: 104, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _thumbFallback());
      } catch (_) {}
    }
    return _thumbFallback();
  }

  Widget _thumbFallback() => Container(
      width: 104, height: 104, color: const Color(0xFFEFF3F8),
      child: const Icon(Icons.image_rounded, color: _blue, size: 32));

  Widget _emptyRecent() => Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text('No classifieds yet. Be the first to post!',
            style: TextStyle(color: _muted)),
      );
}

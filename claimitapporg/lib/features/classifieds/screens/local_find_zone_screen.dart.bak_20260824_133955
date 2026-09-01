import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../data/classified_categories.dart';
import '../models/classified_post.dart';
import '../services/classified_service.dart';
import 'local_finds_screen.dart'
    show
        lfCall,
        lfNavigate,
        lfCurrentPosition,
        lfDistanceLabel,
        kLfBlue,
        kLfInk,
        kLfMuted;

// ─────────────────────────────────────────────────────────────────────────────
// Local Finds — business listing for one category (mockup 3). Header with a
// Filter pill + search + "+", filter chips (All + sub-categories), an "X Found"
// count, and business cards (image, name, location, distance/category chips,
// Call + Direction, favourite heart). Kept as LocalFindZoneScreen(zone:).
// ─────────────────────────────────────────────────────────────────────────────

class LocalFindZoneScreen extends StatefulWidget {
  final LocalFindZone zone;
  const LocalFindZoneScreen({super.key, required this.zone});

  @override
  State<LocalFindZoneScreen> createState() => _LocalFindZoneScreenState();
}

class _LocalFindZoneScreenState extends State<LocalFindZoneScreen> {
  List<ClassifiedPost> _all = [];
  bool _loading = true;
  String _filter = 'All';
  Position? _me;
  final Set<String> _liked = {};

  bool _searchOpen = false;
  final _searchCtrl = TextEditingController();
  String _search = '';

  List<String> get _chips =>
      ['All', ...widget.zone.subcategories.map((s) => s.name)];

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
    final results = await Future.wait([
      ClassifiedService.instance
          .fetchClassifieds(listingType: 'local_find', category: widget.zone.label),
      lfCurrentPosition(),
    ]);
    if (!mounted) return;
    setState(() {
      _all = results[0] as List<ClassifiedPost>;
      _me = results[1] as Position?;
      _loading = false;
    });
  }

  List<ClassifiedPost> get _visible {
    var list = _all;
    if (_filter != 'All') {
      list = list
          .where((b) => b.subcategory.toLowerCase() == _filter.toLowerCase())
          .toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((b) {
        final name = b.businessName.isNotEmpty ? b.businessName : b.title;
        return name.toLowerCase().contains(q) ||
            b.address.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('Filter by category',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kLfInk)),
            ),
            ..._chips.map((c) => ListTile(
                  title: Text(c),
                  trailing: _filter == c
                      ? const Icon(Icons.check_rounded, color: kLfBlue)
                      : null,
                  onTap: () {
                    setState(() => _filter = c);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kLfBlue, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.zone.label,
            style: const TextStyle(color: kLfBlue, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          // GestureDetector(
          //   onTap: _openFilterSheet,
          //   child: Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          //     decoration: BoxDecoration(
          //       borderRadius: BorderRadius.circular(20),
          //       border: Border.all(color: const Color(0xFFCBD5E1)),
          //     ),
          //     child: const Row(mainAxisSize: MainAxisSize.min, children: [
          //       Icon(Icons.tune_rounded, size: 15, color: kLfInk),
          //       SizedBox(width: 4),
          //       Text('Filter', style: TextStyle(fontSize: 13, color: kLfInk)),
          //     ]),
          //   ),
          // ),
          IconButton(
            icon: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded, color: kLfBlue),
            onPressed: () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) {
                _searchCtrl.clear();
                _search = '';
              }
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 2),
            child: GestureDetector(
              onTap: () => context.push('/local-finds/add', extra: widget.zone),
              child: Container(
                width: 34, height: 34,
                decoration: const BoxDecoration(color: kLfBlue, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(children: [
                  const Icon(Icons.search_rounded, color: kLfMuted, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: (v) => setState(() => _search = v),
                      decoration: const InputDecoration(
                        hintText: 'Search businesses',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          // Filter chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: _chips.map((c) {
                final active = _filter == c;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = c),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: active ? kLfBlue : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? kLfBlue : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(c,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: active ? Colors.white : kLfInk)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${visible.length} Found',
                    style: const TextStyle(color: kLfMuted, fontSize: 13)),
                GestureDetector(
                  onTap: _openFilterSheet,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.tune_rounded, size: 16, color: kLfInk),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kLfBlue))
                : visible.isEmpty
                    ? Center(
                        child: Text('No ${widget.zone.label.toLowerCase()} businesses yet.',
                            style: const TextStyle(color: kLfMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: visible.length,
                        itemBuilder: (_, i) => _card(context, visible[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, ClassifiedPost b) {
    final name = b.businessName.isNotEmpty ? b.businessName : b.title;
    final id = b.id.isNotEmpty ? b.id : name;
    final liked = _liked.contains(id);
    final phone = b.whatsapp.isNotEmpty ? b.whatsapp : b.userPhone;
    final dist = lfDistanceLabel(_me, b.latitude, b.longitude);
    final cat = b.subcategory.isNotEmpty ? b.subcategory : b.category;
    return GestureDetector(
      onTap: () => context.push('/classified/detail', extra: b),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: _thumb(b)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700, color: kLfInk)),
                      ),
                      GestureDetector(
                        onTap: () => setState(() =>
                            liked ? _liked.remove(id) : _liked.add(id)),
                        child: Icon(
                            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 19, color: liked ? Colors.redAccent : kLfBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                      b.address.isNotEmpty
                          ? b.address
                          : (b.area.isNotEmpty ? b.area : cat),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: kLfMuted)),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (dist != null) _chip(dist, accent: true),
                      _chip(cat),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(children: [
                    _act(Icons.call_rounded, 'Call', () => lfCall(phone)),
                    const SizedBox(width: 22),
                    _act(Icons.navigation_rounded, 'Direction',
                        () => lfNavigate(b.address, lat: b.latitude, lng: b.longitude)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, {bool accent = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: accent ? const Color(0xFFE3EEFC) : const Color(0xFFEFF3F8),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                color: accent ? kLfBlue : kLfInk,
                fontWeight: FontWeight.w500)),
      );

  Widget _thumb(ClassifiedPost b) {
    if (b.photos.isNotEmpty) {
      try {
        return Image.memory(base64Decode(b.photos.first),
            width: 90, height: 90, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fb());
      } catch (_) {}
    }
    return _fb();
  }

  Widget _fb() => Container(
      width: 90, height: 90, color: const Color(0xFFEFF3F8),
      child: const Icon(Icons.storefront_rounded, color: kLfBlue));

  Widget _act(IconData icon, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: kLfBlue),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(fontSize: 12.5, color: kLfBlue, fontWeight: FontWeight.w600)),
        ]),
      );
}

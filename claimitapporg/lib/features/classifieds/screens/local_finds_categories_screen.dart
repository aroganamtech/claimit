import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/classified_categories.dart';
import 'local_finds_screen.dart'
    show LfCategoriesGrid, LfDiscoverBanner, kLfBlue, kLfMuted;

// ─────────────────────────────────────────────────────────────────────────────
// Local Finds — Categories screen (mockup 2). Search bar, a 3-column grid of
// all 12 categories, and the Discover banner beneath. Reached from the home
// "See All" links and routed at /local-finds/categories.
// ─────────────────────────────────────────────────────────────────────────────

class LocalFindsCategoriesScreen extends StatefulWidget {
  const LocalFindsCategoriesScreen({super.key});

  @override
  State<LocalFindsCategoriesScreen> createState() =>
      _LocalFindsCategoriesScreenState();
}

class _LocalFindsCategoriesScreenState
    extends State<LocalFindsCategoriesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<LocalFindZone> get _filtered {
    if (_query.trim().isEmpty) return localFindZones;
    final q = _query.toLowerCase();
    return localFindZones.where((z) {
      if (z.label.toLowerCase().contains(q)) return true;
      return z.subcategories.any((s) => s.name.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final zones = _filtered;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kLfBlue, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Local Finds Categories',
            style: TextStyle(color: kLfBlue, fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => context.push('/local-finds/add'),
              child: Container(
                width: 34, height: 34,
                decoration: const BoxDecoration(color: kLfBlue, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: kLfMuted, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: "Search for stores, category's",
                      hintStyle: TextStyle(color: kLfMuted, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                Icon(Icons.mic_none_rounded, color: kLfMuted.withOpacity(0.7), size: 22),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (zones.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                  child: Text('No categories match your search.',
                      style: TextStyle(color: kLfMuted))),
            )
          else
            LfCategoriesGrid(
              columns: 3,
              zones: zones,
              onTap: (z) => context.push('/classified/zone', extra: z),
            ),
          const SizedBox(height: 22),
          LfDiscoverBanner(onRegister: () => context.push('/local-finds/add')),
        ],
      ),
    );
  }
}

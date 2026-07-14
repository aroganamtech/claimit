import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/classified_categories.dart';

const Color _navy = Color(0xFF1E3A5F);
const Color _gold = Color(0xFFC9A876);

class ClassifiedHomeScreen extends StatefulWidget {
  const ClassifiedHomeScreen({super.key});

  @override
  State<ClassifiedHomeScreen> createState() => _ClassifiedHomeScreenState();
}

class _ClassifiedHomeScreenState extends State<ClassifiedHomeScreen> {
  // "Local Helpers" tab removed — this screen now only shows Local Classified.
  List<ClassifiedTopCategory> get _items => localClassifiedCategories;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _navy, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'LOCAL CLASSIFIEDS',
          style: TextStyle(
            color: _navy,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'My Listings',
            icon: const Icon(Icons.list_alt_rounded, color: _navy),
            onPressed: () => context.push('/classified/mine'),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: _navy),
            onPressed: () => context.push(
              '/classified/list',
              extra: {'category': '', 'subcategory': '', 'title': 'All Classifieds'},
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFDCE7F5),
              Color(0xFFE9E4EF),
              Color(0xFFF3E3EA),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: kToolbarHeight + 16),
              // ── Category grid ──────────────────────────────────────────────
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    return _TopCategoryBox(
                      item: item,
                      onTap: () => context.push(
                        '/classified/list',
                        extra: {
                          'category': item.category,
                          'subcategory': item.subcategory,
                          'title': item.name,
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category tile — circular icon + label, matching the Local Finds screen design
// ─────────────────────────────────────────────────────────────────────────────

class _TopCategoryBox extends StatelessWidget {
  const _TopCategoryBox({required this.item, required this.onTap});
  final ClassifiedTopCategory item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // PDF-cropped icon art (peach circle already baked in) — falls
          // back to the old gold-bordered Material icon if ever missing.
          item.iconAsset != null
              ? Image.asset(item.iconAsset!, width: 72, height: 72)
              : Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.55),
                    border: Border.all(color: _gold, width: 1.4),
                  ),
                  child: Icon(item.icon, size: 30, color: _navy),
                ),
          const SizedBox(height: 8),
          Text(
            item.name.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.playfairDisplay(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _navy,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

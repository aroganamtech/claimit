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
  // 0 = Local Classified, 1 = Local Helpers
  int _tab = 0;

  List<ClassifiedTopCategory> get _items =>
      _tab == 0 ? localClassifiedCategories : localHelperCategories;

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
        title: Text(
          'LOCAL CLASSIFIEDS',
          style: GoogleFonts.playfairDisplay(
            color: _navy,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.6,
          ),
        ),
        centerTitle: true,
        actions: [
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
              const SizedBox(height: kToolbarHeight + 8),
              // ── Local Classified / Local Helpers toggle ───────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _ClassifiedTabToggle(
                  selected: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),

              // ── Category grid ──────────────────────────────────────────────
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
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
// Local Classified / Local Helpers pill toggle
// ─────────────────────────────────────────────────────────────────────────────

class _ClassifiedTabToggle extends StatelessWidget {
  const _ClassifiedTabToggle({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleSegment(
            label: 'Local Classified',
            active: selected == 0,
            onTap: () => onChanged(0),
          ),
          _ToggleSegment(
            label: 'Local Helpers',
            active: selected == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _navy : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : _navy.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flat grid box — icon + label inside a single outlined card
// ─────────────────────────────────────────────────────────────────────────────

class _TopCategoryBox extends StatelessWidget {
  const _TopCategoryBox({required this.item, required this.onTap});
  final ClassifiedTopCategory item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _gold.withOpacity(0.8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 30, color: _navy),
            const SizedBox(height: 8),
            Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _navy,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

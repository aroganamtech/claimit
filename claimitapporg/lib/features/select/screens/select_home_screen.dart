import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/select_category.dart';
import '../widgets/select_common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Claimit Select — home.
//
// Yellow branded header (wordmark + bell + location + search) over a 3-column
// grid of the 12 professional categories. Tapping a category opens the
// professionals list for it.
//
// Every text element here is overflow-guarded (Flexible/Expanded + maxLines +
// ellipsis, FittedBox on the wordmark) so a long location name or a large
// system font size can't produce a RenderFlex overflow.
// ─────────────────────────────────────────────────────────────────────────────

class SelectHomeScreen extends StatefulWidget {
  const SelectHomeScreen({super.key});

  @override
  State<SelectHomeScreen> createState() => _SelectHomeScreenState();
}

class _SelectHomeScreenState extends State<SelectHomeScreen> {
  final _searchCtrl = TextEditingController();

  // Shown in the location chip. Static for now — the picker is a later step.
  static const String _location = 'Anna Nagar, Chennai';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Both entry points hand the list screen the same shaped map, so it never
  // has to guess what `extra` is.
  void _openCategory(SelectCategory c) {
    context.push('/select/list', extra: {'category': c});
  }

  void _submitSearch() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    // Search runs across all categories.
    context.push('/select/list', extra: {'search': q});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSelBg,
      bottomNavigationBar: const SelectBottomNav(current: 0),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                child: _categoryGrid(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Yellow branded header ───────────────────────────────────────────────────
  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD233), kSelYellow],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wordmark + back + bell
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: kSelOnYellow),
                ),
              ),
              // The app's own logo (home_main_logo.png already contains the
              // icon + "claimit" wordmark — the same asset the home and
              // dashboard headers use), with the "Select" sub-brand beside it.
              // FittedBox keeps the pair on one line at any font scale.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/home_main_logo.png',
                        height: 30,
                        fit: BoxFit.contain,
                        // Same fallback convention as the dashboard header.
                        errorBuilder: (_, __, ___) => const Text(
                          'claimit',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: kSelOnYellow,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Select',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: kSelOnYellow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.notifications_none_rounded,
                  size: 24, color: kSelOnYellow),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Trusted professionals near you',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3A2E00),
            ),
          ),
          const SizedBox(height: 12),

          // Location chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            // Not a const Row: ConstrainedBox has no const constructor (it
            // asserts on its constraints), so the children are marked const
            // individually instead.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 15, color: Color(0xFFE53935)),
                const SizedBox(width: 5),
                // Constrained so a long area name ellipsises instead of
                // overflowing the chip.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: const Text(
                    _location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: kSelInk,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: kSelInk),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submitSearch(),
              decoration: const InputDecoration(
                hintText: 'Search professionals or services',
                hintStyle: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Category grid ───────────────────────────────────────────────────────────
  Widget _categoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kSelectCategories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        // Fixed height rather than childAspectRatio: an aspect ratio scales
        // the cell height with its width, which left a lot of empty space in
        // each tile on wider screens. 112px fits the 46px icon + a 2-line
        // label like "5. Interior Designers" on every screen size.
        mainAxisExtent: 112,
      ),
      itemBuilder: (_, i) => _CategoryTile(
        index: i + 1,
        category: kSelectCategories[i],
        onTap: () => _openCategory(kSelectCategories[i]),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.index,
    required this.category,
    required this.onTap,
  });

  final int index;
  final SelectCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(category.icon, size: 26, color: category.color),
            ),
            const SizedBox(height: 8),
            // Flexible + 2 lines + ellipsis: the long names ("Interior
            // Designers", "Financial Advisors") wrap neatly and can never
            // overflow the tile.
            Flexible(
              child: Text(
                '$index. ${category.label}',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: kSelInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

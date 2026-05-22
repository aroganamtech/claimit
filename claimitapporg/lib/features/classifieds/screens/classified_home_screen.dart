import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/classified_categories.dart';

class ClassifiedHomeScreen extends StatelessWidget {
  const ClassifiedHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E40AF), size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Classified',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded,
                color: Color(0xFF1E40AF)),
            onPressed: () => context.push(
              '/classified/list',
              extra: {'category': '', 'subcategory': '', 'title': 'All Classifieds'},
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ── Explore header ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Explore Local Services & Classifieds',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── ADD card ────────────────────────────────────────────
                  GestureDetector(
                    onTap: () => context.push('/classified/add'),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'ADD',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LOCAL CLASSIFIED POSTINGS',
                                  style: TextStyle(
                                    color: Color(0xFF1E40AF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Post your local requirements.',
                                  style: TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFF2563EB)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── OR divider ──────────────────────────────────────────
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Local Helpers heading ───────────────────────────────
                  const Text(
                    'Local Helpers',
                    style: TextStyle(
                      color: Color(0xFF1E40AF),
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Find trusted local service providers near your location.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Category sections ────────────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _CategorySection(
                category: classifiedCategories[index],
              ),
              childCount: classifiedCategories.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One category row (header + horizontal scroll of subcategory icons)
// ─────────────────────────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category});
  final ClassifiedCategory category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              category.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 108,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: category.subcategories.length,
              itemBuilder: (context, i) {
                final sub = category.subcategories[i];
                return _SubcategoryIcon(
                  subcategory: sub,
                  onTap: () => context.push(
                    '/classified/list',
                    extra: {
                      'category': category.id,
                      'subcategory': sub.name,
                      'title': sub.name,
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual subcategory icon circle + label
// ─────────────────────────────────────────────────────────────────────────────

class _SubcategoryIcon extends StatelessWidget {
  const _SubcategoryIcon({required this.subcategory, required this.onTap});
  final ClassifiedSubcategory subcategory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
              ),
              child: Icon(subcategory.icon,
                  size: 30, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 32,
              child: Text(
                subcategory.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF334155),
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

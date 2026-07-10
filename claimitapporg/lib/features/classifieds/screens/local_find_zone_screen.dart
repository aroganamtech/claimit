import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/classified_categories.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shows the subcategories inside one Local Finds zone (e.g. "Shop" →
// Grocery, Supermarkets, Fashion, ...). Tapping a subcategory opens the same
// browse + "add post" list screen already used by Local Classified, so
// posting a new listing here works exactly the same way.
// ─────────────────────────────────────────────────────────────────────────────

const Color _navy = Color(0xFF1E3A5F);
const Color _gold = Color(0xFFC9A876);

class LocalFindZoneScreen extends StatelessWidget {
  final LocalFindZone zone;
  const LocalFindZoneScreen({super.key, required this.zone});

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
          zone.label.toUpperCase(),
          style: const TextStyle(
            color: _navy,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
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
          child: zone.subcategories.isEmpty
              ? Center(
                  child: Text(
                    '${zone.label} sub-categories coming soon',
                    style: const TextStyle(color: _navy),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 24, 20, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: zone.subcategories.length,
                  itemBuilder: (context, i) {
                    final sub = zone.subcategories[i];
                    return _ZoneSubcategoryTile(
                      sub: sub,
                      onTap: () => context.push(
                        '/classified/list',
                        extra: {
                          'category': zone.id,
                          'subcategory': sub.name,
                          'title': sub.name,
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _ZoneSubcategoryTile extends StatelessWidget {
  const _ZoneSubcategoryTile({required this.sub, required this.onTap});
  final ClassifiedSubcategory sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.55),
              border: Border.all(color: _gold, width: 1.4),
            ),
            child: Icon(sub.icon, size: 30, color: _navy),
          ),
          const SizedBox(height: 8),
          Text(
            sub.name,
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
    );
  }
}

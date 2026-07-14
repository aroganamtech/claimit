import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/classified_categories.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shows the subcategories inside one Local Finds zone (e.g. "Shop" →
// Grocery, Supermarkets, Fashion, ...), styled to match the client's PDF:
// zone icon at top, subcategories as a plain text list (no icons), and a
// blue REGISTER banner at the bottom to list a business under this zone.
// Tapping a subcategory still opens the same browse + "add post" list
// screen already used by Local Classified, so posting a new listing here
// works exactly the same way.
// ─────────────────────────────────────────────────────────────────────────────

const Color _navy = Color(0xFF1E3A5F);
const Color _gold = Color(0xFFC9A876);
const Color _registerBlue = Color(0xFF1565C0);

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
        actions: [
          IconButton(
            tooltip: 'My Listings',
            icon: const Icon(Icons.list_alt_rounded, color: _navy),
            onPressed: () => context.push('/classified/mine'),
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
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, kToolbarHeight + 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Zone icon (PDF art) ─────────────────────────────────────
                zone.iconAsset != null
                    ? Image.asset(zone.iconAsset!, width: 92, height: 92)
                    : Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.55),
                          border: Border.all(color: _gold, width: 1.4),
                        ),
                        child: Icon(zone.icon, size: 38, color: _navy),
                      ),
                const SizedBox(height: 10),
                Text(
                  zone.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Plain text subcategory list — no icons, matches PDF ────
                if (zone.subcategories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      '${zone.label} sub-categories coming soon',
                      style: const TextStyle(color: _navy),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < zone.subcategories.length; i++)
                          _SubcategoryRow(
                            name: zone.subcategories[i].name,
                            showDivider: i != zone.subcategories.length - 1,
                            onTap: () => context.push(
                              '/classified/list',
                              extra: {
                                'category': zone.id,
                                'subcategory': zone.subcategories[i].name,
                                'title': zone.subcategories[i].name,
                                'listingType': 'local_find',
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // ── REGISTER banner — matches the PDF's blue full-width bar ─
                GestureDetector(
                  onTap: () => context.push('/local-finds/add', extra: zone),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _registerBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'REGISTER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubcategoryRow extends StatelessWidget {
  const _SubcategoryRow({
    required this.name,
    required this.showDivider,
    required this.onTap,
  });
  final String name;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: Color(0xFF9CA3AF)),
              ],
            ),
            if (showDivider) ...[
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0xFFE5E7EB)),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mock ad data  (replace with API data later)
// ─────────────────────────────────────────────────────────────────────────────

class _AdItem {
  final String imageUrl;
  final Color fallbackColor;
  final String brand;
  final String tag;
  const _AdItem({
    required this.imageUrl,
    required this.fallbackColor,
    required this.brand,
    required this.tag,
  });
}

const _ads = [
  _AdItem(
    imageUrl:
        'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&q=80',
    fallbackColor: Color(0xFF1A1A2E),
    brand: 'OREO',
    tag: 'AD|Y|TUDE',
  ),
  _AdItem(
    imageUrl:
        'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=800&q=80',
    fallbackColor: Color(0xFFE53935),
    brand: 'SATHYA',
    tag: 'SPREADING HAPPINESS',
  ),
  _AdItem(
    imageUrl:
        'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=800&q=80',
    fallbackColor: Color(0xFFF06292),
    brand: 'SATHYA',
    tag: 'MARLIA ADS',
  ),
  _AdItem(
    imageUrl:
        'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800&q=80',
    fallbackColor: Color(0xFF1A1A2E),
    brand: 'OREO',
    tag: 'AD|Y|TUDE',
  ),
  _AdItem(
    imageUrl:
        'https://images.unsplash.com/photo-1560869713-7d0a29430803?w=800&q=80',
    fallbackColor: Color(0xFF4CAF50),
    brand: 'FRESH MART',
    tag: 'FRESH DEALS',
  ),
  _AdItem(
    imageUrl:
        'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&q=80',
    fallbackColor: Color(0xFF1565C0),
    brand: 'FITZONE',
    tag: 'STAY FIT',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class NationalAdsScreen extends StatefulWidget {
  const NationalAdsScreen({super.key});

  @override
  State<NationalAdsScreen> createState() => _NationalAdsScreenState();
}

class _NationalAdsScreenState extends State<NationalAdsScreen> {
  String _query = '';
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_AdItem> get _filtered => _query.isEmpty
      ? _ads
      : _ads
          .where((a) =>
              a.brand.toLowerCase().contains(_query.toLowerCase()) ||
              a.tag.toLowerCase().contains(_query.toLowerCase()))
          .toList();

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),

                  // Title
                  if (!_showSearch)
                    const Expanded(
                      child: Text(
                        "National Ad's",
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search ads…',
                          hintStyle:
                              const TextStyle(color: Color(0xFF9CA3AF)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF111827),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),

                  // Filter button
                  if (!_showSearch)
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD1D5DB)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.tune_rounded,
                                size: 15, color: Color(0xFF374151)),
                            SizedBox(width: 5),
                            Text(
                              'Filter',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Search button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_showSearch) {
                          _showSearch = false;
                          _query = '';
                          _searchCtrl.clear();
                        } else {
                          _showSearch = true;
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _showSearch
                            ? Icons.close_rounded
                            : Icons.search_rounded,
                        color: const Color(0xFF374151),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: items.isEmpty
          ? const Center(
              child: Text(
                'No ads found',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (ctx, i) => _AdCard(ad: items[i]),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ad card  (full-width thumbnail)
// ─────────────────────────────────────────────────────────────────────────────

class _AdCard extends StatelessWidget {
  final _AdItem ad;
  const _AdCard({required this.ad});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child:AspectRatio(
  aspectRatio: 16 / 9,
  child: SizedBox(
    width: double.infinity,
    child: CachedNetworkImage(
      imageUrl: ad.imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: ad.fallbackColor,
        child: Center(
          child: Text(
            ad.brand,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: ad.fallbackColor,
        child: Center(
          child: Text(
            ad.brand,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    ),
  ),
),
      ),
    );
  }
}

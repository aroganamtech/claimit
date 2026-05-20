import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/shop_category.dart';
import '../../../shared/widgets/shop_filter_sheet.dart';
import '../services/shop_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ShopItem data model — now driven by real API data from MongoDB.
// Images are stored as base64 strings in the DB and decoded here.
// ─────────────────────────────────────────────────────────────────────────────

class ShopItem {
  /// MongoDB ObjectId as String
  final String id;
  final String name;
  final String location;

  /// Category IDs this shop belongs to (matches ShopCategory.id values)
  final List<int> categoryIds;

  final int discount; // percentage
  final double rating;
  final int addedDaysAgo;

  /// Base64-encoded image bytes from MongoDB.
  /// Render with: Image.memory(base64Decode(imageData!))
  final String? imageData;

  /// Filename reference, e.g. "img1.jpg"
  final String imageName;

  /// Resolved client-side from categoryIds for fallback display
  final Color fallbackColor;
  final IconData fallbackIcon;

  final bool hasRewards;
  final bool hasRedeem;

  final String address;
  final String timing;
  final String phone;

  /// Distance from user — provided by backend, e.g. "6 km"
  final String distance;

  const ShopItem({
    required this.id,
    required this.name,
    required this.location,
    required this.categoryIds,
    required this.discount,
    required this.rating,
    required this.addedDaysAgo,
    required this.fallbackColor,
    required this.fallbackIcon,
    this.imageData,
    this.imageName = '',
    this.hasRewards = true,
    this.hasRedeem = true,
    this.address = '',
    this.timing = '',
    this.phone = '',
    this.distance = '',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Category ID → display name helper
// ─────────────────────────────────────────────────────────────────────────────

const Map<int, String> _kCatNames = {
  1: 'New Deals',    2: 'Groceries',   3: 'Supermarket',  4: 'Pharmacy',
  5: 'Salon',        6: 'Gym',         7: 'Restaurant',   8: 'Cafes',
  9: 'Clothing',    10: 'Department', 11: 'Electronics', 12: 'Books',
 13: 'Toys',        14: 'Baby',       15: 'Home Decor',  16: 'Furniture',
 17: 'Spa',         18: 'Schools',    19: 'Colleges',    20: 'Tutoring',
 21: 'Clinics',     22: 'Hospitals',  23: 'Pets',        24: 'Sports',
 25: 'Travel',      26: 'Mobile',     27: 'Computers',   28: 'Gifts',
 29: 'Jewellery',   30: 'Shoes',
};

String _catName(List<int> ids) =>
    ids.isEmpty ? '' : (_kCatNames[ids.first] ?? '');


// ─────────────────────────────────────────────────────────────────────────────
// Category ID reference (matches ShopCategory.id values):
//   1=New deals  2=Groceries  3=Supermarket  4=Pharmacy  5=Salon
//   6=Gym  7=Restaurant  8=Cafes  9=Clothing  10=Department
//  11=Electronics  12=Books  13=Toys  14=Baby  15=Home Decor
//  16=Furniture  17=Spa  18=Schools  19=Colleges  20=Tutoring
//  21=Clinics  22=Hospitals  23=Pets  24=Sports  25=Travel
//  26=Mobile & Accessories  27=Computer & Laptop
//  28=Gifts  29=Jewellery  30=Shoes
// ─────────────────────────────────────────────────────────────────────────────

// FilterCat, filterCats — imported from shared/widgets/shop_filter_sheet.dart

// ─────────────────────────────────────────────────────────────────────────────
// Public accessor — now returns empty; use ShopService for real data
// ─────────────────────────────────────────────────────────────────────────────

List<ShopItem> getShopDatabase() => const [];


// ─────────────────────────────────────────────────────────────────────────────
// ShopListScreen
// ─────────────────────────────────────────────────────────────────────────────

class ShopListScreen extends StatefulWidget {
  final ShopCategory category;
  const ShopListScreen({super.key, required this.category});

  @override
  State<ShopListScreen> createState() => _ShopListScreenState();
}

class _ShopListScreenState extends State<ShopListScreen> {
  late bool _isRewards;

  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Applied filters
  String? _sort;         // 'recently_added' | '30_disc' | '50_above' | '20_disc' | '10_disc' | 'last_7_days'
  int? _filterCatId;
  double? _minRating;
  String? _priceSort;    // 'high_to_low' | 'low_to_high'

  // API-loaded shop data
  List<ShopItem> _shops = [];
  bool _isLoading = true;
  String? _loadError;

  final Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    // id=-1 → opened as "Redeem Zone" → default to Redeem tab
    _isRewards = widget.category.id != -1;
    _loadShops();
  }

  Future<void> _loadShops() async {
    setState(() { _isLoading = true; _loadError = null; });
    try {
      final shops = await ShopService.instance.fetchAllShops();
      if (mounted) setState(() { _shops = shops; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString(); _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ShopItem> get _filteredShops {
    // id == 0  → "Reward / Redeem Zone" all-categories mode (no category filter)
    // Otherwise the filter sheet category overrides the screen's base category.
    final baseCatId = _filterCatId ?? widget.category.id;

    // id 0 = Reward Zone, id -1 = Redeem Zone → show all shops, no category filter
    var shops = (baseCatId == 0 || baseCatId == -1)
        ? _shops.toList()
        : _shops.where((s) => s.categoryIds.contains(baseCatId)).toList();

    // Rewards / Redeem tab
    if (_isRewards) {
      shops = shops.where((s) => s.hasRewards).toList();
    } else {
      shops = shops.where((s) => s.hasRedeem).toList();
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      shops = shops
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              s.location.toLowerCase().contains(q))
          .toList();
    }

    // Sort / discount chips
    if (_sort == 'recently_added') {
      shops = [...shops]..sort((a, b) => a.addedDaysAgo.compareTo(b.addedDaysAgo));
    } else if (_sort == '30_disc') {
      shops = shops.where((s) => s.discount == 30).toList();
    } else if (_sort == '50_above') {
      shops = shops.where((s) => s.discount >= 50).toList();
    } else if (_sort == '20_disc') {
      shops = shops.where((s) => s.discount == 20).toList();
    } else if (_sort == '10_disc') {
      shops = shops.where((s) => s.discount == 10).toList();
    } else if (_sort == 'last_7_days') {
      shops = shops.where((s) => s.addedDaysAgo <= 7).toList();
    }

    // Minimum rating
    if (_minRating != null) {
      shops = shops.where((s) => s.rating >= _minRating!).toList();
    }

    // Price / discount sort
    if (_priceSort == 'high_to_low') {
      shops = [...shops]..sort((a, b) => b.discount.compareTo(a.discount));
    } else if (_priceSort == 'low_to_high') {
      shops = [...shops]..sort((a, b) => a.discount.compareTo(b.discount));
    }

    return shops;
  }

  /// Label shown in the AppBar — switches to the filter category's name
  /// when the user has selected a different category in the filter sheet.
  String get _activeTitle {
    if (_filterCatId != null && _filterCatId! > 0) {
      try {
        return filterCats
            .firstWhere((c) => c.id == _filterCatId)
            .label
            .replaceAll('\n', ' ');
      } catch (_) {}
    }
    return widget.category.name;
  }

  int get _filterCount {
    int c = 0;
    if (_sort != null) c++;
    if (_filterCatId != null) c++;
    if (_minRating != null) c++;
    if (_priceSort != null) c++;
    return c;
  }

  void _openFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShopFilterSheet(
        initialSort: _sort,
        initialCatId: _filterCatId,
        initialRating: _minRating,
        initialPrice: _priceSort,
        onApply: (sort, catId, rating, price) {
          setState(() {
            _sort = sort;
            _filterCatId = catId;
            _minRating = rating;
            _priceSort = price;
          });
        },
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF2563EB), size: 20),
        ),
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search $_activeTitle…',
                  hintStyle:
                      const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 16),
              )
            : Text(
                _activeTitle,
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          // Filter button
          GestureDetector(
            onTap: _openFilter,
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded,
                      size: 14, color: Color(0xFF374151)),
                  const SizedBox(width: 4),
                  const Text('Filter',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF374151))),
                  if (_filterCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$_filterCount',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Search toggle
          IconButton(
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
              color: const Color(0xFF1E3A8A),
              size: 24,
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
    );
  }

  // ── Rewards / Redeem tab ──────────────────────────────────────────────────
  Widget _buildTabToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            _TabBtn(
                label: 'Rewards',
                active: _isRewards,
                onTap: () => setState(() => _isRewards = true)),
            _TabBtn(
                label: 'Redeem',
                active: !_isRewards,
                onTap: () => setState(() => _isRewards = false)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shops = _filteredShops;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Hide tab toggle in Reward Zone (id=0) and Redeem Zone (id=-1)
          // — those zones already lock to one type via _isRewards.
          if (widget.category.id > 0) _buildTabToggle(),
          if (widget.category.id > 0)
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _loadError != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFFD1D5DB)),
                            const SizedBox(height: 12),
                            const Text('Could not load shops', style: TextStyle(fontSize: 15, color: Color(0xFF6B7280))),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _loadShops,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : shops.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _loadShops,
                            color: const Color(0xFF2563EB),
                            child: ListView.builder(
                              itemCount: shops.length,
                              padding: const EdgeInsets.only(top: 4, bottom: 16),
                              itemBuilder: (_, i) => _ShopCard(
                                shop: shops[i],
                                isFav: _favorites.contains(shops[i].id),
                                onToggleFav: () {
                                  setState(() {
                                    if (_favorites.contains(shops[i].id)) {
                                      _favorites.remove(shops[i].id);
                                    } else {
                                      _favorites.add(shops[i].id);
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 72, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            'No shops found',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your filters',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab button
// ─────────────────────────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shop card — matches Reward Zone screenshot design
// ─────────────────────────────────────────────────────────────────────────────

class _ShopCard extends StatelessWidget {
  final ShopItem shop;
  final bool isFav;
  final VoidCallback onToggleFav;
  const _ShopCard(
      {required this.shop,
      required this.isFav,
      required this.onToggleFav});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/shop-detail', extra: shop),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left rectangular image ──────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 110,
                height: 110,
                child: shop.imageData != null && shop.imageData!.isNotEmpty
                    ? Image.memory(
                        base64Decode(shop.imageData!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackAvatar(shop),
                      )
                    : _fallbackAvatar(shop),
              ),
            ),

            // ── Info ────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + heart
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            shop.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: onToggleFav,
                          child: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 20,
                            color: isFav
                                ? Colors.redAccent
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Location
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 12, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            shop.location,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Badges: distance + category
                    Row(
                      children: [
                        if (shop.distance.isNotEmpty) ...[
                          _Badge(
                            label: shop.distance,
                            bgColor: const Color(0xFFF3F4F6),
                            textColor: const Color(0xFF374151),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Builder(builder: (_) {
                          final cat = _catName(shop.categoryIds);
                          if (cat.isEmpty) return const SizedBox.shrink();
                          return _Badge(
                            label: cat,
                            bgColor: const Color(0xFFEFF6FF),
                            textColor: const Color(0xFF2563EB),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Small badge chip used in the shop card
class _Badge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  const _Badge(
      {required this.label,
      required this.bgColor,
      required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fallback avatar — shown when image_data is absent or fails to decode
// ─────────────────────────────────────────────────────────────────────────────

Widget _fallbackAvatar(ShopItem shop) {
  return Container(
    color: shop.fallbackColor,
    alignment: Alignment.center,
    child: Icon(shop.fallbackIcon, size: 28, color: Colors.grey.shade400),
  );
}

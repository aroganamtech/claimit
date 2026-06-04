import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/shop_category.dart';
import '../../../shared/widgets/shop_filter_sheet.dart';
import '../services/shop_service.dart';
import '../../profile/providers/profile_provider.dart';
import '../../auth/providers/auth_provider.dart';

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
  final int reviewCount;
  final int addedDaysAgo;

  /// S3 public URL for the primary shop image (preferred over imageData).
  final String imageUrl;

  /// S3 URLs for the detail-page carousel (up to 3).
  final List<String> imageUrls;

  /// Base64-encoded image bytes — legacy fallback only (now usually empty).
  final String? imageData;

  /// List of up to 3 base64-encoded images — legacy fallback only.
  final List<String> imageDataList;

  /// Filename reference, e.g. "img1.jpg"
  final String imageName;

  /// Resolved client-side from categoryIds for fallback display
  final Color fallbackColor;
  final IconData fallbackIcon;

  final bool hasRewards;
  final bool hasRedeem;

  /// Short description shown in the "About" section on the detail page.
  final String about;

  final String address;
  final String timing;
  final String phone;
  final String email;

  /// Distance from user — provided by backend, e.g. "6 km"
  final String distance;

  /// GPS coordinates (optional — used for Get Direction)
  final double? lat;
  final double? lng;

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
    this.reviewCount = 0,
    this.imageUrl = '',
    this.imageUrls = const [],
    this.imageData,
    this.imageDataList = const [],
    this.imageName = '',
    this.hasRewards = true,
    this.hasRedeem = true,
    this.about = '',
    this.address = '',
    this.timing = '',
    this.phone = '',
    this.email = '',
    this.distance = '',
    this.lat,
    this.lng,
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
  /// When true: rendered as a persistent bottom-nav tab.
  /// Hides the back button, locks to Redeem mode, no Rewards/Redeem toggle.
  final bool isTab;
  const ShopListScreen({super.key, required this.category, this.isTab = false});

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

  @override
  void initState() {
    super.initState();
    // Default tab: Rewards for category screens (id > 0).
    // For isTab / id==-1 (Nearby) the toggle is hidden; value doesn't affect filtering.
    _isRewards = !widget.isTab && widget.category.id > 0;
    _loadShops();
  }

  Future<void> _loadShops() async {
    setState(() { _isLoading = true; _loadError = null; });
    try {
      // Refresh liked IDs so heart buttons always show correct state
      final profileProvider = context.read<ProfileProvider>();
      await profileProvider.fetchLikedIds();

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

    // Rewards / Redeem filter:
    // • isTab (Redeem+ Zone bottom-nav tab) → always filter hasRedeem
    // • id > 0 (specific category) → respect _isRewards toggle
    // • id == -1 AND NOT isTab (Nearby Shops / See-All) → show ALL shops, no filter
    // • id == 0 (Reward Zone) → filter hasRewards
    if (widget.isTab) {
      shops = shops.where((s) => s.hasRedeem).toList();
    } else if (baseCatId == 0) {
      shops = shops.where((s) => s.hasRewards).toList();
    } else if (baseCatId != -1) {
      // Specific category: apply tab toggle
      if (_isRewards) {
        shops = shops.where((s) => s.hasRewards).toList();
      } else {
        shops = shops.where((s) => s.hasRedeem).toList();
      }
    }
    // baseCatId == -1 AND !isTab → Nearby / See-All: no reward/redeem filter

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
    if (widget.isTab) return 'Redeem+ Zone';
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

  // ── AppBar — home-style: logo+location+bell / back+title+filter+search ───────
  PreferredSizeWidget _buildAppBar() {
    final location = context.select<AuthProvider, String>(
      (a) => a.user?.location?.isNotEmpty == true ? a.user!.location! : 'Select Area',
    );
    final topPad = MediaQuery.of(context).padding.top;
    return PreferredSize(
      preferredSize: Size.fromHeight(112 + topPad),
      child: Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: logo + location + bell
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Image.asset('assets/images/home_main_logo.png',
                        height: 30, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text('claimit',
                            style: TextStyle(fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1565C0)))),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push('/location'),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(location, maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black)),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 44, height: 44,
                      child: IconButton(
                        icon: const Icon(Icons.notifications_none_rounded,
                            size: 28, color: Color(0xFF1565C0)),
                        onPressed: () => context.go('/notifications'),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              // Row 2: back + title + filter + search
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 8, 10),
                child: Row(
                  children: [
                    if (!widget.isTab)
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFF2563EB), size: 18),
                        ),
                      ),
                    Expanded(
                      child: _showSearch
                          ? TextField(
                              controller: _searchCtrl,
                              autofocus: true,
                              onChanged: (v) => setState(() => _searchQuery = v),
                              decoration: InputDecoration(
                                hintText: 'Search $_activeTitle…',
                                hintStyle: const TextStyle(
                                    fontSize: 14, color: Color(0xFF9CA3AF)),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 16),
                            )
                          : Text(_activeTitle,
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              )),
                    ),
                    GestureDetector(
                      onTap: _openFilter,
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF374151)),
                            const SizedBox(width: 4),
                            const Text('Filter',
                                style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
                            if (_filterCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 16, height: 16,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB), shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: Text('$_filterCount',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showSearch ? Icons.close_rounded : Icons.search_rounded,
                        color: const Color(0xFF1E3A8A), size: 24,
                      ),
                      onPressed: () => setState(() {
                        _showSearch = !_showSearch;
                        if (!_showSearch) { _searchCtrl.clear(); _searchQuery = ''; }
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
      floatingActionButton: SizedBox(
        width: 68, height: 68,
        child: FloatingActionButton(
          backgroundColor: const Color(0xFFEAB308),
          elevation: 6,
          shape: const CircleBorder(),
          onPressed: () => context.go('/home'),
          child: Image.asset('assets/icons/main_icon.png',
              width: 54, height: 54, fit: BoxFit.contain),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        notchMargin: 10.0,
        shape: const CircularNotchedRectangle(),
        color: const Color.fromARGB(255, 20, 143, 208),
        elevation: 8,
        padding: EdgeInsets.zero,
        height: kBottomNavigationBarHeight + 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BottomBarItem(icon: Icons.home_rounded, label: 'Home',
                      assetIcon: 'assets/icons/home_page_icons/icon2.png',
                      onTap: () => context.go('/home')),
                  _BottomBarItem(icon: Icons.play_circle_rounded, label: 'Reels',
                      onTap: () => context.go('/reelz')),
                ],
              )),
              const SizedBox(width: 72),
              Expanded(child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BottomBarItem(icon: Icons.qr_code_scanner_rounded, label: 'Scan Bill',
                      assetIcon: 'assets/icons/home_page_icons/icon5.png',
                      isScanProfile: true,
                      onTap: () => context.push('/bill-reader')),
                  _BottomBarItem(icon: Icons.person_rounded, label: 'Profile',
                      assetIcon: 'assets/icons/home_page_icons/icon7.png',
                      isScanProfile: true,
                      onTap: () => context.go('/profile')),
                ],
              )),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Hide tab toggle when isTab (Redeem+ nav tab) or special zone ids
          if (!widget.isTab && widget.category.id > 0) _buildTabToggle(),
          if (!widget.isTab && widget.category.id > 0)
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
                            child: Consumer<ProfileProvider>(
                              builder: (ctx, profile, _) => ListView.builder(
                                itemCount: shops.length,
                                padding: const EdgeInsets.only(top: 4, bottom: 16),
                                itemBuilder: (_, i) {
                                  final s = shops[i];
                                  return _ShopCard(
                                    shop: s,
                                    isFav: profile.isLiked(s.id),
                                    // isTab locks to Redeem+ Zone; otherwise
                                    // follow the active Rewards/Redeem toggle
                                    isRedeemMode: widget.isTab || !_isRewards,
                                    onToggleFav: () => profile.toggleFavourite(
                                      s.id,
                                      name: s.name,
                                      location: s.location,
                                      imageUrl: s.imageUrl,
                                      imageData: s.imageData,
                                      discount: s.discount,
                                      rating: s.rating,
                                    ),
                                  );
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
          Icon(Icons.store_outlined, size: 80, color: Colors.grey.shade200),
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
  /// true  → card is shown inside the Redeem tab  → "X% Disc + 1% Cashback"
  /// false → card is shown inside the Rewards tab → "Free Reward + 1% Cashback"
  final bool isRedeemMode;
  const _ShopCard({
    required this.shop,
    required this.isFav,
    required this.onToggleFav,
    required this.isRedeemMode,
  });

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
                width: 130,
                height: 130,
                child: _shopImageWidget(shop, fit: BoxFit.cover),
              ),
            ),

            // ── Info ────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
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
                            size: 28,
                            color: isFav
                                ? Colors.redAccent
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Location
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 28, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            shop.location,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF6B7280)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Offer tag — differs by tab context
                    if (isRedeemMode)
                      // Redeem tab: dynamic discount % + static 1% cashback
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFFFB923C).withOpacity(0.45)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_offer_rounded,
                                size: 11, color: Color(0xFFF97316)),
                            const SizedBox(width: 4),
                            Text(
                              '${shop.discount}% Disc + 1% Cashback',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFC2410C)),
                            ),
                          ],
                        ),
                      )
                    else
                      // Rewards tab: static — user earns reward points + 1% cashback
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF93C5FD).withOpacity(0.7)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.card_giftcard_rounded,
                                size: 11, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text(
                              'Free Reward + 1% Cashback',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D4ED8)),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 6),

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
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── Shop image helper — prefers S3 URL, falls back to base64, then avatar ─────
Widget _shopImageWidget(ShopItem shop, {BoxFit fit = BoxFit.cover}) {
  if (shop.imageUrl.isNotEmpty) {
    return Image.network(
      shop.imageUrl,
      fit: fit,
      errorBuilder: (_, __, ___) => _fallbackAvatar(shop),
    );
  }
  if (shop.imageData != null && shop.imageData!.isNotEmpty) {
    try {
      return Image.memory(
        base64Decode(shop.imageData!),
        fit: fit,
        errorBuilder: (_, __, ___) => _fallbackAvatar(shop),
      );
    } catch (_) {}
  }
  return _fallbackAvatar(shop);
}

// Fallback avatar — shown when image_data is absent or fails to decode
// ─────────────────────────────────────────────────────────────────────────────

Widget _fallbackAvatar(ShopItem shop) {
  return Container(
    color: shop.fallbackColor,
    alignment: Alignment.center,
    child: Icon(shop.fallbackIcon, size: 36, color: Colors.grey.shade400),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom bar item
// ─────────────────────────────────────────────────────────────────────────────
class _BottomBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? assetIcon;
  final bool isScanProfile;
  const _BottomBarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.assetIcon,
    this.isScanProfile = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final iconSize = isScanProfile
        ? (screenW * 0.095).clamp(30.0, 38.0)
        : (screenW * 0.075).clamp(24.0, 28.0);
    final fontSize = (screenW * 0.025).clamp(9.0, 11.0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 60, maxWidth: 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: assetIcon != null
                  ? Padding(
                      padding: isScanProfile ? EdgeInsets.zero : const EdgeInsets.all(4),
                      child: Image.asset(assetIcon!, fit: BoxFit.contain,
                          color: Colors.white, colorBlendMode: BlendMode.srcIn,
                          errorBuilder: (_, __, ___) =>
                              Icon(icon, color: Colors.white, size: iconSize)),
                    )
                  : Icon(icon, color: Colors.white, size: iconSize),
            ),
            const SizedBox(height: 1),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: fontSize,
                    fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

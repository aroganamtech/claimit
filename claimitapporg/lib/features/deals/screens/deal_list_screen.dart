import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/deal_model.dart';
import '../services/deal_service.dart';
import '../../../shared/widgets/shop_filter_sheet.dart'; // filterCats
import '../../profile/providers/profile_provider.dart';
import '../../auth/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DealListScreen
//
// Shared screen for Brand Deals (dealGroup='brand') and
// Nearby Deals (dealGroup='nearby').
//
// Nearby Deals shows a scrollable category icon row that filters the list.
// Both screens have a Filter badge button and an inline search toggle.
// ─────────────────────────────────────────────────────────────────────────────

class DealListScreen extends StatefulWidget {
  final String title;      // "Brand Deals" | "Nearby Deals"
  final String dealGroup;  // "brand"        | "nearby"

  const DealListScreen({
    super.key,
    required this.title,
    required this.dealGroup,
  });

  @override
  State<DealListScreen> createState() => _DealListScreenState();
}

class _DealListScreenState extends State<DealListScreen> {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<DealDto> _all = [];
  bool _isLoading = true;
  String? _error;

  // ── Search ────────────────────────────────────────────────────────────────
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Category filter (Nearby only) ─────────────────────────────────────────
  int? _selectedCatId; // null = "All"

  // ── Filtered list ─────────────────────────────────────────────────────────
  List<DealDto> get _filtered {
    var list = _all;

    // Category (Nearby only — maps filterCat label → DealDto.type)
    if (_selectedCatId != null) {
      final catLabel = filterCats
          .firstWhere((c) => c.id == _selectedCatId,
              orElse: () => filterCats.first)
          .label
          .replaceAll('\n', ' ')
          .toLowerCase();
      list = list
          .where((d) =>
              d.type.toLowerCase().contains(catLabel) ||
              catLabel.contains(d.type.toLowerCase()))
          .toList();
    }

    // Search
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list
          .where((d) =>
              d.name.toLowerCase().contains(q) ||
              d.offer.toLowerCase().contains(q) ||
              d.type.toLowerCase().contains(q) ||
              d.location.toLowerCase().contains(q))
          .toList();
    }

    return list;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadDeals();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDeals() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final deals = widget.dealGroup == 'brand'
          ? await DealService.instance.fetchBrandDeals()
          : await DealService.instance.fetchNearbyDeals();
      if (mounted) setState(() { _all = deals; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ── Convert DealDto → DealData for detail screen ─────────────────────────
  DealData _toData(DealDto d) {
    final meta = _typeMetaFor(d.type);
    return DealData(
      id: d.id,
      name: d.name,
      location: d.location,
      offer: d.offer,
      distance: d.distance,
      type: d.type,
      imageUrl: d.imageUrl,
      fallbackColor: meta.$1,
      fallbackIcon: meta.$2,
      description: d.description,
      address: d.address,
      phone: d.phone,
      timing: d.timing,
      rating: d.rating,
      reviews: d.reviews,
    );
  }

  static (Color, IconData) _typeMetaFor(String type) {
    const map = <String, (Color, IconData)>{
      'Clothing':       (Color(0xFFF3E5F5), Icons.checkroom_rounded),
      'Restaurant':     (Color(0xFFFFF8E1), Icons.restaurant_rounded),
      'Electronics':    (Color(0xFFE8EAF6), Icons.devices_rounded),
      'Department Store': (Color(0xFFE0F2F1), Icons.shopping_bag_rounded),
      'Supermarket':    (Color(0xFFFFF3E0), Icons.store_mall_directory_rounded),
      'Clinic':         (Color(0xFFE3F2FD), Icons.local_hospital_rounded),
      'Bakery':         (Color(0xFFFFF3E0), Icons.bakery_dining_rounded),
      'Gym':            (Color(0xFFE8EAF6), Icons.fitness_center_rounded),
      'Salon':          (Color(0xFFFCE4EC), Icons.content_cut_rounded),
      'Pharmacy':       (Color(0xFFE3F2FD), Icons.medical_services_rounded),
      'Camera':         (Color(0xFFECEFF1), Icons.camera_alt_rounded),
      'Appliances':     (Color(0xFFE8EAF6), Icons.kitchen_rounded),
      'Café':           (Color(0xFFFBE9E7), Icons.local_cafe_rounded),
      'Cafes':          (Color(0xFFFBE9E7), Icons.local_cafe_rounded),
      'cafe':           (Color(0xFFFBE9E7), Icons.local_cafe_rounded),
    };
    return map[type] ?? (const Color(0xFFEEEEEE), Icons.store_rounded);
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
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
                            Flexible(child: Text(location, maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black))),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(width: 44, height: 44,
                      child: IconButton(
                        icon: const Icon(Icons.notifications_none_rounded,
                            size: 28, color: Color(0xFF1565C0)),
                        onPressed: () => context.go('/notifications'),
                        padding: EdgeInsets.zero,
                      )),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              // Row 2: back + title + filter + search
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 8, 10),
                child: Row(
                  children: [
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
                                hintText: 'Search ${widget.title}…',
                                hintStyle: const TextStyle(
                                    fontSize: 14, color: Color(0xFF9CA3AF)),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 16),
                            )
                          : Text(widget.title,
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune_rounded,
                                size: 20, color: Color(0xFF374151)),
                            SizedBox(width: 4),
                            Text('Filter',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF374151))),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showSearch ? Icons.close_rounded : Icons.search_rounded,
                        color: const Color(0xFF1E3A8A), size: 24,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filter sheet ──────────────────────────────────────────────────────────
  void _openFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShopFilterSheet(
        initialSort: null,
        initialCatId: _selectedCatId,
        initialRating: null,
        initialPrice: null,
        onApply: (_, catId, __, ___) {
          setState(() => _selectedCatId = catId);
        },
      ),
    );
  }

  // ── Category scroll row (Nearby only) ─────────────────────────────────────
  Widget _buildCategoryRow() {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: filterCats.length + 1, // +1 for "All"
        itemBuilder: (_, i) {
          if (i == 0) {
            // "All" chip
            final active = _selectedCatId == null;
            return GestureDetector(
              onTap: () => setState(() => _selectedCatId = null),
              child: _CatIcon(
                icon: Icons.apps_rounded,
                label: 'All',
                color: const Color(0xFF2563EB),
                active: active,
              ),
            );
          }
          final cat = filterCats[i - 1];
          final active = _selectedCatId == cat.id;
          return GestureDetector(
            onTap: () => setState(
                () => _selectedCatId = active ? null : cat.id),
            child: _CatIcon(
              icon: cat.icon,
              label: cat.label.replaceAll('\n', ' '),
              color: cat.color,
              active: active,
              isNew: cat.isNew,
              catId: cat.id, // maps to category_icon/icon{id}.png
            ),
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final deals = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
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
                  _DealBottomBarItem(icon: Icons.home_rounded, label: 'Home',
                      assetIcon: 'assets/icons/home_page_icons/icon2.png',
                      onTap: () => context.go('/home')),
                  _DealBottomBarItem(icon: Icons.play_circle_rounded, label: 'Reels',
                      onTap: () => context.go('/reelz')),
                ],
              )),
              const SizedBox(width: 72),
              Expanded(child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _DealBottomBarItem(icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan Bill',
                      assetIcon: 'assets/icons/home_page_icons/icon5.png',
                      isScanProfile: true,
                      onTap: () => context.push('/bill-reader')),
                  _DealBottomBarItem(icon: Icons.person_rounded, label: 'Profile',
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
          // Category scroll — only for Nearby Deals
          if (widget.dealGroup == 'nearby') ...[
            Container(
              color: Colors.white,
              child: _buildCategoryRow(),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
          ],

          // Main content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF2563EB)))
                : _error != null
                    ? _buildError()
                    : deals.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _loadDeals,
                            color: const Color(0xFF2563EB),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 12, 16, 20),
                              itemCount: deals.length,
                              itemBuilder: (_, i) => _DealCard(
                                deal: deals[i],
                                onTap: () => context.push(
                                    '/deal-detail',
                                    extra: _toData(deals[i])),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 12),
            const Text('Could not load deals',
                style: TextStyle(
                    fontSize: 15, color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadDeals,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined,
                size: 72, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text(
              'No deals found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different category or search term',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Category icon tile
// ─────────────────────────────────────────────────────────────────────────────

class _CatIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final bool isNew;
  // catId: 1-based index into category_icon assets (null = "All" button)
  final int? catId;

  const _CatIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    this.isNew = false,
    this.catId,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = catId != null
        ? 'assets/icons/category_icon/icon$catId.png'
        : null;

    return Container(
      width: 68,
      margin: const EdgeInsets.only(right: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Icons already have circle built-in — no extra border needed
              SizedBox(
                width: 54,
                height: 54,
                child: assetPath != null
                    ? Image.asset(
                        assetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            Icon(icon, size: 24, color: color),
                      )
                    : Icon(icon, size: 24, color: color),
              ),
              if (isNew)
                Positioned(
                  top: 2,
                  left: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4B400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('New',
                        style: TextStyle(
                            fontSize: 6,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: active ? color : Colors.black87,
              fontWeight:
                  active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Deal card — matches screenshot design
// ─────────────────────────────────────────────────────────────────────────────

class _DealCard extends StatefulWidget {
  final DealDto deal;
  final VoidCallback onTap;
  const _DealCard({required this.deal, required this.onTap});

  @override
  State<_DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<_DealCard> {
  bool _isFav = false;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _isFav = context.read<ProfileProvider>().isLikedDeal(widget.deal.id);
  }

  Future<void> _toggleFav() async {
    if (_toggling) return;
    setState(() => _toggling = true);
    final d = widget.deal;
    final nowLiked = await context.read<ProfileProvider>().toggleDealFavourite(
          d.id,
          name: d.name,
          location: d.location,
          imageUrl: d.imageUrl,
          offer: d.offer,
        );
    if (mounted) setState(() { _isFav = nowLiked; _toggling = false; });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.deal;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
            // ── Left rectangular image ─────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
              child: SizedBox(
                width: 120,
                height: 110,
                child: d.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: d.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _fallback(d),
                        errorWidget: (_, __, ___) => _fallback(d),
                      )
                    : _fallback(d),
              ),
            ),

            // ── Info ───────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + Premium badge + heart
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (d.isPremium) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 6, top: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: const Color(0xFFFBBF24), width: 1),
                            ),
                            child: const Text(
                              'PREMIUM',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB45309),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            d.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: _toggleFav,
                          child: Icon(
                            _isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 28,
                            color: _isFav
                                ? Colors.redAccent
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Location (no icon — matches the home nearby-deals card)
                    Text(
                      d.location,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),

                    // Offer text
                    Text(
                      d.offer,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 7),

                    // Badges: distance + type
                    Row(
                      children: [
                        if (d.distance.isNotEmpty) ...[
                          _Badge(
                            label: d.distance,
                            bgColor: const Color(0xFFF3F4F6),
                            textColor: const Color(0xFF374151),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (d.type.isNotEmpty)
                          _Badge(
                            label: d.type,
                            bgColor: const Color(0xFFEFF6FF),
                            textColor: const Color(0xFF2563EB),
                          ),
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

  Widget _fallback(DealDto d) {
    final meta = _DealListScreenState._typeMetaFor(d.type);
    return Container(
      color: meta.$1,
      alignment: Alignment.center,
      child: Icon(meta.$2, size: 36, color: Colors.grey.shade400),
    );
  }
}

// Small badge chip
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
// Bottom bar item for DealListScreen
// ─────────────────────────────────────────────────────────────────────────────
class _DealBottomBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? assetIcon;
  final bool isScanProfile;
  const _DealBottomBarItem({
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

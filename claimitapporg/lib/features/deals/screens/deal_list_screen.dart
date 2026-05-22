import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/deal_model.dart';
import '../services/deal_service.dart';
import '../../../shared/widgets/shop_filter_sheet.dart'; // filterCats
import '../../profile/providers/profile_provider.dart';

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
                  hintText: 'Search ${widget.title}…',
                  hintStyle: const TextStyle(
                      fontSize: 14, color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 16),
              )
            : Text(
                widget.title,
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          // Filter badge button
          GestureDetector(
            onTap: _openFilter,
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, size: 26, color: Color(0xFF374151)),
                  SizedBox(width: 4),
                  Text('Filter',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF374151))),
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
      height: 92,
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

  const _CatIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      margin: const EdgeInsets.only(right: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? color.withOpacity(0.15)
                      : Colors.white,
                  border: Border.all(
                    color: active ? color : const Color(0xFFE5E7EB),
                    width: active ? 2 : 1,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                              color: color.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ]
                      : [],
                ),
                child: Icon(icon, size: 22, color: color),
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
            // ── Left rectangular image ─────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 110,
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
                    // Name + heart
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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

                    // Location
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 28, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            d.location,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared Filter & Sort bottom sheet
// Used by ShopListScreen, SearchScreen, and any other screen that needs
// the same category / rating / price filtering on shop data.
// ─────────────────────────────────────────────────────────────────────────────

class FilterCat {
  final int id;
  final String label;
  final IconData icon;
  final Color color;
  final bool isNew;
  const FilterCat(this.id, this.label, this.icon, this.color,
      {this.isNew = false});
}

const filterCats = <FilterCat>[
  FilterCat(1,  'Supermarkets',        Icons.local_grocery_store_rounded, Color(0xFF3B82F6)),
  FilterCat(2,  'Fruits &\nVegetables', Icons.eco_rounded,                Color(0xFF10B981)),
  FilterCat(3,  'Pharmacies',          Icons.local_pharmacy_rounded,      Color(0xFF06B6D4)),
  FilterCat(4,  'Restaurants',         Icons.restaurant_rounded,          Color(0xFFEC4899)),
  FilterCat(5,  'Cafes',               Icons.local_cafe_rounded,          Color(0xFF92400E)),
  FilterCat(6,  'Fashion',             Icons.checkroom_rounded,           Color(0xFFDB2777)),
  FilterCat(7,  'Footwear',            Icons.directions_walk_rounded,     Color(0xFF0369A1)),
  FilterCat(8,  'Bakery &\nSweets',    Icons.cake_rounded,                Color(0xFFF59E0B)),
  FilterCat(9,  'Electronics',         Icons.devices_rounded,             Color(0xFF7C3AED)),
  FilterCat(10, 'Mobile',              Icons.smartphone_rounded,          Color(0xFF0284C7)),
  FilterCat(11, 'Furniture',           Icons.chair_rounded,               Color(0xFF78350F)),
  FilterCat(12, 'Home\nFurnishing',    Icons.king_bed_rounded,            Color(0xFFF59E0B)),
  FilterCat(13, 'Home\nAppliances',    Icons.kitchen_rounded,             Color(0xFF0EA5E9)),
  FilterCat(14, 'Baby\nStores',        Icons.child_care_rounded,          Color(0xFFEC4899)),
  FilterCat(15, 'Books &\nStationery', Icons.menu_book_rounded,           Color(0xFF6366F1)),
  FilterCat(16, 'Salons',              Icons.content_cut_rounded,         Color(0xFFF59E0B)),
  FilterCat(17, 'Beauty\nParlours',    Icons.spa_rounded,                 Color(0xFFEC4899)),
  FilterCat(18, 'Optical',             Icons.visibility_rounded,          Color(0xFF0D9488)),
  FilterCat(19, 'Diagnostic\nCentres', Icons.biotech_rounded,             Color(0xFF6366F1)),
  FilterCat(20, 'Hospitals',           Icons.local_hospital_rounded,      Color(0xFFDC2626)),
];

// ─────────────────────────────────────────────────────────────────────────────
// ShopFilterSheet
// ─────────────────────────────────────────────────────────────────────────────

class ShopFilterSheet extends StatefulWidget {
  final String? initialSort;
  final int? initialCatId;
  final double? initialRating;
  final String? initialPrice;
  final void Function(String?, int?, double?, String?) onApply;

  const ShopFilterSheet({
    super.key,
    required this.initialSort,
    required this.initialCatId,
    required this.initialRating,
    required this.initialPrice,
    required this.onApply,
  });

  @override
  State<ShopFilterSheet> createState() => _ShopFilterSheetState();
}

class _ShopFilterSheetState extends State<ShopFilterSheet> {
  String? _sort;
  int? _catId;
  double? _rating;
  String? _price;

  late final PageController _catPageCtrl;
  int _catPage = 0;

  static const _catsPerPage = 5;
  int get _catPageCount => (filterCats.length / _catsPerPage).ceil();

  @override
  void initState() {
    super.initState();
    _sort   = widget.initialSort;
    _catId  = widget.initialCatId;
    _rating = widget.initialRating;
    _price  = widget.initialPrice;
    _catPageCtrl = PageController();
  }

  @override
  void dispose() {
    _catPageCtrl.dispose();
    super.dispose();
  }

  void _clearAll() {
    setState(() {
      _sort = null;
      _catId = null;
      _rating = null;
      _price = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter & Sort',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    GestureDetector(
                      onTap: _clearAll,
                      child: const Text(
                        'Clear all',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  children: [
                    // ── Sort chips ────────────────────────────────────────
                    _buildSortChips(),

                    const SizedBox(height: 28),

                    // ── Category ──────────────────────────────────────────
                    _buildSectionTitle('Category'),
                    const SizedBox(height: 14),
                    _buildCategoryPagedRow(),

                    const SizedBox(height: 28),

                    // ── Ratings ───────────────────────────────────────────
                    _buildSectionTitle('Ratings'),
                    const SizedBox(height: 14),
                    _buildRatingRow(),

                    const SizedBox(height: 28),

                    // ── Price ─────────────────────────────────────────────
                    _buildSectionTitle('Price'),
                    const SizedBox(height: 14),
                    _buildPriceRow(),

                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Apply button
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 8, 20, MediaQuery.of(context).padding.bottom + 90),
                child: GestureDetector(
                  onTap: () {
                    widget.onApply(_sort, _catId, _rating, _price);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Apply Filter',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Sort chips ──────────────────────────────────────────────────────────────
  Widget _buildSortChips() {
    final opts = [
      ('recently_added', 'Recently Added'),
      ('30_disc', '30% Discount'),
      ('50_above', '50% and Above'),
      ('20_disc', '20% Discount'),
      ('10_disc', '10% Discount'),
      ('last_7_days', 'Last 7 Days'),
    ];

    // 2 rows × 3 columns
    final rows = [opts.sublist(0, 3), opts.sublist(3, 6)];
    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: row.map((o) {
              final active = _sort == o.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _sort = active ? null : o.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF2563EB) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: active
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFD1D5DB),
                          width: active ? 1.5 : 1,
                        ),
                        boxShadow: active
                            ? [BoxShadow(
                                color: const Color(0xFF2563EB).withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2))]
                            : [],
                      ),
                      child: Text(
                        o.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? Colors.white : const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF111827),
        ),
      );

  // ── Category — scrollable PageView, 5 per page, dot indicators ─────────────
  Widget _buildCategoryPagedRow() {
    return Column(
      children: [
        SizedBox(
          height: 100,
          child: PageView.builder(
            controller: _catPageCtrl,
            itemCount: _catPageCount,
            onPageChanged: (p) => setState(() => _catPage = p),
            itemBuilder: (_, pageIdx) {
              final start = pageIdx * _catsPerPage;
              final end =
                  (start + _catsPerPage).clamp(0, filterCats.length);
              final pageItems = filterCats.sublist(start, end);

              return Row(
                children: List.generate(_catsPerPage, (i) {
                  if (i >= pageItems.length) {
                    return const Expanded(child: SizedBox.shrink());
                  }
                  final cat    = pageItems[i];
                  final active = _catId == cat.id;
                  // Asset path: icon1.png … icon30.png (cat.id is 1-based)
                  final assetPath =
                      'assets/icons/category_icon/icon${cat.id}.png';
                  return Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _catId = active ? null : cat.id),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 58,
                            height: 58,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.asset(
                                  assetPath,
                                  width: 58,
                                  height: 58,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                    cat.icon,
                                    size: 30,
                                    color: cat.color,
                                  ),
                                ),
                                if (cat.isNew)
                                  Positioned(
                                    top: 3,
                                    left: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 3, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4B400),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'New',
                                        style: TextStyle(
                                          fontSize: 6,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            cat.label,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              height: 1.2,
                              color: active ? cat.color : Colors.black87,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_catPageCount, (i) {
            final active = i == _catPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── Rating chips ────────────────────────────────────────────────────────────
  Widget _buildRatingRow() {
    // Each chip takes an equal share of the row (Expanded) and its content is
    // wrapped in a FittedBox, so all five always fit any screen width without
    // overflowing to the right.
    return Row(
      children: [1.0, 2.0, 3.0, 4.0, 5.0].map((r) {
        final active = _rating == r;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => setState(() => _rating = active ? null : r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFFEF3C7) : Colors.white,
                  border: Border.all(
                    color: active
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFE5E7EB),
                    width: active ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: active
                      ? [BoxShadow(
                          color: const Color(0xFFF59E0B).withOpacity(0.2),
                          blurRadius: 4, offset: const Offset(0, 2))]
                      : [],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${r.toInt()}.0',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? const Color(0xFFB45309)
                              : const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.star_rounded,
                        size: 20,
                        color: Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Price sort ──────────────────────────────────────────────────────────────
  Widget _buildPriceRow() {
    return Row(
      children: [
        FilterPriceChip(
          label: 'Price high to low',
          active: _price == 'high_to_low',
          onTap: () => setState(
              () => _price = _price == 'high_to_low' ? null : 'high_to_low'),
        ),
        const SizedBox(width: 10),
        FilterPriceChip(
          label: 'Price low to high',
          active: _price == 'low_to_high',
          onTap: () => setState(
              () => _price = _price == 'low_to_high' ? null : 'low_to_high'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Price chip widget
// ─────────────────────────────────────────────────────────────────────────────

class FilterPriceChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const FilterPriceChip(
      {super.key, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEFF6FF) : Colors.white,
          border: Border.all(
            color: active ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: active ? const Color(0xFF2563EB) : const Color(0xFF374151),
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

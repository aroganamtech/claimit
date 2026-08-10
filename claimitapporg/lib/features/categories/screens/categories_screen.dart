import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shops/models/shop_category.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Full categories screen — matches the mobile app screenshot
// ─────────────────────────────────────────────────────────────────────────────

const _allCategories = [
  _Cat('Supermarkets',          Icons.local_grocery_store_rounded, Color(0xFF3B82F6)),
  _Cat('Fruits &\nVegetables',  Icons.eco_rounded,              Color(0xFF10B981)),
  _Cat('Pharmacies',            Icons.local_pharmacy_rounded,   Color(0xFF06B6D4)),
  _Cat('Restaurants',           Icons.restaurant_rounded,       Color(0xFFEC4899)),
  _Cat('Cafes',                 Icons.local_cafe_rounded,       Color(0xFF92400E)),
  _Cat('Bakery &\nSweets',      Icons.cake_rounded,             Color(0xFFF59E0B)),
  _Cat('Juices &\nShakes',      Icons.local_drink_rounded,      Color(0xFFEF4444)),
  _Cat('Garments',              Icons.checkroom_rounded,        Color(0xFF7C3AED)),
  _Cat('Fashion',               Icons.local_mall_rounded,       Color(0xFFDB2777)),
  _Cat('Footwear',              Icons.directions_walk_rounded,  Color(0xFF0369A1)),
  _Cat('Mobile',                Icons.smartphone_rounded,       Color(0xFF0284C7)),
  _Cat('Electronics',           Icons.devices_rounded,          Color(0xFFF59E0B)),
  _Cat('Salons',                Icons.content_cut_rounded,      Color(0xFF7C3AED)),
  _Cat('Beauty\nParlours',      Icons.spa_rounded,              Color(0xFFEC4899)),
  _Cat('Dry Fruits\n& Nuts',    Icons.grain_rounded,            Color(0xFF16A34A)),
  _Cat('Fashion\nAccessories',  Icons.shopping_bag_rounded,     Color(0xFF2563EB)),
  _Cat('Optical',               Icons.visibility_rounded,       Color(0xFF3B82F6)),
  _Cat('Home\nAppliances',      Icons.kitchen_rounded,          Color(0xFF16A34A)),
  _Cat('Furniture',             Icons.chair_rounded,            Color(0xFF06B6D4)),
  _Cat('Home\nFurnishing',      Icons.king_bed_rounded,         Color(0xFFDB2777)),
  _Cat('Baby\nStores',          Icons.child_friendly_rounded,   Color(0xFFF59E0B)),
  _Cat('Books &\nStationery',   Icons.menu_book_rounded,        Color(0xFFEF4444)),
  _Cat('Gifts &\nFancy',        Icons.card_giftcard_rounded,    Color(0xFF7C3AED)),
  _Cat('Toys &\nGames',         Icons.toys_rounded,             Color(0xFF0D9488)),
  _Cat('Sports &\nFitness',     Icons.fitness_center_rounded,   Color(0xFF2563EB)),
  _Cat('Diagnostic\nCentres',   Icons.biotech_rounded,          Color(0xFF16A34A)),
  _Cat('Hospitals',             Icons.local_hospital_rounded,   Color(0xFF06B6D4)),
  _Cat('Photography\n& Studios', Icons.camera_alt_rounded,      Color(0xFFEC4899)),
  _Cat('Pet Stores',            Icons.pets_rounded,             Color(0xFF92400E)),
  _Cat('Training\nInstitutes',  Icons.school_rounded,           Color(0xFFF59E0B)),
  _Cat('Online\nStores',        Icons.shopping_cart_rounded,    Color(0xFF2563EB)),
];

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF2563EB), size: 20),
        ),
        title: const Text(
          'Categories',
          style: TextStyle(
            color: Color(0xFF2563EB),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.search_rounded,
        //         color: Color(0xFF1E3A8A), size: 24),
        //     onPressed: () {},
        //   ),
        //   Container(
        //     margin: const EdgeInsets.only(right: 12),
        //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        //     decoration: BoxDecoration(
        //       border: Border.all(color: const Color(0xFFE5E7EB)),
        //       borderRadius: BorderRadius.circular(20),
        //     ),
        //     child: Row(
        //       children: const [
        //         Icon(Icons.tune_rounded, size: 26, color: Color(0xFF374151)),
        //         SizedBox(width: 4),
        //         Text('Filter',
        //             style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
        //       ],
        //     ),
        //   ),
        // ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 20,
          crossAxisSpacing: 8,
          childAspectRatio: 0.62,
        ),
        itemCount: _allCategories.length,
        itemBuilder: (context, index) {
          final cat = _allCategories[index];
          return GestureDetector(
            onTap: () => context.push(
              '/shops',
              extra: ShopCategory(
                id: index + 1,
                name: cat.label.replaceAll('\n', ' '),
                icon: cat.icon,
                color: cat.color,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 78,
                  height: 78,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/icons/category_icon/icon${index + 1}.png',
                        width: 78,
                        height: 78,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            Icon(cat.icon, size: 36, color: cat.color),
                      ),
                      if (cat.isNew)
                        Positioned(
                          top: 4,
                          left: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4B400),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'New',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  width: double.infinity,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        cat.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data class
// ─────────────────────────────────────────────────────────────────────────────

class _Cat {
  final String label;
  final IconData icon;
  final Color color;
  final bool isNew;
  const _Cat(this.label, this.icon, this.color, {this.isNew = false});
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shops/models/shop_category.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Full categories screen — matches the mobile app screenshot
// ─────────────────────────────────────────────────────────────────────────────

const _allCategories = [
  _Cat('New deals',             Icons.local_offer_rounded,      Color(0xFFEF4444), isNew: true),
  _Cat('Groceries',             Icons.shopping_basket_rounded,  Color(0xFF10B981)),
  _Cat('Supermarket',           Icons.store_rounded,            Color(0xFF3B82F6)),
  _Cat('Pharmacy',              Icons.local_pharmacy_rounded,   Color(0xFF06B6D4)),
  _Cat('Salon',                 Icons.content_cut_rounded,      Color(0xFFF59E0B)),
  _Cat('Gym',                   Icons.fitness_center_rounded,   Color(0xFF8B5CF6)),
  _Cat('Restaurant',            Icons.restaurant_rounded,       Color(0xFFEC4899)),
  _Cat('Cafes',                 Icons.local_cafe_rounded,       Color(0xFF92400E)),
  _Cat('Clothing',              Icons.checkroom_rounded,        Color(0xFFDB2777)),
  _Cat('Department',            Icons.apartment_rounded,        Color(0xFF0284C7)),
  _Cat('Electronics',           Icons.devices_rounded,          Color(0xFF7C3AED)),
  _Cat('Books',                 Icons.menu_book_rounded,        Color(0xFF0D9488)),
  _Cat('Toys',                  Icons.toys_rounded,             Color(0xFFF97316)),
  _Cat('Baby',                  Icons.child_care_rounded,       Color(0xFFEC4899)),
  _Cat('Home Decor',            Icons.weekend_rounded,          Color(0xFFF59E0B)),
  _Cat('Furniture',             Icons.chair_rounded,            Color(0xFF78350F)),
  _Cat('Spa',                   Icons.spa_rounded,              Color(0xFF059669)),
  _Cat('Schools',               Icons.school_rounded,           Color(0xFF2563EB)),
  _Cat('Colleges',              Icons.account_balance_rounded,  Color(0xFF1D4ED8)),
  _Cat('Tutoring',              Icons.menu_book_outlined,       Color(0xFF9333EA)),
  _Cat('Clinics',               Icons.local_hospital_rounded,   Color(0xFFEF4444)),
  _Cat('Hospitals',             Icons.emergency_rounded,        Color(0xFFDC2626)),
  _Cat('Pets',                  Icons.pets_rounded,             Color(0xFF10B981)),
  _Cat('Sports',                Icons.sports_soccer_rounded,    Color(0xFF16A34A)),
  _Cat('Travel',                Icons.luggage_rounded,          Color(0xFFEF4444)),
  _Cat('Mobile &\nAccessories', Icons.smartphone_rounded,       Color(0xFF0284C7)),
  _Cat('Computer &\nLaptop',    Icons.laptop_rounded,           Color(0xFF6366F1)),
  _Cat('Gifts',                 Icons.card_giftcard_rounded,    Color(0xFFE11D48)),
  _Cat('Jewellery',             Icons.diamond_rounded,          Color(0xFFB45309)),
  _Cat('Shoes',                 Icons.directions_run_rounded,   Color(0xFF0369A1)),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded,
                color: Color(0xFF1E3A8A), size: 24),
            onPressed: () {},
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: const [
                Icon(Icons.tune_rounded, size: 14, color: Color(0xFF374151)),
                SizedBox(width: 4),
                Text('Filter',
                    style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
              ],
            ),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 20,
          crossAxisSpacing: 4,
          childAspectRatio: 0.72,
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
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(cat.icon, size: 26, color: cat.color),
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
                Text(
                  cat.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    color: Colors.black87,
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

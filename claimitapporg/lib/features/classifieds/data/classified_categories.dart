import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Static category / subcategory data for the Classifieds feature.
// Category IDs match the strings stored in MongoDB (snake_case).
// ─────────────────────────────────────────────────────────────────────────────

class ClassifiedSubcategory {
  final String name;
  final IconData icon;
  const ClassifiedSubcategory({required this.name, required this.icon});
}

class ClassifiedCategory {
  final String id;        // stored in DB, e.g. "home_maintenance"
  final String name;      // display name
  final String subtitle;  // shown on Add Post category tile
  final IconData icon;    // category icon
  final List<ClassifiedSubcategory> subcategories;

  const ClassifiedCategory({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.subcategories,
  });
}

const List<ClassifiedCategory> classifiedCategories = [
  ClassifiedCategory(
    id: 'home_maintenance',
    name: 'Home Maintenance',
    subtitle: 'Electrician, Plumbing, Carpentry, etc',
    icon: Icons.home_repair_service_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Electrician',        icon: Icons.electrical_services_rounded),
      ClassifiedSubcategory(name: 'Plumbing',           icon: Icons.plumbing_rounded),
      ClassifiedSubcategory(name: 'Carpentry',          icon: Icons.handyman_rounded),
      ClassifiedSubcategory(name: 'Painting',           icon: Icons.format_paint_rounded),
      ClassifiedSubcategory(name: 'AC Repair',          icon: Icons.ac_unit_rounded),
      ClassifiedSubcategory(name: 'Appliance Repair',   icon: Icons.build_rounded),
      ClassifiedSubcategory(name: 'Water Tank Cleaning',icon: Icons.water_drop_rounded),
      ClassifiedSubcategory(name: 'RO Service',         icon: Icons.filter_alt_rounded),
      ClassifiedSubcategory(name: 'Pest Control',       icon: Icons.bug_report_rounded),
      ClassifiedSubcategory(name: 'Flooring',           icon: Icons.grid_on_rounded),
    ],
  ),
  ClassifiedCategory(
    id: 'domestic_help',
    name: 'Domestic Help',
    subtitle: 'Maid Services, Cook, Babysitter, etc',
    icon: Icons.people_alt_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Maid Services', icon: Icons.cleaning_services_rounded),
      ClassifiedSubcategory(name: 'Cook',           icon: Icons.restaurant_rounded),
      ClassifiedSubcategory(name: 'Babysitter',     icon: Icons.child_care_rounded),
      ClassifiedSubcategory(name: 'Elder Care',     icon: Icons.elderly_rounded),
      ClassifiedSubcategory(name: 'Driver',         icon: Icons.drive_eta_rounded),
      ClassifiedSubcategory(name: 'Security Guard', icon: Icons.security_rounded),
    ],
  ),
  ClassifiedCategory(
    id: 'home_cooked_food',
    name: 'Home-Cooked Food',
    subtitle: 'Daily Meals, Tiffin Service, Snacks',
    icon: Icons.rice_bowl_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Daily Meals',    icon: Icons.rice_bowl_rounded),
      ClassifiedSubcategory(name: 'Tiffin Service', icon: Icons.lunch_dining_rounded),
      ClassifiedSubcategory(name: 'Snacks',         icon: Icons.fastfood_rounded),
      ClassifiedSubcategory(name: 'Catering',       icon: Icons.room_service_rounded),
    ],
  ),
  ClassifiedCategory(
    id: 'buy_sell_household',
    name: 'Buy/Sell – Household',
    subtitle: 'Furniture, Electronics, Appliances',
    icon: Icons.shopping_bag_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Furniture',   icon: Icons.chair_rounded),
      ClassifiedSubcategory(name: 'Electronics', icon: Icons.devices_rounded),
      ClassifiedSubcategory(name: 'Appliances',  icon: Icons.kitchen_rounded),
      ClassifiedSubcategory(name: 'Home Decor',  icon: Icons.home_rounded),
      ClassifiedSubcategory(name: 'Books',       icon: Icons.menu_book_rounded),
    ],
  ),
  ClassifiedCategory(
    id: 'medical_services',
    name: 'Medical Services',
    subtitle: 'Doctor, Nurse, Physiotherapy, etc',
    icon: Icons.local_hospital_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Doctor Visit',    icon: Icons.medical_services_rounded),
      ClassifiedSubcategory(name: 'Nurse at Home',   icon: Icons.healing_rounded),
      ClassifiedSubcategory(name: 'Physiotherapy',   icon: Icons.accessibility_new_rounded),
      ClassifiedSubcategory(name: 'Lab Tests',       icon: Icons.biotech_rounded),
    ],
  ),
  ClassifiedCategory(
    id: 'education_service',
    name: 'Education Service',
    subtitle: 'School, College, Music, Drawing',
    icon: Icons.school_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'School Tutor',   icon: Icons.school_rounded),
      ClassifiedSubcategory(name: 'College Tutor',  icon: Icons.account_balance_rounded),
      ClassifiedSubcategory(name: 'Music',          icon: Icons.music_note_rounded),
      ClassifiedSubcategory(name: 'Drawing',        icon: Icons.draw_rounded),
      ClassifiedSubcategory(name: 'Dance',          icon: Icons.directions_run_rounded),
    ],
  ),
  ClassifiedCategory(
    id: 'local_tutors',
    name: 'Local Tutors',
    subtitle: 'Maths, Science, English, Tamil',
    icon: Icons.menu_book_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Maths',          icon: Icons.calculate_rounded),
      ClassifiedSubcategory(name: 'Science',        icon: Icons.science_rounded),
      ClassifiedSubcategory(name: 'English',        icon: Icons.translate_rounded),
      ClassifiedSubcategory(name: 'Tamil',          icon: Icons.language_rounded),
      ClassifiedSubcategory(name: 'Hindi',          icon: Icons.language_rounded),
      ClassifiedSubcategory(name: 'Social Science', icon: Icons.public_rounded),
    ],
  ),
  ClassifiedCategory(
    id: 'professional_freelancers',
    name: 'Professional Freelancers',
    subtitle: 'Web Dev, Designer, Photographer',
    icon: Icons.work_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Web Developer',    icon: Icons.code_rounded),
      ClassifiedSubcategory(name: 'Graphic Designer', icon: Icons.design_services_rounded),
      ClassifiedSubcategory(name: 'Content Writer',   icon: Icons.edit_note_rounded),
      ClassifiedSubcategory(name: 'Photographer',     icon: Icons.photo_camera_rounded),
      ClassifiedSubcategory(name: 'Video Editor',     icon: Icons.movie_rounded),
    ],
  ),
  ClassifiedCategory(
    id: 'on_demand_beauty',
    name: 'On-Demand Beauty',
    subtitle: 'Makeup, Mehendi, Hair Styling',
    icon: Icons.face_retouching_natural_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Makeup Artist', icon: Icons.face_retouching_natural_rounded),
      ClassifiedSubcategory(name: 'Mehendi',       icon: Icons.brush_rounded),
      ClassifiedSubcategory(name: 'Hair Stylist',  icon: Icons.content_cut_rounded),
      ClassifiedSubcategory(name: 'Nail Art',      icon: Icons.spa_rounded),
      ClassifiedSubcategory(name: 'Facial',        icon: Icons.face_rounded),
    ],
  ),
  ClassifiedCategory(
    id: 'fitness_sports',
    name: 'Fitness & Sports',
    subtitle: 'Personal Trainer, Yoga, Zumba',
    icon: Icons.fitness_center_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Personal Trainer', icon: Icons.fitness_center_rounded),
      ClassifiedSubcategory(name: 'Yoga',             icon: Icons.self_improvement_rounded),
      ClassifiedSubcategory(name: 'Zumba',            icon: Icons.directions_walk_rounded),
      ClassifiedSubcategory(name: 'Swimming Coach',   icon: Icons.pool_rounded),
      ClassifiedSubcategory(name: 'Cricket Coach',    icon: Icons.sports_cricket_rounded),
    ],
  ),
];

/// Quick lookup: category id → ClassifiedCategory
ClassifiedCategory? categoryById(String id) {
  try {
    return classifiedCategories.firstWhere((c) => c.id == id);
  } catch (_) {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flat (single-level) category model used by the Classified home screen's
// "Local Classified" / "Local Helpers" toggle. Unlike ClassifiedCategory above
// (which nests subcategories under a parent for the Add-Post flow), each of
// these is directly tappable and goes straight to the listings screen.
// ─────────────────────────────────────────────────────────────────────────────

class ClassifiedTopCategory {
  final String id;          // unique key for this grid item
  final String name;        // display label
  final IconData icon;
  final String category;    // value sent as ?category= to the list screen
  final String subcategory; // value sent as ?subcategory= (may be empty)

  const ClassifiedTopCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
    this.subcategory = '',
  });
}

/// "Local Classified" tab — top-level posting categories
/// (property, rentals, jobs, buy & sell, etc).
const List<ClassifiedTopCategory> localClassifiedCategories = [
  ClassifiedTopCategory(id: 'property',    name: 'Property',    icon: Icons.apartment_rounded,      category: 'property'),
  ClassifiedTopCategory(id: 'home_needs',  name: 'Home Needs',  icon: Icons.home_rounded,            category: 'home_needs'),
  ClassifiedTopCategory(id: 'rental',      name: 'Rental',      icon: Icons.house_rounded,           category: 'rental'),
  ClassifiedTopCategory(id: 'job',         name: 'Job',         icon: Icons.work_rounded,             category: 'job'),
  ClassifiedTopCategory(id: 'buy_sell',    name: 'Buy & Sell',  icon: Icons.shopping_bag_rounded,     category: 'buy_sell'),
  ClassifiedTopCategory(id: 'community',   name: 'Community',   icon: Icons.groups_rounded,          category: 'community'),
  ClassifiedTopCategory(id: 'vehicle',     name: 'Vehicle',     icon: Icons.directions_car_rounded,  category: 'vehicle'),
  ClassifiedTopCategory(id: 'tuition',     name: 'Tuition',     icon: Icons.school_rounded,           category: 'tuition'),
  ClassifiedTopCategory(id: 'electronics', name: 'Electronics', icon: Icons.devices_rounded,          category: 'electronics'),
  ClassifiedTopCategory(id: 'hostel',      name: 'Hostel',      icon: Icons.bed_rounded,              category: 'hostel'),
  ClassifiedTopCategory(id: 'furniture',   name: 'Furniture',   icon: Icons.chair_rounded,            category: 'furniture'),
  ClassifiedTopCategory(id: 'others',      name: 'Others',      icon: Icons.more_horiz_rounded,       category: 'others'),
];

/// "Local Helpers" tab — every existing service subcategory flattened into
/// one grid (no nested "view all" grouping). Reuses the existing nested
/// category/subcategory ids so already-submitted posts stay filterable.
/// The product-selling group ("Buy/Sell – Household") is excluded here since
/// it's covered by the "Local Classified" tab instead (Buy & Sell, Furniture,
/// Electronics, Others).
final List<ClassifiedTopCategory> localHelperCategories = classifiedCategories
    .where((c) => c.id != 'buy_sell_household')
    .expand(
      (c) => c.subcategories.map(
        (s) => ClassifiedTopCategory(
          id: '${c.id}_${s.name}',
          name: s.name,
          icon: s.icon,
          category: c.id,
          subcategory: s.name,
        ),
      ),
    )
    .toList();

// ─────────────────────────────────────────────────────────────────────────────
// "Local Finds" zone — the 12-tile landing grid shown before the Classified
// home screen (Shop / Eat / Beauty / Health / Fitness / Edu / Services /
// Auto / Stay / Entertain / Fin / Living). Each zone lists its own
// sub-categories, shown on LocalFindZoneScreen; tapping a sub-category opens
// the shared browse + "add post" list screen (same as Local Classified).
// ─────────────────────────────────────────────────────────────────────────────

class LocalFindZone {
  final String id;      // stable key, e.g. "shop"
  final String label;   // display label, e.g. "Shop"
  final IconData icon;
  final List<ClassifiedSubcategory> subcategories;

  const LocalFindZone({
    required this.id,
    required this.label,
    required this.icon,
    this.subcategories = const [],
  });
}

const List<LocalFindZone> localFindZones = [
  LocalFindZone(
    id: 'shop',
    label: 'Shop',
    icon: Icons.shopping_bag_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Grocery',               icon: Icons.shopping_basket_rounded),
      ClassifiedSubcategory(name: 'Supermarkets',           icon: Icons.store_rounded),
      ClassifiedSubcategory(name: 'Fashion',                icon: Icons.checkroom_rounded),
      ClassifiedSubcategory(name: 'Footwear',                icon: Icons.directions_run_rounded),
      ClassifiedSubcategory(name: 'Mobiles & Electronics',   icon: Icons.devices_rounded),
      ClassifiedSubcategory(name: 'Home & Living',           icon: Icons.home_rounded),
      ClassifiedSubcategory(name: 'Jewellery',               icon: Icons.diamond_rounded),
      ClassifiedSubcategory(name: 'Books',                   icon: Icons.menu_book_rounded),
      ClassifiedSubcategory(name: 'Gifts & Toys',            icon: Icons.card_giftcard_rounded),
      ClassifiedSubcategory(name: 'Pet Supplies',            icon: Icons.pets_rounded),
    ],
  ),
  LocalFindZone(
    id: 'eat',
    label: 'Eat',
    icon: Icons.restaurant_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Restaurants',        icon: Icons.restaurant_rounded),
      ClassifiedSubcategory(name: 'Cafés',               icon: Icons.local_cafe_rounded),
      ClassifiedSubcategory(name: 'Bakeries / Sweets',   icon: Icons.bakery_dining_rounded),
      ClassifiedSubcategory(name: 'Fast Food',           icon: Icons.fastfood_rounded),
      ClassifiedSubcategory(name: 'Juice / Ice Cream',   icon: Icons.lunch_dining_rounded),
      ClassifiedSubcategory(name: 'Catering',            icon: Icons.room_service_rounded),
      ClassifiedSubcategory(name: 'Cloud Kitchens',      icon: Icons.rice_bowl_rounded),
    ],
  ),
  LocalFindZone(
    id: 'beauty',
    label: 'Beauty',
    icon: Icons.face_retouching_natural_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Salons',           icon: Icons.content_cut_rounded),
      ClassifiedSubcategory(name: 'Parlours',         icon: Icons.face_rounded),
      ClassifiedSubcategory(name: 'Spa / Wellness',   icon: Icons.spa_rounded),
      ClassifiedSubcategory(name: 'Cosmetics',        icon: Icons.brush_rounded),
      ClassifiedSubcategory(name: 'Bridal / Makeup',  icon: Icons.face_retouching_natural_rounded),
    ],
  ),
  LocalFindZone(
    id: 'health',
    label: 'Health',
    icon: Icons.favorite_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Hospitals',       icon: Icons.local_hospital_rounded),
      ClassifiedSubcategory(name: 'Clinics',         icon: Icons.medical_services_rounded),
      ClassifiedSubcategory(name: 'Pharmacies',      icon: Icons.local_pharmacy_rounded),
      ClassifiedSubcategory(name: 'Diagnostics',     icon: Icons.biotech_rounded),
      ClassifiedSubcategory(name: 'Optical',         icon: Icons.remove_red_eye_outlined),
      ClassifiedSubcategory(name: 'Dental',          icon: Icons.healing_rounded),
      ClassifiedSubcategory(name: 'Physiotherapy',   icon: Icons.accessibility_new_rounded),
      ClassifiedSubcategory(name: 'Veterinary',      icon: Icons.pets_rounded),
      ClassifiedSubcategory(name: 'Ayurveda',        icon: Icons.eco_rounded),
      ClassifiedSubcategory(name: 'Homeopathy',      icon: Icons.health_and_safety_rounded),
    ],
  ),
  LocalFindZone(
    id: 'fitness',
    label: 'Fitness',
    icon: Icons.fitness_center_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Gyms',           icon: Icons.fitness_center_rounded),
      ClassifiedSubcategory(name: 'Yoga',           icon: Icons.self_improvement_rounded),
      ClassifiedSubcategory(name: 'Wellness',       icon: Icons.spa_rounded),
      ClassifiedSubcategory(name: 'Dance',          icon: Icons.music_note_rounded),
      ClassifiedSubcategory(name: 'Martial Arts',   icon: Icons.sports_rounded),
    ],
  ),
  LocalFindZone(
    id: 'edu',
    label: 'Edu',
    icon: Icons.school_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Play Schools',        icon: Icons.child_care_rounded),
      ClassifiedSubcategory(name: 'Schools',             icon: Icons.school_rounded),
      ClassifiedSubcategory(name: 'Colleges',            icon: Icons.account_balance_rounded),
      ClassifiedSubcategory(name: 'Tuition',             icon: Icons.menu_book_rounded),
      ClassifiedSubcategory(name: 'Coaching',            icon: Icons.groups_rounded),
      ClassifiedSubcategory(name: 'Training',            icon: Icons.cast_for_education_rounded),
      ClassifiedSubcategory(name: 'Music / Dance / Arts',icon: Icons.music_note_rounded),
    ],
  ),
  LocalFindZone(
    id: 'services',
    label: 'Services',
    icon: Icons.handyman_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Home Services',           icon: Icons.home_repair_service_rounded),
      ClassifiedSubcategory(name: 'Repairs',                 icon: Icons.build_rounded),
      ClassifiedSubcategory(name: 'Maintenance',             icon: Icons.handyman_rounded),
      ClassifiedSubcategory(name: 'Printing',                icon: Icons.insert_drive_file_outlined),
      ClassifiedSubcategory(name: 'Tailoring',               icon: Icons.content_cut_rounded),
      ClassifiedSubcategory(name: 'Photography',             icon: Icons.photo_camera_rounded),
      ClassifiedSubcategory(name: 'Events',                  icon: Icons.stars_rounded),
      ClassifiedSubcategory(name: 'Travel',                  icon: Icons.flight_rounded),
      ClassifiedSubcategory(name: 'Business Services',       icon: Icons.work_rounded),
      ClassifiedSubcategory(name: 'Professional Services',   icon: Icons.work_outline_rounded),
    ],
  ),
  LocalFindZone(
    id: 'auto',
    label: 'Auto',
    icon: Icons.directions_car_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Service',        icon: Icons.build_rounded),
      ClassifiedSubcategory(name: 'Repairs',        icon: Icons.handyman_rounded),
      ClassifiedSubcategory(name: 'Accessories',    icon: Icons.category_rounded),
      ClassifiedSubcategory(name: 'Spare Parts',    icon: Icons.settings_outlined),
      ClassifiedSubcategory(name: 'Car Wash',       icon: Icons.water_drop_rounded),
      ClassifiedSubcategory(name: 'Detailing',      icon: Icons.stars_rounded),
      ClassifiedSubcategory(name: 'Fuel',           icon: Icons.local_fire_department_rounded),
      ClassifiedSubcategory(name: 'EV Charging',    icon: Icons.eco_rounded),
    ],
  ),
  LocalFindZone(
    id: 'stay',
    label: 'Stay',
    icon: Icons.hotel_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Hotels',       icon: Icons.hotel_rounded),
      ClassifiedSubcategory(name: 'Lodges',       icon: Icons.house_rounded),
      ClassifiedSubcategory(name: 'Resorts',      icon: Icons.pool_rounded),
      ClassifiedSubcategory(name: 'Homestays',    icon: Icons.home_rounded),
    ],
  ),
  LocalFindZone(
    id: 'entertain',
    label: 'Entertain',
    icon: Icons.theaters_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Movies',       icon: Icons.movie_rounded),
      ClassifiedSubcategory(name: 'Gaming',       icon: Icons.play_circle_rounded),
      ClassifiedSubcategory(name: 'Kids',         icon: Icons.child_care_rounded),
      ClassifiedSubcategory(name: 'Family',       icon: Icons.people_alt_rounded),
      ClassifiedSubcategory(name: 'Parks',        icon: Icons.eco_rounded),
      ClassifiedSubcategory(name: 'Recreation',   icon: Icons.stars_rounded),
    ],
  ),
  LocalFindZone(
    id: 'fin',
    label: 'Fin',
    icon: Icons.payments_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Insurance',    icon: Icons.shield_rounded),
      ClassifiedSubcategory(name: 'Finance',      icon: Icons.currency_exchange_rounded),
      ClassifiedSubcategory(name: 'Loans',        icon: Icons.payments_rounded),
      ClassifiedSubcategory(name: 'Tax',          icon: Icons.receipt_long_rounded),
      ClassifiedSubcategory(name: 'Investment',   icon: Icons.trending_up_rounded),
    ],
  ),
  LocalFindZone(
    id: 'living',
    label: 'Living',
    icon: Icons.home_rounded,
    subcategories: [
      ClassifiedSubcategory(name: 'Home Cleaning',           icon: Icons.cleaning_services_rounded),
      ClassifiedSubcategory(name: 'Electricians',            icon: Icons.electrical_services_rounded),
      ClassifiedSubcategory(name: 'Plumbers',                icon: Icons.plumbing_rounded),
      ClassifiedSubcategory(name: 'Carpenters',               icon: Icons.chair_rounded),
      ClassifiedSubcategory(name: 'AC & Appliance Repair',   icon: Icons.ac_unit_rounded),
      ClassifiedSubcategory(name: 'Pest Control',            icon: Icons.bug_report_rounded),
    ],
  ),
];

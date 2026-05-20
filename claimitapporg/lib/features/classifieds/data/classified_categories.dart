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

import 'package:flutter/material.dart';

/// One tile on the Claimit Select home grid.
///
/// [id] must match the category ids the backend uses (routes/select.py
/// SELECT_CATEGORIES) — it's what gets sent as ?category= when listing
/// professionals.
class SelectCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const SelectCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// The 12 fixed categories, in the same display order as the design.
/// Kept in sync with SELECT_CATEGORIES in the backend.
const List<SelectCategory> kSelectCategories = [
  SelectCategory(
    id: 'doctors',
    label: 'Doctors',
    icon: Icons.medical_services_rounded,
    color: Color(0xFF2E7DF6),
  ),
  SelectCategory(
    id: 'lawyers',
    label: 'Lawyers',
    icon: Icons.gavel_rounded,
    color: Color(0xFF8B5E3C),
  ),
  SelectCategory(
    id: 'ca_tax',
    label: 'CA & Tax',
    icon: Icons.calculate_rounded,
    color: Color(0xFF0EA5A5),
  ),
  SelectCategory(
    id: 'architects',
    label: 'Architects',
    icon: Icons.architecture_rounded,
    color: Color(0xFF3B82F6),
  ),
  SelectCategory(
    id: 'interior',
    label: 'Interior Designers',
    icon: Icons.chair_rounded,
    color: Color(0xFFEAB308),
  ),
  SelectCategory(
    id: 'tutors',
    label: 'Tutors',
    icon: Icons.school_rounded,
    color: Color(0xFF1E293B),
  ),
  SelectCategory(
    id: 'beauty',
    label: 'Beauty Experts',
    icon: Icons.brush_rounded,
    color: Color(0xFFEC4899),
  ),
  SelectCategory(
    id: 'fitness',
    label: 'Fitness Trainers',
    icon: Icons.fitness_center_rounded,
    color: Color(0xFF2563EB),
  ),
  SelectCategory(
    id: 'photographers',
    label: 'Photographers',
    icon: Icons.photo_camera_rounded,
    color: Color(0xFF334155),
  ),
  SelectCategory(
    id: 'events',
    label: 'Event Planners',
    icon: Icons.celebration_rounded,
    color: Color(0xFFEF4444),
  ),
  SelectCategory(
    id: 'financial',
    label: 'Financial Advisors',
    icon: Icons.trending_up_rounded,
    color: Color(0xFF16A34A),
  ),
  SelectCategory(
    id: 'home_services',
    label: 'Home Services',
    icon: Icons.handyman_rounded,
    color: Color(0xFF0F766E),
  ),
];

/// Looks a category up by id, falling back to the first one so a screen can
/// never be handed a null category.
SelectCategory selectCategoryById(String id) {
  for (final c in kSelectCategories) {
    if (c.id == id) return c;
  }
  return kSelectCategories.first;
}

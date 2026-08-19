import 'package:flutter/material.dart';

/// One tile on the Claimit Select home grid.
///
/// [id] must match the category ids the backend uses (routes/select.py
/// SELECT_CATEGORIES) — it's what gets sent as ?category= when listing
/// professionals.
///
/// [iconAsset] is the client-supplied illustrated icon; [icon] stays as a
/// Material fallback so a missing asset can never leave a blank tile.
class SelectCategory {
  final String id;
  final String label;
  final String iconAsset;
  final IconData icon;
  final Color color;

  const SelectCategory({
    required this.id,
    required this.label,
    required this.iconAsset,
    required this.icon,
    required this.color,
  });
}

/// The 12 fixed categories, in the same display order as the client's icon
/// sheet. Kept in sync with SELECT_CATEGORIES in the backend.
const List<SelectCategory> kSelectCategories = [
  SelectCategory(
    id: 'doctors',
    label: 'Doctors',
    iconAsset: 'assets/images/sel_doctors.png',
    icon: Icons.medical_services_rounded,
    color: Color(0xFFE53935),
  ),
  SelectCategory(
    id: 'lawyers',
    label: 'Lawyers',
    iconAsset: 'assets/images/sel_lawyers.png',
    icon: Icons.gavel_rounded,
    color: Color(0xFF8B5E3C),
  ),
  SelectCategory(
    id: 'ca_tax',
    label: 'CA & Tax',
    iconAsset: 'assets/images/sel_ca_tax.png',
    icon: Icons.calculate_rounded,
    color: Color(0xFF0EA5A5),
  ),
  SelectCategory(
    id: 'architects',
    label: 'Architects',
    iconAsset: 'assets/images/sel_architects.png',
    icon: Icons.architecture_rounded,
    color: Color(0xFF3B82F6),
  ),
  SelectCategory(
    id: 'interior',
    label: 'Interiors',
    iconAsset: 'assets/images/sel_interior.png',
    icon: Icons.chair_rounded,
    color: Color(0xFFEAB308),
  ),
  SelectCategory(
    id: 'financial',
    label: 'Financial Advisors',
    iconAsset: 'assets/images/sel_financial.png',
    icon: Icons.trending_up_rounded,
    color: Color(0xFF16A34A),
  ),
  SelectCategory(
    id: 'business',
    label: 'Business Consultants',
    iconAsset: 'assets/images/sel_business.png',
    icon: Icons.business_center_rounded,
    color: Color(0xFF8B5E3C),
  ),
  SelectCategory(
    id: 'real_estate',
    label: 'Real Estate',
    iconAsset: 'assets/images/sel_real_estate.png',
    icon: Icons.home_work_rounded,
    color: Color(0xFF2563EB),
  ),
  SelectCategory(
    id: 'marketing',
    label: 'Marketing Experts',
    iconAsset: 'assets/images/sel_marketing.png',
    icon: Icons.campaign_rounded,
    color: Color(0xFFEF4444),
  ),
  SelectCategory(
    id: 'it_ai',
    label: 'IT & AI Experts',
    iconAsset: 'assets/images/sel_it_ai.png',
    icon: Icons.memory_rounded,
    color: Color(0xFF0EA5A5),
  ),
  SelectCategory(
    id: 'career',
    label: 'Career Consultants',
    iconAsset: 'assets/images/sel_career.png',
    icon: Icons.school_rounded,
    color: Color(0xFF7C3AED),
  ),
  SelectCategory(
    id: 'events',
    label: 'Event Planners',
    iconAsset: 'assets/images/sel_events.png',
    icon: Icons.celebration_rounded,
    color: Color(0xFFEF4444),
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

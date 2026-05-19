import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ShopCategory — passed via GoRouter extra when navigating to ShopListScreen
// ─────────────────────────────────────────────────────────────────────────────

class ShopCategory {
  final int id;
  final String name;
  final IconData icon;
  final Color color;

  const ShopCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

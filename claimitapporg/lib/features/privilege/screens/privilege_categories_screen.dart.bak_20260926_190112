import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/privilege_models.dart';
import '../widgets/privilege_common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The Categories tab — all nine, as a full-width list rather than the home
// screen's compact 3x3 grid. Same destinations, more room for the longer
// labels ("Healthcare, Dental & Wellness" wraps awkwardly in a small tile).
// ─────────────────────────────────────────────────────────────────────────────

class PrivilegeCategoriesScreen extends StatelessWidget {
  const PrivilegeCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrivBg,
      appBar: const PrivilegeHeader(),
      bottomNavigationBar: const PrivilegeBottomBar(current: 1),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        itemCount: kPrivilegeCategories.length,
        itemBuilder: (_, i) {
          final c = kPrivilegeCategories[i];
          return InkWell(
            onTap: () =>
                context.push('/privilege/list', extra: {'category': c}),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kPrivLine),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: Image.asset(
                      c.iconAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          Icon(c.icon, size: 28, color: c.color),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      c.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: kPrivInk),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 22, color: kPrivMuted),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

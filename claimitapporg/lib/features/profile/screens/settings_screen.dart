import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 26, color: Color(0xFF1A1A2E)),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsCard(
            children: [
              // Dark Mode (toggle) — wired to ThemeProvider for app-wide effect
              _ToggleTile(
                icon: Icons.dark_mode_outlined,
                iconColor: const Color(0xFF2563EB),
                label: 'Dark Mode',
                value: themeProvider.isDark,
                onChanged: (val) => context.read<ThemeProvider>().setDark(val),
              ),
              _divider(),
              // Privacy & Security
              _NavTile(
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFF2563EB),
                label: 'Privacy & Security',
                onTap: () => context.push('/privacy-policy'),
              ),
              _divider(),
              // Terms & Conditions
              _NavTile(
                icon: Icons.description_outlined,
                iconColor: const Color(0xFF2563EB),
                label: 'Terms & Conditions',
                onTap: () => context.push('/terms'),
              ),
              _divider(),
              // Refund Policy
              _NavTile(
                icon: Icons.currency_exchange_rounded,
                iconColor: const Color(0xFF2563EB),
                label: 'Refund Policy',
                onTap: () => context.push('/refund-policy'),
              ),
              _divider(),
              // Payment History
              _NavTile(
                icon: Icons.credit_card_outlined,
                iconColor: const Color(0xFF2563EB),
                label: 'Payment History',
                onTap: () => _showComingSoon(context, 'Payment History'),
              ),
              _divider(),
              // Help & Support
              _NavTile(
                icon: Icons.help_outline_rounded,
                iconColor: const Color(0xFF2563EB),
                label: 'Help & Support',
                onTap: () => context.push('/support'),
              ),
              _divider(),
              // Feedback & Complaints
              _NavTile(
                icon: Icons.feedback_outlined,
                iconColor: const Color(0xFF2563EB),
                label: 'Feedback & Complaints',
                onTap: () => context.push('/feedback'),
              ),
              _divider(),
              // Language
              _NavTile(
                icon: Icons.language_rounded,
                iconColor: const Color(0xFF2563EB),
                label: 'Language',
                onTap: () => _showComingSoon(context, 'Language'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Logout button
          ElevatedButton(
            onPressed: () => _confirmLogout(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 52, endIndent: 0);

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<AuthProvider>().logout();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _iconBox(icon, iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A2E)),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _iconBox(icon, iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E)),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF), size: 20),
          ],
        ),
      ),
    );
  }
}

Widget _iconBox(IconData icon, Color color) {
  return Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, size: 18, color: color),
  );
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/classified_post.dart';

class ClassifiedDetailScreen extends StatefulWidget {
  final ClassifiedPost post;
  const ClassifiedDetailScreen({super.key, required this.post});

  @override
  State<ClassifiedDetailScreen> createState() => _ClassifiedDetailScreenState();
}

class _ClassifiedDetailScreenState extends State<ClassifiedDetailScreen> {
  int _photoIndex = 0;

  ClassifiedPost get p => widget.post;

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF059669),
      const Color(0xFFD97706),
      const Color(0xFFDC2626),
      const Color(0xFF7C3AED),
      const Color(0xFF0891B2),
    ];
    final index = name.isEmpty ? 0 : name.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  Future<void> _call() async {
    if (p.userPhone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: p.userPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsapp() async {
    if (p.userPhone.isEmpty) return;
    final phone = p.userPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/91$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = p.photos.isNotEmpty;
    final initials = p.userName.isNotEmpty ? p.userName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ── App bar / photo hero ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: hasPhotos ? 300 : 180,
            pinned: true,
            backgroundColor: const Color(0xFF1E40AF),
            leading: IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: hasPhotos
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        // Photo
                        PageView.builder(
                          itemCount: p.photos.length,
                          onPageChanged: (i) =>
                              setState(() => _photoIndex = i),
                          itemBuilder: (_, i) {
                            try {
                              return Image.memory(
                                base64Decode(p.photos[i]),
                                fit: BoxFit.cover,
                              );
                            } catch (_) {
                              return _AvatarHero(
                                  initials: initials,
                                  color: _avatarColor(p.userName));
                            }
                          },
                        ),
                        // Page dots
                        if (p.photos.length > 1)
                          Positioned(
                            bottom: 12,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(p.photos.length, (i) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 3),
                                  width: _photoIndex == i ? 18 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: _photoIndex == i
                                        ? Colors.white
                                        : Colors.white54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              }),
                            ),
                          ),
                      ],
                    )
                  : _AvatarHero(
                      initials: initials,
                      color: _avatarColor(p.userName),
                    ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Name + availability ─────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.userName.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Availability pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: p.isAvailable
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: p.isAvailable
                                        ? const Color(0xFF22C55E)
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  p.isAvailable ? 'Available' : 'Unavailable',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: p.isAvailable
                                        ? const Color(0xFF16A34A)
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Quick stats row ─────────────────────────────────
                      Row(
                        children: [
                          _StatChip(
                            icon: Icons.work_history_rounded,
                            label: p.yearsOfExp > 0
                                ? '${p.yearsOfExp}+ yrs exp'
                                : 'Experienced',
                            color: const Color(0xFF7C3AED),
                            bg: const Color(0xFFF5F3FF),
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            icon: Icons.currency_rupee_rounded,
                            label: p.price > 0
                                ? '₹${p.price.toStringAsFixed(0)}/day'
                                : 'Negotiable',
                            color: const Color(0xFF059669),
                            bg: const Color(0xFFECFDF5),
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            icon: Icons.category_rounded,
                            label: p.subcategory,
                            color: const Color(0xFF0891B2),
                            bg: const Color(0xFFECFEFF),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Location ────────────────────────────────────────────────
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(
                          icon: Icons.location_on_rounded, label: 'Location'),
                      const SizedBox(height: 10),
                      if (p.address.isNotEmpty)
                        _InfoRow(
                            icon: Icons.home_rounded, text: p.address),
                      _InfoRow(
                          icon: Icons.map_rounded,
                          text: '${p.area}, ${p.pincode}'),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── About ───────────────────────────────────────────────────
                if (p.description.isNotEmpty)
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(
                            icon: Icons.info_outline_rounded,
                            label: 'About'),
                        const SizedBox(height: 10),
                        Text(
                          p.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (p.description.isNotEmpty) const SizedBox(height: 8),

                // ── Payment ─────────────────────────────────────────────────
                if (p.paymentMethod.isNotEmpty)
                  _SectionCard(
                    child: Row(
                      children: [
                        const Icon(Icons.payment_rounded,
                            color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 10),
                        const Text(
                          'Payment: ',
                          style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500),
                        ),
                        Text(
                          p.paymentMethod,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Bottom spacing for the sticky button
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),

      // ── Sticky bottom action bar ────────────────────────────────────────
      bottomNavigationBar: Container(
        padding:
            const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            // WhatsApp button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _whatsapp,
                icon: const Icon(Icons.chat_rounded, size: 28),
                label: const Text('WhatsApp'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366),
                  side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Call button
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _call,
                icon: const Icon(Icons.call_rounded, size: 28),
                label: Text(
                  p.userPhone.isNotEmpty ? 'Call ${p.userPhone}' : 'Call Now',
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarHero extends StatelessWidget {
  const _AvatarHero({required this.initials, required this.color});
  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 72,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.icon,
      required this.label,
      required this.color,
      required this.bg});
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2563EB)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF475569), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

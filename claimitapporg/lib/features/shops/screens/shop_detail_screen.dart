import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'shop_list_screen.dart'; // ShopItem lives here

// ─────────────────────────────────────────────────────────────────────────────
// ShopDetailScreen — landing page opened when a shop card is tapped
// ─────────────────────────────────────────────────────────────────────────────

class ShopDetailScreen extends StatefulWidget {
  final ShopItem shop;
  const ShopDetailScreen({super.key, required this.shop});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  bool _isFav = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.shop;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Hero image app bar ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 270,
            pinned: true,
            backgroundColor: const Color(0xFF2563EB),
            leading: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF2563EB), size: 18),
              ),
            ),
            actions: [
              // Favourite toggle
              GestureDetector(
                onTap: () => setState(() => _isFav = !_isFav),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isFav ? Colors.redAccent : const Color(0xFF9CA3AF),
                    size: 20,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: s.imageData != null && s.imageData!.isNotEmpty
                  ? Image.memory(
                      base64Decode(s.imageData!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _heroFallback(s),
                    )
                  : _heroFallback(s),
            ),
          ),

          // ── Main content ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Name + discount badge ──────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          s.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: const Color(0xFF2563EB)),
                        ),
                        child: Text(
                          '${s.discount}% OFF',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Location + rating ──────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 14, color: Color(0xFF6B7280)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          s.location,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.star_rounded,
                          size: 15, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        s.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Rewards / Redeem availability tags ─────────────────
                  Row(
                    children: [
                      if (s.hasRewards)
                        _Tag(
                          label: 'Rewards',
                          icon: Icons.card_giftcard_rounded,
                          color: const Color(0xFF10B981),
                        ),
                      if (s.hasRewards && s.hasRedeem)
                        const SizedBox(width: 8),
                      if (s.hasRedeem)
                        _Tag(
                          label: 'Redeem',
                          icon: Icons.redeem_rounded,
                          color: const Color(0xFF2563EB),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Offer highlight card ───────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.local_offer_rounded,
                                color: Color(0xFFFFD93D), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Exclusive Offer',
                              style: TextStyle(
                                color: Color(0xFFFFD93D),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${s.discount}% OFF on all eligible purchases',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '+ 1% Cashback credited instantly to your wallet',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── How it works ───────────────────────────────────────
                  const Text(
                    'How it works',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Step(
                    step: '1',
                    text: 'Shop at ${s.name} and collect your bill',
                    color: const Color(0xFF2563EB),
                  ),
                  _Step(
                    step: '2',
                    text: 'Open claimit and tap "Scan Bill"',
                    color: const Color(0xFF10B981),
                  ),
                  _Step(
                    step: '3',
                    text: 'Points credited instantly to your account',
                    color: const Color(0xFFF59E0B),
                  ),
                  _Step(
                    step: '4',
                    text: 'Redeem points at any claimit partner store',
                    color: const Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 20),

                  // ── Store details ──────────────────────────────────────
                  const Text(
                    'Store details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (s.address.isNotEmpty)
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: s.address,
                    ),
                  if (s.phone.isNotEmpty)
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: s.phone,
                    ),
                  if (s.timing.isNotEmpty)
                    _InfoRow(
                      icon: Icons.access_time_rounded,
                      label: 'Timings',
                      value: s.timing,
                    ),
                  _InfoRow(
                    icon: Icons.trending_down_rounded,
                    label: 'Added',
                    value: s.addedDaysAgo == 0
                        ? 'Today'
                        : s.addedDaysAgo == 1
                            ? 'Yesterday'
                            : '${s.addedDaysAgo} days ago',
                  ),
                  const SizedBox(height: 28),

                  // ── CTAs ──────────────────────────────────────────────
                  if (s.hasRewards) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.document_scanner_outlined,
                            size: 20),
                        label: const Text(
                          'Scan Bill & Earn Rewards',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (s.hasRedeem)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.redeem_rounded, size: 20),
                        label: const Text(
                          'Redeem Points Here',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(
                              color: Color(0xFF2563EB), width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Tag(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String step;
  final String text;
  final Color color;
  const _Step(
      {required this.step, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero image fallback
// ─────────────────────────────────────────────────────────────────────────────
Widget _heroFallback(shop) => Container(
  color: shop.fallbackColor,
  alignment: Alignment.center,
  child: Icon(shop.fallbackIcon, color: const Color(0xFF9CA3AF), size: 72),
);

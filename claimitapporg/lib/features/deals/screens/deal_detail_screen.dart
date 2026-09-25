import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../deals/models/deal_model.dart';

class DealDetailScreen extends StatefulWidget {
  final DealData deal;
  const DealDetailScreen({super.key, required this.deal});

  @override
  State<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends State<DealDetailScreen> {
  // ── Image carousel ────────────────────────────────────────────────────────
  // Same behaviour as the shop landing page: swipe between up to 4 photos,
  // auto-advance every 4 seconds, dots underneath. A deal with one image
  // behaves exactly as it did before — no pager, no dots, no timer.
  final PageController _imgCtrl = PageController();
  int _currentImg = 0;
  Timer? _imgTimer;

  /// Cover first, then the extras. Falls back to the single thumbnail for
  /// deals created before galleries existed, so nothing needs backfilling.
  List<String> get _images {
    final gallery =
        widget.deal.imageUrls.where((s) => s.trim().isNotEmpty).toList();
    if (gallery.isNotEmpty) return gallery;
    if (widget.deal.imageUrl.trim().isNotEmpty) return [widget.deal.imageUrl];
    return const [];
  }

  @override
  void initState() {
    super.initState();
    if (_images.length > 1) {
      _imgTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || !_imgCtrl.hasClients) return;
        final next = (_currentImg + 1) % _images.length;
        _imgCtrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    // Both must go, or the timer keeps firing against a disposed controller
    // after the user navigates away.
    _imgTimer?.cancel();
    _imgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.deal;
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Hero image app bar ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
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
            flexibleSpace: FlexibleSpaceBar(
              background: _buildCarousel(d),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + type chip (chip hidden when type is empty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          d.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (d.type.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF2563EB)),
                          ),
                          child: Text(
                            d.type,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Location + distance (distance hidden when empty)
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 15, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          d.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      ),
                      if (d.distance.isNotEmpty) ...[
                        const SizedBox(width: 1),
                        const Icon(Icons.directions_walk_rounded,
                            size: 26, color: Color(0xFF2563EB)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            d.distance,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Offer highlight card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
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
                              'OFFER',
                              style: TextStyle(
                                color: Color(0xFFFFD93D),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          d.offer,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // const Text(
                        //   '+ 1% Cashback on every purchase',
                        //   style: TextStyle(
                        //     color: Colors.white70,
                        //     fontSize: 12,
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // About / Offer Details — only shown when non-empty
                  if (d.description.isNotEmpty) ...[
                    const Text(
                      'Offer Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      d.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4B5563),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Info rows — only shown when value is non-empty
                  if (d.address.isNotEmpty)
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: d.address,
                    ),
                  if (d.phone.isNotEmpty)
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: d.phone,
                    ),
                  if (d.timing.isNotEmpty)
                    _InfoRow(
                      icon: Icons.access_time_rounded,
                      label: 'Timings',
                      value: d.timing,
                    ),

                  // Rating — only shown when reviews > 0
                  if (d.reviews > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFF59E0B), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          d.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${d.reviews} reviews)',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Scan bill CTA button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    // child: ElevatedButton.icon(
                    //   onPressed: () {},
                    //   icon: const Icon(Icons.document_scanner_outlined,
                    //       size: 28),
                    //   label: const Text(
                    //     'Scan Bill & Earn Rewards',
                    //     style: TextStyle(
                    //         fontSize: 16, fontWeight: FontWeight.bold),
                    //   ),
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: const Color(0xFF2563EB),
                    //     foregroundColor: Colors.white,
                    //     shape: RoundedRectangleBorder(
                    //       borderRadius: BorderRadius.circular(30),
                    //     ),
                    //     elevation: 0,
                    //   ),
                    // ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Carousel ──────────────────────────────────────────────────────────────
  // Deliberately the same shape as the shop landing page: a PageView filling
  // the FlexibleSpaceBar, dots pinned to the bottom, and no pager at all when
  // there is a single image. The UI is unchanged for one-image deals.
  Widget _buildCarousel(DealData d) {
    final images = _images;
    if (images.isEmpty) return _fallback(d);

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _imgCtrl,
          itemCount: images.length,
          onPageChanged: (i) => setState(() => _currentImg = i),
          itemBuilder: (_, i) => CachedNetworkImage(
            imageUrl: images[i],
            fit: BoxFit.cover,
            placeholder: (_, __) => _fallback(d),
            errorWidget: (_, __, ___) => _fallback(d),
          ),
        ),

        // Dots. Only drawn for a real gallery — a lone dot under a single
        // photo just looks like a smudge.
        if (images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final active = i == _currentImg;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  /// Shown while an image loads, when one fails, and when a deal has no
  /// photo at all — so the hero area is never blank or broken.
  Widget _fallback(DealData d) => Container(
        color: d.fallbackColor,
        child: Icon(d.fallbackIcon, color: const Color(0xFF9CA3AF), size: 60),
      );
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
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF374151))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

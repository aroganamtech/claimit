// ─────────────────────────────────────────────────────────────────────────────
// What a paid Spot Promo opens when the card is tapped.
//
// A Spot Promo is an advertiser's booking, not a Local Finder listing, a
// Select professional or a Privilege partner — so there is no existing detail
// route it can push. Rather than invent three screens, or leave the card dead
// to the touch, it opens this sheet: the promo's own details, in the app, with
// a Call button when a number was supplied.
//
// Deliberately NOT a web link. The ad carries a `cta_link` the advertiser
// typed, and sending a user straight out to an unvetted URL from a tap is a
// different decision with a different risk, so that field is shown as text
// the user can read before deciding, never auto-opened.
//
// Shared by all three pages for the same reason the card and the service are:
// one Spot Promo looks and behaves the same wherever it appears.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/spot_promo_service.dart';

Future<void> showSpotPromoSheet(
  BuildContext context,
  SpotPromoDto promo, {
  required Color accent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SpotPromoSheet(promo: promo, accent: accent),
  );
}

class _SpotPromoSheet extends StatelessWidget {
  final SpotPromoDto promo;
  final Color accent;

  const _SpotPromoSheet({required this.promo, required this.accent});

  Future<void> _call() async {
    final p = promo.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (p.isEmpty) return;
    await launchUrl(Uri.parse('tel:$p'));
  }

  @override
  Widget build(BuildContext context) {
    // Capped so a long description scrolls inside the sheet instead of
    // pushing the Call button off the bottom of the screen.
    final maxH = MediaQuery.of(context).size.height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (promo.imageUrl.startsWith('http'))
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: promo.imageUrl,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 160,
                    color: accent.withOpacity(0.08),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 160,
                    color: accent.withOpacity(0.08),
                    alignment: Alignment.center,
                    child: Icon(Icons.storefront_rounded,
                        size: 34, color: accent.withOpacity(0.5)),
                  ),
                ),
              ),
            if (promo.imageUrl.startsWith('http')) const SizedBox(height: 14),

            // Labelled as paid placement. An advertiser's card sitting among
            // organic listings has to say so — the user is entitled to know
            // which of these is an ad.
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('Sponsored',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accent)),
                ),
                if (promo.isPremium) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4D6),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text('PREMIUM',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8A6100))),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            Text(promo.name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),

            if (promo.offer.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(promo.offer,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: accent)),
            ],

            if (promo.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(promo.description,
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.5, color: Color(0xFF444444))),
            ],

            const SizedBox(height: 14),
            _row(Icons.place_outlined,
                promo.address.isNotEmpty ? promo.address : promo.location),
            _row(Icons.category_outlined, promo.category),
            _row(Icons.access_time_rounded, promo.timing),
            _row(Icons.near_me_outlined, promo.distance),
            _row(Icons.link_rounded, promo.ctaLink),

            if (promo.phone.isNotEmpty) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _call,
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// One detail line, or nothing at all when the field is empty — so a promo
  /// with no timing doesn't leave a stray clock icon behind.
  Widget _row(IconData icon, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF888888)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, height: 1.45, color: Color(0xFF555555))),
          ),
        ],
      ),
    );
  }
}

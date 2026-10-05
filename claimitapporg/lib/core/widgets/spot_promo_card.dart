import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The "Spot Promos" card.
//
// A faithful duplicate of the Nearby/Brand Deals card in
// features/deals/screens/deal_list_screen.dart — same 120px full-height image,
// same IntrinsicHeight row, same shadow, same type scale, and the same five
// pieces of content: name, location, offer, distance, category.
//
// It lives here rather than inside one feature because Local Finder, Select
// and Privilege all draw it. Three copies would drift the first time one was
// adjusted — which is exactly how the bottom bars ended up looking different
// from one another.
//
// Each caller maps its own model onto [SpotPromo]; nothing model-specific
// belongs in this file.
// ─────────────────────────────────────────────────────────────────────────────

/// One card's worth of content, independent of which feature produced it.
class SpotPromo {
  final String id;
  final String name;

  /// Address, or "Area, City" — the line under the name.
  final String location;

  /// What is on offer: "Up to 15% off", "20% OFF", "Premium partner".
  /// Empty is fine; the line is simply left out.
  final String offer;

  /// "1.2 km". Empty when GPS was off, in which case the badge is dropped.
  final String distance;

  /// Category label for the right-hand badge.
  final String category;

  /// An http(s) URL (bulk/S3 upload) or a raw base64 string (posted from the
  /// app). Both occur in the same field, so both are handled.
  final String image;

  /// Draws the gold PREMIUM chip before the name.
  final bool isPremium;

  /// Glyph shown when there is no usable photo.
  final IconData fallbackIcon;

  const SpotPromo({
    required this.id,
    required this.name,
    required this.location,
    required this.offer,
    required this.distance,
    required this.category,
    required this.image,
    this.isPremium = false,
    this.fallbackIcon = Icons.storefront_rounded,
  });
}

class SpotPromoCard extends StatelessWidget {
  final SpotPromo promo;

  /// The feature's colour — tints the image placeholder so a slow or missing
  /// photo still reads as part of that product.
  final Color accent;

  final bool isFavourite;

  /// Omit to hide the heart entirely.
  final VoidCallback? onFavourite;

  final VoidCallback onTap;

  const SpotPromoCard({
    super.key,
    required this.promo,
    required this.onTap,
    this.accent = const Color(0xFF1565C0),
    this.isFavourite = false,
    this.onFavourite,
  });

  @override
  Widget build(BuildContext context) {
    final p = promo;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            // stretch → the image fills the full card height, no white gap
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                child: SizedBox(width: 120, child: _image(p)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.isPremium) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 6, top: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: const Color(0xFFFBBF24), width: 1),
                              ),
                              child: const Text(
                                'PREMIUM',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          if (onFavourite != null)
                            GestureDetector(
                              onTap: onFavourite,
                              child: Icon(
                                isFavourite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 28,
                                color: isFavourite
                                    ? Colors.redAccent
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (p.location.isNotEmpty) ...[
                        Text(
                          p.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 5),
                      ],
                      if (p.offer.isNotEmpty) ...[
                        Text(
                          p.offer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 7),
                      ],
                      Row(
                        children: [
                          if (p.distance.isNotEmpty) ...[
                            _badge(p.distance, const Color(0xFFF3F4F6),
                                const Color(0xFF374151)),
                            const SizedBox(width: 6),
                          ],
                          if (p.category.isNotEmpty)
                            // Flexible so a long category shrinks instead of
                            // pushing the row past the card edge.
                            Flexible(
                              child: _badge(p.category, const Color(0xFFEFF6FF),
                                  const Color(0xFF2563EB)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Three kinds of value reach this field across the four products, so all
  /// three are handled rather than assuming a URL: an http(s) link from a
  /// bulk/S3 upload, a raw base64 string from a listing posted in the app, or
  /// nothing at all.
  Widget _image(SpotPromo p) {
    final raw = p.image.trim();
    if (raw.isEmpty) return _fallback(p);

    if (raw.startsWith('http')) {
      return Container(
        decoration: BoxDecoration(
          color: accent.withOpacity(0.10),
          image: DecorationImage(
            image: CachedNetworkImageProvider(raw),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    try {
      return Image.memory(
        base64Decode(raw),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(p),
      );
    } catch (_) {
      return _fallback(p);
    }
  }

  Widget _fallback(SpotPromo p) => Container(
        color: accent.withOpacity(0.10),
        alignment: Alignment.center,
        child: Icon(p.fallbackIcon, size: 36, color: accent.withOpacity(0.55)),
      );

  Widget _badge(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
        ),
      );
}

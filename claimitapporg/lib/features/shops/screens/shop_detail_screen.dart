import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../profile/providers/profile_provider.dart';
import '../services/shop_service.dart';
import 'shop_list_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ShopDetailScreen
// ─────────────────────────────────────────────────────────────────────────────

class ShopDetailScreen extends StatefulWidget {
  final ShopItem shop;
  const ShopDetailScreen({super.key, required this.shop});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  static const _blue = Color(0xFF2563EB);

  bool _isFav = false;
  bool _toggling = false;

  // ── Image carousel ───────────────────────────────────────────────────────
  late final PageController _imgPageCtrl;
  int _currentImg = 0;
  Timer? _imgTimer;

  // Reviews
  List<ShopReview> _reviews = [];
  double _avgRating = 0;
  int _totalReviews = 0;
  bool _loadingReviews = true;

  // Nearby shops
  List<ShopItem> _nearbyShops = [];
  bool _loadingNearby = true;

  // Write-review state
  double _myRating = 0;
  final _reviewCtrl = TextEditingController();
  bool _submitting = false;

  // Full shop fetched from detail endpoint (includes gallery)
  ShopItem? _fullShop;

  // Effective image list: prefer gallery from full shop, then cover
  List<String> get _images {
    final shop = _fullShop ?? widget.shop;
    final list = shop.imageDataList.where((s) => s.isNotEmpty).toList();
    if (list.isNotEmpty) return list;
    final single = shop.imageData;
    if (single != null && single.isNotEmpty) return [single];
    return [];
  }

  @override
  void initState() {
    super.initState();
    _imgPageCtrl = PageController();
    _isFav = context.read<ProfileProvider>().isLiked(widget.shop.id);
    _loadReviews();
    _loadNearbyShops();
    _fetchFullShop();
    // Auto-scroll images every 4 seconds (only when more than one image)
    if (_images.length > 1) {
      _imgTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!_imgPageCtrl.hasClients) return;
        final next = (_currentImg + 1) % _images.length;
        _imgPageCtrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _imgTimer?.cancel();
    _imgPageCtrl.dispose();
    _reviewCtrl.dispose();
    super.dispose();
  }

  /// Re-fetch the full shop from /shops/{id} to get image_data_list (gallery).
  /// The list screen only passes cover image; detail endpoint includes gallery.
  Future<void> _fetchFullShop() async {
    final full = await ShopService.instance.fetchShopById(widget.shop.id);
    if (!mounted || full == null) return;
    setState(() {
      _fullShop = full;
      // Restart auto-scroll timer if gallery has multiple images
      _imgTimer?.cancel();
      if (_images.length > 1) {
        _imgTimer = Timer.periodic(const Duration(seconds: 4), (_) {
          if (!_imgPageCtrl.hasClients) return;
          final next = (_currentImg + 1) % _images.length;
          _imgPageCtrl.animateToPage(next,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut);
        });
      }
    });
  }

  Future<void> _loadReviews() async {
    setState(() => _loadingReviews = true);
    final result = await ShopService.instance.fetchShopReviews(widget.shop.id);
    if (!mounted) return;
    setState(() {
      _reviews = result.reviews;
      _avgRating = result.avgRating > 0
          ? result.avgRating
          : widget.shop.rating;
      _totalReviews = result.total > 0
          ? result.total
          : widget.shop.reviewCount;
      _loadingReviews = false;
    });
  }

  Future<void> _loadNearbyShops() async {
    setState(() => _loadingNearby = true);
    List<ShopItem> shops = [];

    // Prefer GPS-radius search when shop has coordinates
    final shopLat = widget.shop.lat;
    final shopLng = widget.shop.lng;

    if (shopLat != null && shopLng != null) {
      // Use the shop's GPS position as the centre → show stores within 4 km
      shops = await ShopService.instance.fetchNearbyShops(
        lat: shopLat,
        lng: shopLng,
        radiusKm: 4.0,
        excludeId: widget.shop.id,
      );
    } else {
      // Fallback: area-text match (for shops without GPS coords in DB)
      final area = widget.shop.location.split(',').first.trim();
      shops = await ShopService.instance.fetchShopsNearArea(
        area: area,
        excludeId: widget.shop.id,
        limit: 6,
      );
    }

    if (!mounted) return;
    setState(() {
      _nearbyShops = shops.take(6).toList();
      _loadingNearby = false;
    });
  }

  Future<void> _toggleFav() async {
    if (_toggling) return;
    setState(() => _toggling = true);
    final s = widget.shop;
    final nowLiked = await context.read<ProfileProvider>().toggleFavourite(
          s.id,
          name: s.name,
          location: s.location,
          imageData: s.imageData,
          discount: s.discount,
          rating: s.rating,
        );
    if (mounted) setState(() { _isFav = nowLiked; _toggling = false; });
  }

  Future<void> _submitReview() async {
    if (_myRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating first')),
      );
      return;
    }
    if (_reviewCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a review')),
      );
      return;
    }
    setState(() => _submitting = true);
    final ok = await ShopService.instance.submitReview(
      shopId: widget.shop.id,
      rating: _myRating,
      comment: _reviewCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      _reviewCtrl.clear();
      setState(() => _myRating = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Review submitted! Thank you.'),
            backgroundColor: Color(0xFF10B981)),
      );
      _loadReviews(); // refresh
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to submit review. Please try again.'),
            backgroundColor: Color(0xFFEF4444)),
      );
    }
  }

  Future<void> _openDirections() async {
    final s = widget.shop;
    Uri uri;

    if (s.lat != null && s.lng != null) {
      // Open exact GPS coordinates in Google Maps
      uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${s.lat},${s.lng}&travelmode=driving');
    } else {
      // Fall back to searching by shop name + location
      final query = Uri.encodeComponent('${s.name}, ${s.location}');
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$query');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps')),
        );
      }
    }
  }

  void _redeemNow() {
    context.push('/redeem-loading', extra: widget.shop);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s = widget.shop;
    final avgDisplay = _avgRating > 0 ? _avgRating : s.rating;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar with image carousel ────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: _blue,
            leading: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _blue, size: 18),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: _toggleFav,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
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
              background: _buildImageCarousel(s),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Category label ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Text(
                    'Redeem+ Shop',
                    style: TextStyle(
                      fontSize: 13,
                      color: _blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // ── Name + rating badge ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(s.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            )),
                      ),
                      if (avgDisplay > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 3),
                              Text(avgDisplay.toStringAsFixed(1),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Location ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 26, color: Color(0xFF6B7280)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(s.location,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF6B7280))),
                      ),
                    ],
                  ),
                ),

                // ── Offer description ──────────────────────────────────────
                if (s.address.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Text(
                      s.address,
                      style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                          height: 1.5),
                    ),
                  ),

                // ── Offer chips — one row per mode the shop supports ───────
                if (s.hasRedeem && s.discount > 0)
                  // Redeem shop: owner accepts points → user gets X% off + 1% cashback
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Row(
                      children: [
                        _OfferChip(
                          label: '${s.discount}% Discount',
                          bg: const Color(0xFFFFF7ED),
                          border: const Color(0xFFFB923C),
                          fg: const Color(0xFFC2410C),
                        ),
                        const SizedBox(width: 8),
                        const _OfferChip(
                          label: '+ 1% Cashback',
                          bg: Color(0xFFECFDF5),
                          border: Color(0xFF6EE7B7),
                          fg: Color(0xFF065F46),
                        ),
                      ],
                    ),
                  ),
                if (s.hasRewards)
                  // Reward shop: user scans bill → earns reward points + 1% cashback
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        20, (s.hasRedeem && s.discount > 0) ? 8 : 14, 20, 0),
                    child: Row(
                      children: const [
                        _OfferChip(
                          label: 'Free Reward Points',
                          bg: Color(0xFFEFF6FF),
                          border: Color(0xFF93C5FD),
                          fg: Color(0xFF1D4ED8),
                        ),
                        SizedBox(width: 8),
                        _OfferChip(
                          label: '+ 1% Cashback',
                          bg: Color(0xFFECFDF5),
                          border: Color(0xFF6EE7B7),
                          fg: Color(0xFF065F46),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // ── Redeem Now button ──────────────────────────────────────
                if (s.hasRedeem)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _redeemNow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: 0,
                        ),
                        child: const Text('Redeem Now',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // ── Get Direction button ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _openDirections,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _blue,
                        side:
                            const BorderSide(color: _blue, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Get Direction',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Contact info ───────────────────────────────────────────
                if (s.phone.isNotEmpty)
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    text: s.phone,
                    onTap: () => launchUrl(
                        Uri.parse('tel:${s.phone}'),
                        mode: LaunchMode.externalApplication),
                  ),
                if (s.email.isNotEmpty)
                  _ContactRow(
                    icon: Icons.email_outlined,
                    text: s.email,
                    onTap: () => launchUrl(
                        Uri.parse('mailto:${s.email}'),
                        mode: LaunchMode.externalApplication),
                  ),

                // ── About section ─────────────────────────────────────────
                if (s.about.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 20),
                  _buildAbout(s.about),
                ],

                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 20),

                // ── Rating summary ─────────────────────────────────────────
                _buildRatingSummary(avgDisplay),

                const SizedBox(height: 16),

                // ── Reviews list ───────────────────────────────────────────
                _buildReviewsList(),

                const SizedBox(height: 16),

                // ── Write a review ─────────────────────────────────────────
                _buildWriteReview(),

                const SizedBox(height: 24),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 16),

                // ── Stores Nearby ──────────────────────────────────────────
                _buildNearbyShops(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Image carousel (used inside FlexibleSpaceBar) ─────────────────────────
  Widget _buildImageCarousel(ShopItem s) {
    final images = _images;
    if (images.isEmpty) return _heroFallback(s);

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Sliding images ──────────────────────────────────────────────────
        PageView.builder(
          controller: _imgPageCtrl,
          itemCount: images.length,
          onPageChanged: (i) => setState(() => _currentImg = i),
          itemBuilder: (ctx, i) {
            try {
              return Image.memory(
                base64Decode(images[i]),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _heroFallback(s),
              );
            } catch (_) {
              return _heroFallback(s);
            }
          },
        ),

        // ── Gradient overlay so dots are readable ───────────────────────────
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            height: 60,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black45, Colors.transparent],
              ),
            ),
          ),
        ),

        // ── Dot indicators (bottom-center) ──────────────────────────────────
        if (images.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _imgPageCtrl,
                count: images.length,
                effect: const WormEffect(
                  dotHeight: 7,
                  dotWidth: 7,
                  activeDotColor: Colors.white,
                  dotColor: Colors.white38,
                  spacing: 6,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── About section ─────────────────────────────────────────────────────────
  Widget _buildAbout(String about) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                'About',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            about,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  // ── Rating summary row ─────────────────────────────────────────────────────
  Widget _buildRatingSummary(double avg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Big rating number
          Text(
            avg.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StarRow(rating: avg, size: 22),
              const SizedBox(height: 4),
              Text(
                '$_totalReviews reviews',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Reviews list ──────────────────────────────────────────────────────────
  Widget _buildReviewsList() {
    if (_loadingReviews) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
            child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }
    if (_reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text('No reviews yet. Be the first to review!',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
      );
    }
    return Column(
      children: _reviews.map((r) => _ReviewTile(review: r)).toList(),
    );
  }

  // ── Write a review ────────────────────────────────────────────────────────
  Widget _buildWriteReview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Star picker
          Row(
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _myRating = star.toDouble()),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    _myRating >= star
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 30,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // Text field
          TextField(
            controller: _reviewCtrl,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'Write a review',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('Submit Review',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Nearby shops section ──────────────────────────────────────────────────
  Widget _buildNearbyShops() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Stores Nearby',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2563EB),
            ),
          ),
        ),
        if (_loadingNearby)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF2563EB))),
          )
        else if (_nearbyShops.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('No nearby stores found.',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          )
        else
          ...(_nearbyShops
              .map((shop) => _NearbyShopCard(shop: shop))
              .toList()),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Review tile
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewTile extends StatelessWidget {
  final ShopReview review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${_monthName(review.date.month)} ${review.date.day}, ${review.date.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF2563EB).withOpacity(0.12),
            backgroundImage:
                review.userAvatar != null && review.userAvatar!.isNotEmpty
                    ? NetworkImage(review.userAvatar!)
                    : null,
            child:
                review.userAvatar == null || review.userAvatar!.isEmpty
                    ? Text(
                        review.userName.isNotEmpty
                            ? review.userName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.bold),
                      )
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(review.userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF111827))),
                    ),
                    Row(
                      children: [
                        Text(review.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1A1A1A))),
                        const SizedBox(width: 2),
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFF59E0B), size: 16),
                      ],
                    ),
                  ],
                ),
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF))),
                const SizedBox(height: 4),
                Text(review.comment,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF374151),
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _monthName(int m) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Star row widget
// ─────────────────────────────────────────────────────────────────────────────
class _StarRow extends StatelessWidget {
  final double rating;
  final double size;
  const _StarRow({required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final val = i + 1;
        IconData icon;
        if (rating >= val) {
          icon = Icons.star_rounded;
        } else if (rating >= val - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(icon, color: const Color(0xFFF59E0B), size: size);
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Contact row
// ─────────────────────────────────────────────────────────────────────────────
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _ContactRow(
      {required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF2563EB), size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF374151))),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nearby shop card
// ─────────────────────────────────────────────────────────────────────────────
class _NearbyShopCard extends StatelessWidget {
  final ShopItem shop;
  const _NearbyShopCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/shop-detail', extra: shop),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(10),
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
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 70,
                height: 70,
                child: shop.imageData != null && shop.imageData!.isNotEmpty
                    ? Image.memory(
                        base64Decode(shop.imageData!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallback(shop),
                      )
                    : _fallback(shop),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF111827))),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 11, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(shop.location,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF6B7280)),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (shop.distance.isNotEmpty)
                        _Badge(
                            label: shop.distance,
                            bg: const Color(0xFFF3F4F6),
                            fg: const Color(0xFF374151)),
                      _Badge(
                          label: 'Supermarket',
                          bg: const Color(0xFFEFF6FF),
                          fg: const Color(0xFF2563EB)),
                    ],
                  ),
                ],
              ),
            ),
            // Heart
            Consumer<ProfileProvider>(
              builder: (ctx, profile, _) => GestureDetector(
                onTap: () => profile.toggleFavourite(
                  shop.id,
                  name: shop.name,
                  location: shop.location,
                  imageData: shop.imageData,
                  discount: shop.discount,
                  rating: shop.rating,
                ),
                child: Icon(
                  profile.isLiked(shop.id)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 28,
                  color: profile.isLiked(shop.id)
                      ? Colors.redAccent
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(ShopItem s) => Container(
        color: s.fallbackColor,
        alignment: Alignment.center,
        child: Icon(s.fallbackIcon, color: Colors.grey.shade400, size: 26),
      );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero fallback
// ─────────────────────────────────────────────────────────────────────────────
Widget _heroFallback(ShopItem shop) => Container(
      color: shop.fallbackColor,
      alignment: Alignment.center,
      child: Icon(shop.fallbackIcon,
          color: const Color(0xFF9CA3AF), size: 72),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Small offer chip — used for "30% Discount" and "+ 1% Cashback" tags
// ─────────────────────────────────────────────────────────────────────────────
class _OfferChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color border;
  final Color fg;
  const _OfferChip({
    required this.label,
    required this.bg,
    required this.border,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

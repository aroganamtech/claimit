import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../models/reel_model.dart';
import '../services/reel_service.dart';
import '../../shops/services/shop_service.dart';
import '../../shops/screens/shop_list_screen.dart';

class ReelzScreen extends StatefulWidget {
  const ReelzScreen({super.key});

  @override
  State<ReelzScreen> createState() => _ReelzScreenState();
}

class _ReelzScreenState extends State<ReelzScreen> {
  List<ReelItem> _reels = [];
  bool _loading = true;
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _load();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final reels = await ReelService.instance.fetchReels();
    if (mounted) setState(() { _reels = reels; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _reels.isEmpty
              ? const Center(
                  child: Text('No reels yet',
                      style: TextStyle(color: Colors.white70, fontSize: 16)),
                )
              : Stack(
                  children: [
                    PageView.builder(
                      controller: _pageCtrl,
                      scrollDirection: Axis.vertical,
                      physics: const PageScrollPhysics(),
                      itemCount: _reels.length,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      itemBuilder: (context, index) => _ReelPage(
                        reel: _reels[index],
                        isActive: index == _currentPage,
                      ),
                    ),
                    // Back button
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => context.pop(),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: const BoxDecoration(
                                    color: Colors.black38,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Promo Reelz',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  shadows: [
                                    Shadow(color: Colors.black54, blurRadius: 6),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              const SizedBox(width: 38), // balance
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single reel page
// ─────────────────────────────────────────────────────────────────────────────

class _ReelPage extends StatefulWidget {
  const _ReelPage({required this.reel, required this.isActive});
  final ReelItem reel;
  final bool isActive;

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;

  // Like state
  bool _liked = false;
  late int _likeCount;

  // View state
  late int _viewCount;
  bool _viewRecorded = false;

  // Shop loading state
  bool _shopLoading = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.reel.likedByMe;   // restore red heart from server
    _likeCount = widget.reel.likeCount;
    _viewCount = widget.reel.viewCount;
    _initVideo();
  }

  Future<void> _initVideo() async {
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.reel.videoUrl));
    try {
      await _ctrl.initialize();
      _ctrl.setLooping(true);
      if (widget.isActive) {
        _ctrl.play();
        _recordView();
      }
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      debugPrint('Video init error: $e');
      if (mounted) setState(() => _initialized = false);
    }
  }

  @override
  void didUpdateWidget(_ReelPage old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      if (widget.isActive) {
        _ctrl.play();
        _recordView();
      } else {
        _ctrl.pause();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _toggleLike() async {
    // One like per user — once liked, tapping again does nothing.
    if (_liked) return;

    // Optimistic update immediately
    setState(() {
      _liked = true;
      _likeCount += 1;
    });

    // Persist and sync with server
    final result = await ReelService.instance.likeReel(
      widget.reel.id,
      liked: true,
    );
    if (result != null && mounted) {
      // Always trust the server's confirmed state
      setState(() {
        _liked = result.likedByMe;
        _likeCount = result.likeCount;
      });
    }
  }

  Future<void> _recordView() async {
    if (_viewRecorded || widget.reel.id.isEmpty) return;
    _viewRecorded = true;
    final updated = await ReelService.instance.viewReel(widget.reel.id);
    if (updated != null && mounted) {
      setState(() => _viewCount = updated);
    }
  }

  /// Tap shop name → search for matching shop → open ShopDetailScreen
  Future<void> _openShop() async {
    if (_shopLoading) return;
    setState(() => _shopLoading = true);

    try {
      final shops =
          await ShopService.instance.searchShops(widget.reel.shopName);
      if (!mounted) return;

      if (shops.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shop "${widget.reel.shopName}" not found'),
            backgroundColor: Colors.black87,
          ),
        );
        return;
      }

      context.push('/shop-detail', extra: shops.first);
    } catch (e) {
      debugPrint('_openShop error: $e');
    } finally {
      if (mounted) setState(() => _shopLoading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final reel = widget.reel;

    return GestureDetector(
      onTap: () {
        if (_initialized) {
          _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
          setState(() {});
        }
      },
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video / thumbnail background ──────────────────────────────
            if (_initialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _ctrl.value.size.width,
                  height: _ctrl.value.size.height,
                  child: VideoPlayer(_ctrl),
                ),
              )
            else
              Image.network(
                reel.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFF0F172A)),
              ),

            // ── Gradient overlay ──────────────────────────────────────────
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x40000000),
                    Color(0xCC000000),
                  ],
                  stops: [0.0, 0.4, 0.65, 1.0],
                ),
              ),
            ),

            // ── Loading spinner ───────────────────────────────────────────
            if (!_initialized)
              const Center(
                child: CircularProgressIndicator(
                    color: Colors.white70, strokeWidth: 2),
              ),

            // ── Paused icon ───────────────────────────────────────────────
            if (_initialized && !_ctrl.value.isPlaying)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration:
                      const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 52),
                ),
              ),

            // ── Bottom-left: shop info ────────────────────────────────────
            Positioned(
              left: 16,
              right: 76,
              bottom: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Shop name — tappable → opens shop detail
                  GestureDetector(
                    onTap: _openShop,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            reel.shopName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.88),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            reel.tag,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_shopLoading) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Tap hint
                  GestureDetector(
                    onTap: _openShop,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          reel.shopLocation,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white38, width: 0.6),
                          ),
                          child: const Text(
                            'View Shop →',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Offer pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Colors.white38, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_offer_rounded,
                            color: Color(0xFFFBBF24), size: 14),
                        const SizedBox(width: 5),
                        Text(
                          reel.offer,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Caption
                  Text(
                    reel.caption,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ── Right-side action buttons ─────────────────────────────────
            Positioned(
              right: 12,
              bottom: 44,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Shop avatar circle
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      color: const Color(0xFF2563EB),
                    ),
                    child: const Icon(Icons.storefront_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 24),

                  // ── Like (one-time per user) ──────────────────────────────
                  _ActionBtn(
                    icon: _liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _liked ? Colors.redAccent : Colors.white,
                    label: _fmt(_likeCount),
                    onTap: _liked ? () {} : _toggleLike,
                    dimmed: _liked, // shows a glow ring when already liked
                  ),
                  const SizedBox(height: 24),

                  // ── Views (read-only) ────────────────────────────────────
                  _ActionBtn(
                    icon: Icons.remove_red_eye_outlined,
                    color: Colors.white,
                    label: _fmt(_viewCount),
                    onTap: () {}, // display only
                  ),
                ],
              ),
            ),

            // ── Progress bar ──────────────────────────────────────────────
            if (_initialized)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  _ctrl,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF2563EB),
                    bufferedColor: Colors.white30,
                    backgroundColor: Colors.white12,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Right-side action button
// ─────────────────────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.dimmed = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  /// When true the icon shows a soft glow ring (used for "already liked" state).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      color: color,
      size: 32,
      shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
    );

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glow ring behind heart when already liked
          dimmed
              ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.35),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: iconWidget,
                )
              : iconWidget,
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../models/reel_model.dart';
import '../services/reel_service.dart';
import '../services/reel_video_cache_service.dart';
import '../../shops/services/shop_service.dart';
import '../../shops/screens/shop_list_screen.dart';
import '../../../core/router/app_router.dart' show appRouteObserver;

class ReelzScreen extends StatefulWidget {
  const ReelzScreen({super.key});

  @override
  State<ReelzScreen> createState() => _ReelzScreenState();
}

class _ReelzScreenState extends State<ReelzScreen> {
  List<ReelItem> _reels = [];
  List<ReelItem> _filtered = [];
  bool _loading = true;
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  // Search
  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Keep status bar visible — use edgeToEdge so the app bar renders normally
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _load();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    setState(() {
      _searchQuery = q.toLowerCase().trim();
      _filtered = _searchQuery.isEmpty
          ? _reels
          : _reels
              .where((r) => r.shopName.toLowerCase().contains(_searchQuery))
              .toList();
      _currentPage = 0;
    });
    if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
    _prefetchNext(0);
  }

  /// Starts downloading the *next* reel's video in the background while
  /// the current one plays, so swiping to it feels instant — mirrors the
  /// preloading behaviour of apps like Instagram/YouTube. Best-effort only:
  /// if it fails for any reason the next reel simply streams from the
  /// network like normal, so this can never break or crash the feed.
  void _prefetchNext(int index) {
    try {
      final next = index + 1;
      if (next < _filtered.length) {
        ReelVideoCacheService.instance.prefetch(_filtered[next].videoUrl);
      }
    } catch (e) {
      // Preloading is purely a nice-to-have — never let it affect the feed.
      debugPrint('Reel prefetch error (ignored): $e');
    }
  }

  // ── Transparent top overlay (back + search) rendered on the video ──────────
  Widget _buildTopOverlay() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Back button — transparent circle on the video
                GestureDetector(
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const Spacer(),
                // Search toggle — transparent circle on the video
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      }
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _showSearch
                          ? const Color(0xFF1565C0)
                          : Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _showSearch ? Icons.close_rounded : Icons.search_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            // Search bar — visible when _showSearch is true
            if (_showSearch)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by shop name…',
                    hintStyle: const TextStyle(
                        fontSize: 14, color: Colors.white70),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 20, color: Colors.white70),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.45),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Bottom navigation bar ──────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return BottomAppBar(
      notchMargin: 10.0,
      shape: const CircularNotchedRectangle(),
      color: const Color.fromARGB(255, 20, 143, 208),
      elevation: 8,
      padding: EdgeInsets.zero,
      height: kBottomNavigationBarHeight + 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Matches the home bar exactly. The second slot used to be a
                  // Reels tab marked selected — a tab that did nothing on the
                  // screen it pointed at, drawn in a different icon style from
                  // its neighbours. Learn goes here instead, as on every other
                  // screen; you are already in Reelz, so nothing is lost.
                  // Identical to the home bar — same four tabs, same four
                  // icons, same size (see _BarItem.build).
                  _BarItem(icon: Icons.home_rounded, label: 'Home',
                      assetIcon: 'assets/images/nav_home.png',
                      onTap: () => context.go('/home')),
                  _BarItem(icon: Icons.school_rounded, label: 'Learn',
                      assetIcon: 'assets/images/nav_learn.png',
                      onTap: () => context.go('/learn')),
                ],
              ),
            ),
            const SizedBox(width: 72), // FAB gap
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BarItem(icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan Bill',
                      assetIcon: 'assets/images/nav_scan.png',
                      onTap: () => context.push('/bill-reader')),
                  _BarItem(icon: Icons.person_rounded, label: 'Profile',
                      assetIcon: 'assets/images/nav_profile.png',
                      onTap: () => context.go('/profile')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Paged feed ────────────────────────────────────────────────────────────
  // The feed is loaded 10 at a time instead of all at once. Reels are the
  // heaviest thing the app fetches — every row carries a video URL and a
  // thumbnail — so pulling the whole table to show the first three was the
  // single biggest avoidable load on the backend.
  //
  // The next page is requested while the user is still _kPrefetchAhead videos
  // from the end, so it has already arrived by the time they swipe into it and
  // the feed never visibly stalls.
  static const int _kPrefetchAhead = 3;

  bool _hasMore = true;
  bool _loadingMore = false;

  Future<void> _load() async {
    final page = await ReelService.instance.fetchReelsPage(skip: 0);
    if (mounted) {
      setState(() {
        _reels = page.reels;
        _filtered = page.reels;
        _hasMore = page.hasMore;
        _loading = false;
      });
      _prefetchNext(_currentPage);
    }
  }

  /// Fetch the next page and append it. Called on every swipe; it exits
  /// immediately unless another page is actually needed, so it is cheap to
  /// call often.
  Future<void> _loadMoreReels() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    try {
      // skip counts what has been LOADED, not what is displayed — the search
      // filter can hide some, and paging must not shift when it does.
      final page = await ReelService.instance.fetchReelsPage(skip: _reels.length);
      if (!mounted) return;
      if (page.reels.isEmpty) {
        setState(() => _hasMore = false);
        return;
      }
      // Guard against a duplicate arriving if two loads ever overlap: appending
      // a reel that is already in the list would break the PageView's keys.
      final existing = _reels.map((r) => r.id).toSet();
      final fresh = page.reels.where((r) => !existing.contains(r.id)).toList();
      setState(() {
        _reels = [..._reels, ...fresh];
        _filtered = [..._filtered, ...fresh];
        _hasMore = page.hasMore;
      });
    } finally {
      _loadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        bottomNavigationBar: _buildBottomBar(),
        floatingActionButton: SizedBox(
          width: 68,
          height: 68,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFFEAB308),
            elevation: 6,
            shape: const CircleBorder(),
            onPressed: () => context.go('/home'),
            child: Image.asset(
              'assets/icons/main_icon.png',
              width: 54,
              height: 54,
              fit: BoxFit.contain,
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        // Video goes fullscreen to the top; back + search float on top of it.
        body: Stack(
          children: [
            Positioned.fill(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white))
                  : _filtered.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? 'No reels found for "$_searchQuery"'
                                : 'No reels yet. Pull down to refresh.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 16),
                          ),
                        )
                      : PageView.builder(
                          controller: _pageCtrl,
                          scrollDirection: Axis.vertical,
                          physics: const PageScrollPhysics(),
                          itemCount: _filtered.length,
                          onPageChanged: (i) {
                            setState(() => _currentPage = i);
                            _prefetchNext(i);
                            // Queue the next page while there are still a few
                            // videos left to watch, so it has landed before
                            // the user swipes into it. Not awaited —
                            // playback must never wait on the network.
                            if (i >= _filtered.length - _kPrefetchAhead) {
                              _loadMoreReels();
                            }
                          },
                          itemBuilder: (context, index) => _ReelPage(
                            reel: _filtered[index],
                            isActive: index == _currentPage,
                          ),
                        ),
            ),
            // Transparent overlay on the video
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopOverlay(),
            ),
          ],
        ),
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

class _ReelPageState extends State<_ReelPage> with RouteAware {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _coveredByAnotherRoute = false;
  bool _disposed = false;
  PageRoute? _subscribedRoute;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _subscribedRoute) {
      if (_subscribedRoute != null) appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
      _subscribedRoute = route;
    }
  }

  Future<void> _initVideo() async {
    // Always assign a valid (uninitialized) controller synchronously first,
    // so dispose() can never race against an unassigned `_ctrl`.
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.reel.videoUrl));
    try {
      // If this video already finished downloading — e.g. it was preloaded
      // while the previous reel was playing, or this reel was watched
      // before — play it straight from disk: instant start, no
      // re-download. This is a quick local-only lookup (capped wait), so
      // it can never stall first playback if the file isn't ready yet.
      final cached = await ReelVideoCacheService.instance
          .getCachedFileIfReady(widget.reel.videoUrl);
      if (_disposed) return;
      if (cached != null) {
        final placeholder = _ctrl;
        _ctrl = VideoPlayerController.file(cached);
        unawaited(placeholder.dispose());
      } else {
        // Not cached yet — stream from the network as usual, and make
        // sure it's downloading in the background for next time.
        ReelVideoCacheService.instance.prefetch(widget.reel.videoUrl);
      }

      await _ctrl.initialize();
      _ctrl.setLooping(true);
      if (widget.isActive && !_coveredByAnotherRoute) {
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
        if (!_coveredByAnotherRoute) {
          _ctrl.play();
          _recordView();
        }
      } else {
        _ctrl.pause();
      }
    }
  }

  // ── RouteAware ───────────────────────────────────────────────────────────
  // Stop the video + sound the instant another screen is opened on top of
  // Reelz (tapping the shop name, Scan Bill, etc.), and resume only if this
  // page is still the one in view when the user comes back.
  @override
  void didPushNext() {
    _coveredByAnotherRoute = true;
    if (_initialized) _ctrl.pause();
  }

  @override
  void didPopNext() {
    _coveredByAnotherRoute = false;
    if (_initialized && widget.isActive) _ctrl.play();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_subscribedRoute != null) appRouteObserver.unsubscribe(this);
    _ctrl.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _toggleLike() async {
    // One like per user — once liked, tapping again does nothing.
    if (_liked) return;

    // Tap feedback — a short click sound + light vibration on like.
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();

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
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 3),
                      // Long addresses stay on one line but can be swiped
                      // horizontally to read in full, and long-pressed to copy.
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SelectableText(
                            reel.shopLocation,
                            maxLines: 1,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _openShop,
                        child: Container(
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
                      ),
                    ],
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
                        // Long offer text on some reels was pushing this
                        // pill past the available width (the shop-name Row
                        // above already guards against this the same way —
                        // this one just didn't have it).
                        Flexible(
                          child: Text(
                            reel.offer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Simple bottom bar item for the Reelz screen
// ─────────────────────────────────────────────────────────────────────────────
class _BarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final String? assetIcon;
  const _BarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.assetIcon,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? const Color.fromARGB(255, 238, 255, 0)
        : Colors.white;
    final screenW = MediaQuery.of(context).size.width;
    // Exactly the home bar's numbers. There used to be a second, larger scale
    // (0.095 / clamp 30-38) selected by an isScanProfile flag, because the old
    // icon2 was drawn to a different spec than icon5/icon7 and needed to be
    // smaller to look equal. The new nav_*.png set is one 92x92 spec, so the
    // second scale has been removed rather than left unused — same as on Home.
    final iconSize = (screenW * 0.075).clamp(24.0, 28.0);
    final fontSize = (screenW * 0.025).clamp(9.0, 11.0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 60, maxWidth: 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: iconSize,
              height: iconSize,
              // Zero padding for all four, like Home. The old 4dp inset made
              // whichever icon got it render smaller than its neighbours at
              // the same iconSize; the new set carries its own padding.
              child: assetIcon != null
                  ? Padding(
                      padding: EdgeInsets.zero,
                      child: Image.asset(assetIcon!, fit: BoxFit.contain,
                          color: color, colorBlendMode: BlendMode.srcIn,
                          errorBuilder: (_, __, ___) =>
                              Icon(icon, color: color, size: iconSize)),
                    )
                  : Icon(icon, color: color, size: iconSize),
            ),
            const SizedBox(height: 1),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

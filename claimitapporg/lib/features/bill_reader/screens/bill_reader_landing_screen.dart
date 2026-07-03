import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/router/app_router.dart' show appRouteObserver;

// ─────────────────────────────────────────────────────────────────────────────
// BillReaderLandingScreen
// New entry point for the "Scan Bill" nav action (bottom nav / Home / shop
// list / deal list / reelz). Shows a short how-to + demo video before the
// user picks Redeem vs Reward on BillReaderIntroScreen. Pure instructional
// step — no API calls, nothing that can fail except the optional demo video,
// which fails safe (shows a placeholder) if its asset isn't bundled yet.
// ─────────────────────────────────────────────────────────────────────────────

class BillReaderLandingScreen extends StatelessWidget {
  const BillReaderLandingScreen({super.key});

  static const _blue = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _blue, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Bill Reader',
          style: TextStyle(
            color: _blue,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 24),
          children: [
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 20),
            //   child: const Text(
            //     'Scan your bill to apply your discount or cashback',
            //     style: TextStyle(
            //       color: Color(0xFF6B7280),
            //       fontSize: 14,
            //       height: 1.4,
            //     ),
            //   ),
            // ),
            // const SizedBox(height: 22),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const _ScanTile(),
            ),

            const SizedBox(height: 28),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'How to Scan your Bill - Demo Video',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Full-bleed — no horizontal padding, so it spans edge to edge.
            const _DemoVideoCard(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(0, 0, 0, 16),
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: () => context.push('/bill-reader/choose-type'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              elevation: 0,
            ),
            child: const Text(
              'Scan Bill',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Scan the Bill" info row
// ─────────────────────────────────────────────────────────────────────────────

class _ScanTile extends StatelessWidget {
  const _ScanTile();

  static const _blue = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.camera_alt_outlined,
              color: Color(0xFF374151), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scan the Bill',
                style: TextStyle(
                  color: _blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Scan your shop bill using your phone camera',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Demo video card — loads and plays automatically as soon as this card
// appears (no separate play-button step). Tap pauses/resumes. Plays
// assets/videos/generate_a_video_as_reels_size.mp4 (declared in
// pubspec.yaml); if that asset can't be loaded, this shows a plain
// placeholder instead of erroring, so the screen always works.
// ─────────────────────────────────────────────────────────────────────────────

class _DemoVideoCard extends StatefulWidget {
  const _DemoVideoCard();

  @override
  State<_DemoVideoCard> createState() => _DemoVideoCardState();
}

class _DemoVideoCardState extends State<_DemoVideoCard> with RouteAware {
  static const _assetPath = 'assets/videos/generate_a_video_as_reels_size.mp4';

  // The demo clip is portrait (reels-sized, ~9:16). Used as the height
  // fallback before the real video loads, so there's no layout jump once
  // it's ready.
  static const _fallbackAspectRatio = 9 / 16;

  VideoPlayerController? _ctrl;
  bool _videoReady = false;
  bool _videoFailed = false;
  bool _disposed = false;
  PageRoute? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    _startPlayback();
  }

  // Subscribe to this screen's own route so we know the instant another
  // screen (e.g. the "choose type" page after tapping Scan Bill) is pushed
  // on top of it, and pause immediately instead of playing on unseen
  // underneath. Resumes only if the user comes back to this exact page.
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

  @override
  void didPushNext() {
    if (_videoReady) _ctrl?.pause();
  }

  @override
  void didPopNext() {
    if (_videoReady) _ctrl?.play();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_subscribedRoute != null) appRouteObserver.unsubscribe(this);
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _startPlayback() async {
    try {
      final ctrl = VideoPlayerController.asset(_assetPath);
      await ctrl.initialize();
      if (_disposed) {
        unawaited(ctrl.dispose());
        return;
      }
      ctrl.setLooping(true);
      ctrl.play();
      setState(() {
        _ctrl = ctrl;
        _videoReady = true;
      });
    } catch (e) {
      debugPrint('Bill demo video error (asset missing or invalid): $e');
      if (mounted) setState(() => _videoFailed = true);
    }
  }

  void _togglePlayback() {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    setState(() {
      ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    final aspectRatio =
        (_videoReady && ctrl != null) ? ctrl.value.aspectRatio : _fallbackAspectRatio;

    // Width comes from whatever space is available (full device width,
    // since this card has no horizontal padding around it) — height is
    // then derived from the video's own aspect ratio. This scales
    // correctly on every screen size instead of using a fixed pixel height
    // tuned for one phone.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width / aspectRatio;
        return SizedBox(
          width: width,
          height: height,
          child: GestureDetector(
            onTap: _videoReady ? _togglePlayback : null,
            child: Container(
              color: const Color(0xFFE5E7EB),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_videoReady && ctrl != null) VideoPlayer(ctrl),
                  if (!_videoReady && !_videoFailed)
                    const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF9CA3AF), strokeWidth: 2),
                    ),
                  if (_videoReady && ctrl != null && !ctrl.value.isPlaying)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.black26,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 40),
                      ),
                    ),
                  if (_videoFailed)
                    const Center(
                      child: Icon(Icons.videocam_off_rounded,
                          color: Color(0xFF9CA3AF), size: 36),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

void unawaited(Future<void> future) {}

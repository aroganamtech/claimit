import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/learn_item.dart';
import '../services/learn_service.dart';

/// Fullscreen video player for a single "Learn Claimit" lesson.
/// Opened by tapping a question on [LearnListScreen]. Plays with sound by
/// default (this is a deliberate open, not an autoplay feed) with a
/// mute/unmute toggle, plus a one-time like button — same visual language
/// as the Reelz player (black background, floating circular controls).
class LearnVideoScreen extends StatefulWidget {
  const LearnVideoScreen({super.key, required this.item});
  final LearnItem item;

  @override
  State<LearnVideoScreen> createState() => _LearnVideoScreenState();
}

class _LearnVideoScreenState extends State<LearnVideoScreen> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _failed = false;
  bool _muted = false;

  bool _liked = false;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _liked = widget.item.likedByMe;
    _likeCount = widget.item.likeCount;
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.item.videoUrl.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.item.videoUrl));
    _ctrl = ctrl;
    try {
      await ctrl.initialize();
      ctrl.setLooping(true);
      ctrl.setVolume(_muted ? 0 : 1);
      ctrl.play();
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      debugPrint('LearnVideoScreen init error: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _ctrl?.setVolume(_muted ? 0 : 1);
  }

  Future<void> _toggleLike() async {
    // One like per user — once liked, tapping again does nothing (matches
    // the Reelz convention).
    if (_liked) return;
    setState(() {
      _liked = true;
      _likeCount += 1;
    });
    final result = await LearnService.instance.likeItem(widget.item.id, liked: true);
    if (result != null && mounted) {
      setState(() {
        _likeCount = result.likeCount;
        _liked = result.likedByMe;
      });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        // Without this, the Stack shrinks to the size of its one
        // non-positioned child (the SafeArea control bar below) instead of
        // filling the screen — that's what was leaving the bottom half
        // black. StackFit.expand forces it (and that child) to fill fully,
        // same as the Reelz per-video Stack.
        fit: StackFit.expand,
        children: [
          // Fills the entire screen edge-to-edge (crops to fit, no letterbox
          // bars) — same FittedBox/cover pattern the Reelz player uses.
          Positioned.fill(
            child: _initialized && _ctrl != null
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _ctrl!.value.size.width,
                      height: _ctrl!.value.size.height,
                      child: VideoPlayer(_ctrl!),
                    ),
                  )
                : Center(
                    child: _failed
                        ? const Text(
                            'Could not load this video',
                            style: TextStyle(color: Colors.white70),
                          )
                        : const CircularProgressIndicator(color: Colors.white),
                  ),
          ),

          // ── Top bar: back, question, mute toggle ───────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CircleIconBtn(
                    icon: Icons.arrow_back_rounded,
                    onTap: () {
                      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        widget.item.question,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CircleIconBtn(
                    icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    onTap: _toggleMute,
                  ),
                ],
              ),
            ),
          ),

          // ── Like button ─────────────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 32,
            child: GestureDetector(
              onTap: _liked ? null : _toggleLike,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _liked ? Colors.redAccent : Colors.white,
                    size: 32,
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_likeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Progress bar ────────────────────────────────────────────────
          if (_initialized && _ctrl != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                _ctrl!,
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
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  const _CircleIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.35),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

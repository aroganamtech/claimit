import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared on-disk cache for the short ad/banner videos shown around the
/// app (Home page banner carousel, National Ads list, etc.) so a video
/// that's already been downloaded once plays straight from disk instead
/// of being re-streamed from the network every time its widget rebuilds.
///
/// Every public method here is defensive on purpose: a cache or network
/// failure must never surface to the UI or crash the app. Callers always
/// have a plain network-streaming fallback for when caching hasn't
/// finished yet (or failed entirely).
class VideoCacheService {
  VideoCacheService._();
  static final VideoCacheService instance = VideoCacheService._();

  /// A dedicated cache — separate from cached_network_image's image cache
  /// and from the Reelz video cache — so ad/banner clips don't crowd out
  /// (or get crowded out by) other cached media. Disk usage stays bounded:
  /// at most ~30 videos, evicted after 7 days.
  final CacheManager _cache = CacheManager(
    Config(
      'adVideoCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 30,
    ),
  );

  /// Downloads currently in progress, keyed by video URL, so the same
  /// video is never requested from the network twice at once.
  final Map<String, Future<File>> _inFlight = {};

  /// Starts downloading [url] in the background if it isn't already
  /// cached or already downloading. Fire-and-forget: any failure (no
  /// connectivity, server error, disk full, etc.) is logged and
  /// swallowed — playback just keeps streaming from the network instead,
  /// exactly like before this feature existed.
  void prefetch(String url) {
    if (url.isEmpty) return;
    unawaited(() async {
      try {
        await _download(url);
      } catch (e) {
        debugPrint('VideoCacheService: prefetch failed for $url ($e)');
      }
    }());
  }

  /// Returns the local file for [url] only if it's *already* fully
  /// cached. A quick local lookup — it never starts a network download
  /// and is capped so it can never stall video playback. Returns null on
  /// a cache miss or any error; callers should then fall back to
  /// streaming from the network as usual.
  Future<File?> getCachedFileIfReady(String url) async {
    if (url.isEmpty) return null;
    try {
      final info = await _cache
          .getFileFromCache(url)
          .timeout(const Duration(milliseconds: 400));
      return info?.file;
    } catch (e) {
      debugPrint('VideoCacheService: cache lookup failed for $url ($e)');
      return null;
    }
  }

  Future<File> _download(String url) {
    return _inFlight.putIfAbsent(url, () async {
      try {
        return await _cache.getSingleFile(url);
      } finally {
        _inFlight.remove(url);
      }
    });
  }
}

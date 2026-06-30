import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Caches reel videos on local disk so that:
///  • the *next* reel can start downloading in the background while the
///    current one is still playing — no visible loading delay on swipe, and
///  • a reel that's already been downloaded is never re-downloaded — it's
///    served straight from disk, the same way Instagram/YouTube avoid
///    re-fetching short-form videos a user has already seen.
///
/// Every public method here is defensive on purpose: a cache or network
/// failure must never surface to the UI or crash the app. Callers always
/// have a plain network-streaming fallback for the case where caching
/// didn't finish in time (or didn't work at all).
class ReelVideoCacheService {
  ReelVideoCacheService._();
  static final ReelVideoCacheService instance = ReelVideoCacheService._();

  /// A dedicated cache (separate from cached_network_image's image cache)
  /// so reel videos don't crowd out cached images, and disk usage stays
  /// bounded — at most ~40 videos, evicted after 3 days.
  final CacheManager _cache = CacheManager(
    Config(
      'reelVideoCache',
      stalePeriod: const Duration(days: 3),
      maxNrOfCacheObjects: 40,
    ),
  );

  /// Downloads currently in progress, keyed by video URL, so the same
  /// video is never requested from the network twice at once.
  final Map<String, Future<File>> _inFlight = {};

  /// Starts downloading [url] in the background if it isn't already
  /// cached or already downloading. Fire-and-forget: any failure (no
  /// connectivity, server error, disk full, etc.) is logged and swallowed
  /// — it just means the next play attempt streams from the network
  /// instead, exactly like before this feature existed.
  void prefetch(String url) {
    if (url.isEmpty) return;
    unawaited(() async {
      try {
        await _download(url);
      } catch (e) {
        debugPrint('ReelVideoCacheService: prefetch failed for $url ($e)');
      }
    }());
  }

  /// Returns the local file for [url] only if it's *already* fully
  /// cached. This is a quick local lookup — it never starts a network
  /// download and is capped so it can never stall video playback. Returns
  /// null on a cache miss, a stale entry, or any error; callers should
  /// then fall back to streaming from the network as usual.
  Future<File?> getCachedFileIfReady(String url) async {
    if (url.isEmpty) return null;
    try {
      final info = await _cache
          .getFileFromCache(url)
          .timeout(const Duration(milliseconds: 400));
      return info?.file;
    } catch (e) {
      debugPrint('ReelVideoCacheService: cache lookup failed for $url ($e)');
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

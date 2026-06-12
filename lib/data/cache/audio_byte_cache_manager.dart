import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Bounded on-disk cache for streamed audio bytes.
///
/// Caps the cache so streamed audio does not grow unbounded on mobile; LRU
/// eviction is handled by flutter_cache_manager once limits are exceeded.
class AudioByteCacheManager extends CacheManager {
  AudioByteCacheManager._() : super(_config);

  static const String key = 'auraAudioCache';

  // ~500MB / a few hundred files: cap audio byte cache.
  static final Config _config = Config(
    key,
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 300,
    fileService: HttpFileService(),
  );

  static final AudioByteCacheManager instance = AudioByteCacheManager._();

  /// Returns a cached local file URI for [url] if present; otherwise returns
  /// the remote [url] so just_audio streams + caches it on first play.
  Future<Uri> resolvePlayableUri(String url) async {
    final fileInfo = await getFileFromCache(url);
    if (fileInfo != null && fileInfo.file.existsSync()) {
      return fileInfo.file.uri;
    }
    // Warm the cache in the background; play directly from network meanwhile.
    unawaited(downloadFile(url));
    return Uri.parse(url);
  }

  /// Pre-warms the cache for [url] (used by the pre-buffer controller).
  Future<void> warm(String url) async {
    final existing = await getFileFromCache(url);
    if (existing == null) {
      await downloadFile(url);
    }
  }
}

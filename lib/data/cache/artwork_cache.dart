import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Bounded on-disk cache for album artwork.
///
/// Used by `cached_network_image` so artwork renders instantly and is never
/// re-downloaded. Capped to keep the footprint bounded on mobile.
class ArtworkCacheManager extends CacheManager {
  ArtworkCacheManager._() : super(_config);

  static const String key = 'auraArtworkCache';

  static final Config _config = Config(
    key,
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 500,
    fileService: HttpFileService(),
  );

  static final ArtworkCacheManager instance = ArtworkCacheManager._();

  /// Clears in-memory + on-disk artwork (used on low-memory / lifecycle pause).
  Future<void> evict() => emptyCache();
}

import 'package:isar/isar.dart';

part 'cached_track_model.g.dart';

/// Cached track metadata + extracted palette, keyed by trackId.
@collection
class CachedTrackModel {
  CachedTrackModel();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String trackId;

  /// Full [Track] serialized as JSON for forward-compatible caching.
  late String trackJson;

  // Cached palette (ARGB ints); null until extracted.
  int? paletteDominant;
  int? paletteVibrant;
  int? paletteMuted;

  late int cachedAt;
  int ttlMs = 24 * 60 * 60 * 1000; // 24h

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch - cachedAt >= ttlMs;
}

import '../../core/errors/result.dart';
import '../entities/history_entry.dart';
import '../entities/playlist.dart';
import '../entities/track.dart';

/// Local, decentralized user-data store (favorites, playlists, history) plus
/// metadata / API response caches. Backed by Isar; no server involved.
abstract interface class UserRepository {
  // --- Favorites ---
  Future<Result<List<Track>>> getFavorites();
  Future<Result<bool>> isFavorite(String trackId);
  Future<Result<void>> toggleFavorite(Track track);

  Stream<List<Track>> watchFavorites();

  // --- Playlists ---
  Future<Result<List<Playlist>>> getPlaylists();
  Future<Result<Playlist>> createPlaylist(String name);
  Future<Result<void>> addToPlaylist(String playlistId, String trackId);
  Future<Result<void>> removeFromPlaylist(String playlistId, String trackId);

  // --- History ---
  Future<Result<List<HistoryEntry>>> getHistory({int limit = 100});
  Future<Result<void>> recordHistory(Track track);

  // --- Metadata cache ---
  Future<Result<List<Track>>?> getCachedCharts();
  Future<Result<void>> cacheCharts(List<Track> tracks);

  // --- Generic API cache (keyed) ---
  Future<String?> getCachedResponse(String cacheKey);
  Future<void> cacheResponse(String cacheKey, String json, {int ttlMs});

  // --- Palette cache ---
  Future<List<int>?> getCachedPalette(String trackId);
  Future<void> cachePalette(String trackId, List<int> argb);
}

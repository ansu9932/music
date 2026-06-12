import 'dart:async';
import 'dart:convert';

import 'package:isar/isar.dart';

import '../../core/errors/failure.dart';
import '../../core/errors/result.dart';
import '../../domain/entities/history_entry.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/user_repository.dart';
import 'models/api_cache_model.dart';
import 'models/cached_track_model.dart';
import 'models/favorite_model.dart';
import 'models/history_model.dart';
import 'models/playlist_model.dart';

/// Isar-backed implementation of [UserRepository]. All operations are guarded
/// so storage errors become [StorageFailure] values rather than thrown.
class IsarUserRepository implements UserRepository {
  IsarUserRepository(this._isar);

  final Isar _isar;

  static const String _chartsCacheKey = 'charts:featured';

  // --- Favorites ---------------------------------------------------------

  @override
  Future<Result<List<Track>>> getFavorites() {
    return guardAsync<List<Track>>(
      () async {
        final models = await _isar.favoriteModels
            .where()
            .sortBySavedAtDesc()
            .findAll();
        return models.map(_favoriteToTrack).toList();
      },
      onError: (e, _) => StorageFailure('Could not load favorites', e),
    );
  }

  @override
  Future<Result<bool>> isFavorite(String trackId) {
    return guardAsync<bool>(
      () async {
        final found = await _isar.favoriteModels
            .filter()
            .trackIdEqualTo(trackId)
            .findFirst();
        return found != null;
      },
      onError: (e, _) => StorageFailure('Favorite lookup failed', e),
    );
  }

  @override
  Future<Result<void>> toggleFavorite(Track track) {
    return guardAsync<void>(
      () async {
        await _isar.writeTxn(() async {
          final existing = await _isar.favoriteModels
              .filter()
              .trackIdEqualTo(track.id)
              .findFirst();
          if (existing != null) {
            await _isar.favoriteModels.delete(existing.id);
          } else {
            final model = FavoriteModel()
              ..trackId = track.id
              ..title = track.displayTitle
              ..artist = track.displayArtist
              ..album = track.album
              ..artworkUrl = track.artworkUrl
              ..directAudioUrl = track.directAudioUrl
              ..durationMs = track.durationMs
              ..savedAt = DateTime.now().millisecondsSinceEpoch;
            await _isar.favoriteModels.put(model);
          }
        });
      },
      onError: (e, _) => StorageFailure('Could not update favorite', e),
    );
  }

  @override
  Stream<List<Track>> watchFavorites() {
    return _isar.favoriteModels
        .where()
        .sortBySavedAtDesc()
        .watch(fireImmediately: true)
        .map((models) => models.map(_favoriteToTrack).toList());
  }

  // --- Playlists ---------------------------------------------------------

  @override
  Future<Result<List<Playlist>>> getPlaylists() {
    return guardAsync<List<Playlist>>(
      () async {
        final models =
            await _isar.playlistModels.where().sortByUpdatedAtDesc().findAll();
        return models.map(_playlistToEntity).toList();
      },
      onError: (e, _) => StorageFailure('Could not load playlists', e),
    );
  }

  @override
  Future<Result<Playlist>> createPlaylist(String name) {
    return guardAsync<Playlist>(
      () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final model = PlaylistModel()
          ..playlistId = 'pl_$now'
          ..name = name.trim().isEmpty ? 'Untitled' : name.trim()
          ..trackIds = <String>[]
          ..createdAt = now
          ..updatedAt = now;
        await _isar.writeTxn(() => _isar.playlistModels.put(model));
        return _playlistToEntity(model);
      },
      onError: (e, _) => StorageFailure('Could not create playlist', e),
    );
  }

  @override
  Future<Result<void>> addToPlaylist(String playlistId, String trackId) {
    return guardAsync<void>(
      () async {
        await _isar.writeTxn(() async {
          final model = await _isar.playlistModels
              .filter()
              .playlistIdEqualTo(playlistId)
              .findFirst();
          if (model == null) return;
          if (!model.trackIds.contains(trackId)) {
            model.trackIds = <String>[...model.trackIds, trackId];
            model.updatedAt = DateTime.now().millisecondsSinceEpoch;
            await _isar.playlistModels.put(model);
          }
        });
      },
      onError: (e, _) => StorageFailure('Could not add to playlist', e),
    );
  }

  @override
  Future<Result<void>> removeFromPlaylist(String playlistId, String trackId) {
    return guardAsync<void>(
      () async {
        await _isar.writeTxn(() async {
          final model = await _isar.playlistModels
              .filter()
              .playlistIdEqualTo(playlistId)
              .findFirst();
          if (model == null) return;
          model.trackIds =
              model.trackIds.where((id) => id != trackId).toList();
          model.updatedAt = DateTime.now().millisecondsSinceEpoch;
          await _isar.playlistModels.put(model);
        });
      },
      onError: (e, _) => StorageFailure('Could not update playlist', e),
    );
  }

  // --- History -----------------------------------------------------------

  @override
  Future<Result<List<HistoryEntry>>> getHistory({int limit = 100}) {
    return guardAsync<List<HistoryEntry>>(
      () async {
        final models = await _isar.historyModels
            .where()
            .sortByPlayedAtDesc()
            .limit(limit)
            .findAll();
        return models
            .map((m) => HistoryEntry(
                  trackId: m.trackId,
                  title: m.title,
                  artist: m.artist,
                  artworkUrl: m.artworkUrl,
                  playedAtMs: m.playedAt,
                ))
            .toList();
      },
      onError: (e, _) => StorageFailure('Could not load history', e),
    );
  }

  @override
  Future<Result<void>> recordHistory(Track track) {
    return guardAsync<void>(
      () async {
        await _isar.writeTxn(() async {
          // Unique index on trackId with replace de-dups automatically.
          final existing = await _isar.historyModels
              .filter()
              .trackIdEqualTo(track.id)
              .findFirst();
          final model = (existing ?? HistoryModel())
            ..trackId = track.id
            ..title = track.displayTitle
            ..artist = track.displayArtist
            ..artworkUrl = track.artworkUrl
            ..playedAt = DateTime.now().millisecondsSinceEpoch;
          await _isar.historyModels.put(model);
        });
      },
      onError: (e, _) => StorageFailure('Could not record history', e),
    );
  }

  // --- Metadata / charts cache ------------------------------------------

  @override
  Future<Result<List<Track>>?> getCachedCharts() async {
    final json = await getCachedResponse(_chartsCacheKey);
    if (json == null) return null;
    return guard<List<Track>>(
      () {
        final decoded = jsonDecode(json) as List<dynamic>;
        return decoded
            .map((e) => Track.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      onError: (e, _) => StorageFailure('Corrupt charts cache', e),
    );
  }

  @override
  Future<Result<void>> cacheCharts(List<Track> tracks) {
    return guardAsync<void>(
      () async {
        final json = jsonEncode(tracks.map((t) => t.toJson()).toList());
        await cacheResponse(_chartsCacheKey, json);
      },
      onError: (e, _) => StorageFailure('Could not cache charts', e),
    );
  }

  // --- Generic API response cache ---------------------------------------

  @override
  Future<String?> getCachedResponse(String cacheKey) async {
    final model = await _isar.apiCacheModels
        .filter()
        .cacheKeyEqualTo(cacheKey)
        .findFirst();
    if (model == null) return null;
    if (model.isExpired) return model.responseJson; // stale-but-usable offline
    return model.responseJson;
  }

  @override
  Future<void> cacheResponse(
    String cacheKey,
    String json, {
    int ttlMs = 30 * 60 * 1000,
  }) async {
    final model = ApiCacheModel()
      ..cacheKey = cacheKey
      ..responseJson = json
      ..cachedAt = DateTime.now().millisecondsSinceEpoch
      ..ttlMs = ttlMs;
    await _isar.writeTxn(() => _isar.apiCacheModels.put(model));
  }

  // --- Palette cache -----------------------------------------------------

  @override
  Future<List<int>?> getCachedPalette(String trackId) async {
    final model = await _isar.cachedTrackModels
        .filter()
        .trackIdEqualTo(trackId)
        .findFirst();
    if (model?.paletteDominant == null) return null;
    return <int>[
      model!.paletteDominant!,
      model.paletteVibrant ?? model.paletteDominant!,
      model.paletteMuted ?? model.paletteDominant!,
    ];
  }

  @override
  Future<void> cachePalette(String trackId, List<int> argb) async {
    if (argb.length < 3) return;
    await _isar.writeTxn(() async {
      final existing = await _isar.cachedTrackModels
          .filter()
          .trackIdEqualTo(trackId)
          .findFirst();
      final model = (existing ?? CachedTrackModel())
        ..trackId = trackId
        ..trackJson = existing?.trackJson ?? '{}'
        ..paletteDominant = argb[0]
        ..paletteVibrant = argb[1]
        ..paletteMuted = argb[2]
        ..cachedAt = DateTime.now().millisecondsSinceEpoch;
      await _isar.cachedTrackModels.put(model);
    });
  }

  // --- Mappers -----------------------------------------------------------

  Track _favoriteToTrack(FavoriteModel m) => Track(
        id: m.trackId,
        title: m.title,
        artist: m.artist,
        album: m.album,
        durationMs: m.durationMs,
        artworkUrl: m.artworkUrl,
        directAudioUrl: m.directAudioUrl,
      );

  Playlist _playlistToEntity(PlaylistModel m) => Playlist(
        id: m.playlistId,
        name: m.name,
        trackIds: m.trackIds,
        updatedAtMs: m.updatedAt,
      );
}

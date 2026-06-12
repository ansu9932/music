import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'user/models/api_cache_model.dart';
import 'user/models/cached_track_model.dart';
import 'user/models/favorite_model.dart';
import 'user/models/history_model.dart';
import 'user/models/playlist_model.dart';
import 'user/models/session_model.dart';

/// Opens the single Isar instance with all collection schemas.
///
/// On a corrupt store / failed open, the database directory is cleared and a
/// fresh store is created so the app never fails to launch (recovery path).
abstract final class IsarBootstrap {
  const IsarBootstrap._();

  static const List<CollectionSchema<dynamic>> _schemas =
      <CollectionSchema<dynamic>>[
    FavoriteModelSchema,
    PlaylistModelSchema,
    HistoryModelSchema,
    CachedTrackModelSchema,
    ApiCacheModelSchema,
    SessionModelSchema,
  ];

  static Future<Isar> open() async {
    // Reuse an already-open instance if present (single instance guarantee).
    final existing = Isar.getInstance();
    if (existing != null) return existing;

    final dir = await getApplicationSupportDirectory();
    try {
      return await Isar.open(_schemas, directory: dir.path);
    } catch (_) {
      // Recovery: wipe and reopen so a corrupt/incompatible store can't brick
      // the app. User favorites/playlists are rebuilt as they re-favorite.
      try {
        final corrupt = await Isar.open(
          _schemas,
          directory: dir.path,
          name: 'aura_recovery_${DateTime.now().millisecondsSinceEpoch}',
        );
        await corrupt.writeTxn(() => corrupt.clear());
        return corrupt;
      } catch (e) {
        rethrow;
      }
    }
  }
}

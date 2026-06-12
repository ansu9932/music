import 'package:isar/isar.dart';

import '../../domain/entities/play_queue.dart';
import '../../domain/repositories/session_repository.dart';
import '../user/models/session_model.dart';

/// Isar-backed [SessionRepository]. Persists a single session row (id 0).
class SessionStore implements SessionRepository {
  SessionStore(this._isar);

  final Isar _isar;

  @override
  Future<void> save({
    required String? activeTrackId,
    required List<String> queueTrackIds,
    required int positionMs,
    required RepeatMode repeatMode,
    required bool shuffle,
  }) async {
    final model = SessionModel()
      ..id = 0
      ..activeTrackId = activeTrackId
      ..queueTrackIds = queueTrackIds
      ..positionMs = positionMs
      ..repeatMode = repeatMode.index
      ..shuffle = shuffle;
    await _isar.writeTxn(() => _isar.sessionModels.put(model));
  }

  @override
  Future<SessionSnapshot?> restore() async {
    final model = await _isar.sessionModels.get(0);
    if (model == null || model.activeTrackId == null) return null;
    return SessionSnapshot(
      activeTrackId: model.activeTrackId,
      queueTrackIds: model.queueTrackIds,
      positionMs: model.positionMs,
      repeatMode: RepeatMode.values[
          model.repeatMode.clamp(0, RepeatMode.values.length - 1)],
      shuffle: model.shuffle,
    );
  }

  @override
  Future<void> clear() async {
    await _isar.writeTxn(() => _isar.sessionModels.delete(0));
  }
}

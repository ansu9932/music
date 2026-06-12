import '../entities/play_queue.dart';

/// Persists and restores last-session playback context so the app resumes
/// where the listener left off.
abstract interface class SessionRepository {
  Future<void> save({
    required String? activeTrackId,
    required List<String> queueTrackIds,
    required int positionMs,
    required RepeatMode repeatMode,
    required bool shuffle,
  });

  Future<SessionSnapshot?> restore();
  Future<void> clear();
}

/// Plain-data result of [SessionRepository.restore].
class SessionSnapshot {
  const SessionSnapshot({
    required this.activeTrackId,
    required this.queueTrackIds,
    required this.positionMs,
    required this.repeatMode,
    required this.shuffle,
  });

  final String? activeTrackId;
  final List<String> queueTrackIds;
  final int positionMs;
  final RepeatMode repeatMode;
  final bool shuffle;
}

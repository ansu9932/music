import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../domain/entities/play_queue.dart';
import '../../domain/entities/track.dart';
import 'audio_providers.dart';
import 'library_controller.dart';
import 'queue_controller.dart';
import 'toast_controller.dart';

/// Imperative playback orchestration consumed by the UI. Wraps the
/// [AudioRepository] and coordinates queue mirror + history recording.
class PlayerController {
  PlayerController(this._ref);
  final Ref _ref;

  /// Plays [track] within [contextTracks] (e.g. the charts list). The queue is
  /// rotated so the tapped track becomes index 0 (keeping the engine playlist
  /// and the queue mirror perfectly aligned for next/pre-buffer). Records
  /// history.
  Future<void> playTrack(
    Track track, {
    List<Track>? contextTracks,
  }) async {
    final source = (contextTracks == null || contextTracks.isEmpty)
        ? <Track>[track]
        : contextTracks;

    final start = source.indexWhere((t) => t.id == track.id);
    final ordered = start <= 0
        ? source
        : <Track>[...source.sublist(start), ...source.sublist(0, start)];

    _ref.read(queueControllerProvider.notifier).setQueue(ordered);

    try {
      await _ref.read(audioRepositoryProvider).setQueue(ordered);
      await _ref.read(libraryControllerProvider).recordHistory(track);
    } catch (e) {
      _ref.read(toastControllerProvider.notifier).showFailure(
            PlaybackFailure('Could not start playback', e),
          );
    }
  }

  Future<void> togglePlayPause(bool isPlaying) async {
    final audio = _ref.read(audioRepositoryProvider);
    if (isPlaying) {
      await audio.pause();
    } else {
      await audio.play();
    }
  }

  Future<void> seek(Duration position) =>
      _ref.read(audioRepositoryProvider).seek(position);

  Future<void> next() => _ref.read(audioRepositoryProvider).skipToNext();

  Future<void> previous() =>
      _ref.read(audioRepositoryProvider).skipToPrevious();

  Future<void> cycleRepeat() async {
    _ref.read(queueControllerProvider.notifier).cycleRepeatMode();
    await _ref
        .read(audioRepositoryProvider)
        .setRepeatMode(_ref.read(queueControllerProvider).repeatMode);
  }

  Future<void> toggleShuffle() async {
    _ref.read(queueControllerProvider.notifier).toggleShuffle();
    await _ref
        .read(audioRepositoryProvider)
        .setShuffle(_ref.read(queueControllerProvider).shuffle);
  }
}

final playerControllerProvider = Provider<PlayerController>((ref) {
  return PlayerController(ref);
});

/// Re-exported for convenience in the UI.
RepeatMode currentRepeatMode(WidgetRef ref) =>
    ref.watch(queueControllerProvider).repeatMode;

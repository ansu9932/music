import 'package:freezed_annotation/freezed_annotation.dart';

import 'track.dart';

part 'playback_state.freezed.dart';

/// Coarse processing status of the audio engine, mirrored from audio_service.
enum PlaybackStatus { idle, loading, buffering, ready, playing, paused, completed, error }

/// UI-facing snapshot of the player. Immutable; rebuilt on every change.
@freezed
class PlaybackState with _$PlaybackState {
  const factory PlaybackState({
    Track? track,
    @Default(PlaybackStatus.idle) PlaybackStatus status,
    @Default(Duration.zero) Duration position,
    @Default(Duration.zero) Duration buffered,
    @Default(Duration.zero) Duration duration,
    @Default(false) bool shuffle,
    @Default(0) int repeatModeIndex,
    @Default(false) bool hasNext,
    @Default(false) bool hasPrevious,
  }) = _PlaybackState;

  const PlaybackState._();

  bool get isPlaying => status == PlaybackStatus.playing;
  bool get isBuffering =>
      status == PlaybackStatus.loading || status == PlaybackStatus.buffering;

  double get progress {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  /// Remaining time before the track ends (used by the pre-buffer trigger).
  Duration get remaining {
    final r = duration - position;
    return r.isNegative ? Duration.zero : r;
  }
}

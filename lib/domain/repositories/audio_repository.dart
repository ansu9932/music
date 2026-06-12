import '../entities/play_queue.dart';
import '../entities/playback_state.dart';
import '../entities/track.dart';

/// High-level audio control surface consumed by the application layer. Backed
/// by the background audio_service handler + just_audio engine.
abstract interface class AudioRepository {
  /// Broadcast stream of UI-facing playback state.
  Stream<PlaybackState> get playbackState;

  /// High-frequency position stream for smooth progress rendering.
  Stream<Duration> get positionStream;

  /// Replace the queue and start playback at [initialIndex].
  Future<void> setQueue(List<Track> tracks, {int initialIndex = 0});

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> setRepeatMode(RepeatMode mode);
  Future<void> setShuffle(bool enabled);

  /// Smoothly ramps volume to [target] over [duration] (used for the 300ms
  /// fade-out on network drops).
  Future<void> fadeVolumeTo(double target, Duration duration);
  Future<void> setVolume(double volume);

  /// Stage the resolved [next] track for gapless transition (pre-buffer).
  Future<void> stageNext(Track next);

  Future<void> dispose();
}

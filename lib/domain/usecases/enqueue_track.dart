import '../entities/track.dart';
import '../repositories/audio_repository.dart';

/// Replaces the queue with [tracks] and begins playback at [initialIndex].
class EnqueueTrack {
  const EnqueueTrack(this._audio);
  final AudioRepository _audio;

  Future<void> call(List<Track> tracks, {int initialIndex = 0}) =>
      _audio.setQueue(tracks, initialIndex: initialIndex);
}

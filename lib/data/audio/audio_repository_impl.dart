import 'dart:async';

import 'package:audio_service/audio_service.dart' as a_s;

import '../../domain/entities/play_queue.dart';
import '../../domain/entities/playback_state.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/audio_repository.dart';
import 'aura_audio_handler.dart';

/// Adapts [AuraAudioHandler] (audio_service) to the domain [AudioRepository],
/// translating audio_service [a_s.PlaybackState] into the app's
/// [PlaybackState] entity.
class AudioRepositoryImpl implements AudioRepository {
  AudioRepositoryImpl(this._handler);

  final AuraAudioHandler _handler;

  Track? _currentTrack;

  @override
  Stream<PlaybackState> get playbackState {
    return _handler.playbackState.map(_mapState);
  }

  @override
  Stream<Duration> get positionStream => a_s.AudioService.position;

  PlaybackState _mapState(a_s.PlaybackState s) {
    // Resolve current track from the media item stream value.
    final mediaItem = _handler.mediaItem.valueOrNull;
    if (mediaItem != null) {
      _currentTrack = Track(
        id: mediaItem.id,
        title: mediaItem.title,
        artist: mediaItem.artist ?? 'Unknown Artist',
        album: mediaItem.album,
        durationMs: mediaItem.duration?.inMilliseconds ?? 0,
        artworkUrl: mediaItem.artUri?.toString(),
      );
    }

    return PlaybackState(
      track: _currentTrack,
      status: _mapStatus(s),
      position: s.updatePosition,
      buffered: s.bufferedPosition,
      duration: _currentTrack?.duration ?? Duration.zero,
      shuffle: s.shuffleMode == a_s.AudioServiceShuffleMode.all,
      repeatModeIndex: s.repeatMode.index,
      hasNext: _handler.player.hasNext,
      hasPrevious: _handler.player.hasPrevious,
    );
  }

  PlaybackStatus _mapStatus(a_s.PlaybackState s) {
    switch (s.processingState) {
      case a_s.AudioProcessingState.idle:
        return PlaybackStatus.idle;
      case a_s.AudioProcessingState.loading:
        return PlaybackStatus.loading;
      case a_s.AudioProcessingState.buffering:
        return PlaybackStatus.buffering;
      case a_s.AudioProcessingState.ready:
        return s.playing ? PlaybackStatus.playing : PlaybackStatus.paused;
      case a_s.AudioProcessingState.completed:
        return PlaybackStatus.completed;
      case a_s.AudioProcessingState.error:
        return PlaybackStatus.error;
    }
  }

  @override
  Future<void> setQueue(List<Track> tracks, {int initialIndex = 0}) {
    if (tracks.isEmpty) return Future<void>.value();
    final index = initialIndex.clamp(0, tracks.length - 1);
    return _handler.setQueueTracks(tracks, initialIndex: index);
  }

  @override
  Future<void> play() => _handler.play();

  @override
  Future<void> pause() => _handler.pause();

  @override
  Future<void> seek(Duration position) => _handler.seek(position);

  @override
  Future<void> skipToNext() => _handler.skipToNext();

  @override
  Future<void> skipToPrevious() => _handler.skipToPrevious();

  @override
  Future<void> setRepeatMode(RepeatMode mode) {
    final asMode = switch (mode) {
      RepeatMode.off => a_s.AudioServiceRepeatMode.none,
      RepeatMode.one => a_s.AudioServiceRepeatMode.one,
      RepeatMode.all => a_s.AudioServiceRepeatMode.all,
    };
    return _handler.setRepeatMode(asMode);
  }

  @override
  Future<void> setShuffle(bool enabled) {
    return _handler.setShuffleMode(
      enabled
          ? a_s.AudioServiceShuffleMode.all
          : a_s.AudioServiceShuffleMode.none,
    );
  }

  @override
  Future<void> fadeVolumeTo(double target, Duration duration) =>
      _handler.fadeVolumeTo(target, duration);

  @override
  Future<void> setVolume(double volume) => _handler.setVolume(volume);

  @override
  Future<void> stageNext(Track next) => _handler.stageNext(next);

  @override
  Future<void> dispose() => _handler.shutdown();
}

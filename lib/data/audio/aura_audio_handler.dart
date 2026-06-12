import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/track.dart';
import '../../domain/repositories/stream_resolver.dart';
import '../cache/audio_byte_cache_manager.dart';

/// Background audio engine. Hosts the single [AudioPlayer] for the app's
/// lifetime, bridges just_audio <-> audio_service, and owns the queue via a
/// [ConcatenatingAudioSource] for gapless transitions.
class AuraAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  AuraAudioHandler({
    required StreamResolver resolver,
    AudioPlayer? player,
  })  : _resolver = resolver,
        _player = player ?? AudioPlayer() {
    _init();
  }

  final AudioPlayer _player;
  final StreamResolver _resolver;
  final ConcatenatingAudioSource _playlist =
      ConcatenatingAudioSource(children: <AudioSource>[]);

  /// Tracks aligned by index with [_playlist] children.
  final List<Track> _tracks = <Track>[];

  StreamSubscription<PlaybackEvent>? _eventSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<int?>? _indexSub;
  bool _interruptedByLoss = false;

  AudioPlayer get player => _player;

  Future<void> _init() async {
    // Configure focus + becoming-noisy handling.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    session.interruptionEventStream.listen((event) async {
      if (event.begin) {
        if (_player.playing) {
          _interruptedByLoss = true;
          await _player.pause();
        }
      } else {
        // Resume only if we paused due to a transient interruption.
        if (_interruptedByLoss &&
            event.type == AudioInterruptionType.pause) {
          _interruptedByLoss = false;
          await _player.play();
        } else {
          _interruptedByLoss = false;
        }
      }
    });

    // Becoming noisy (headphones unplugged / BT disconnect) -> pause.
    session.becomingNoisyEventStream.listen((_) {
      if (_player.playing) _player.pause();
    });

    // Mirror just_audio events to audio_service PlaybackState.
    _eventSub = _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) => _broadcastError(),
    );
    _stateSub = _player.playerStateStream.listen((_) => _broadcastState(
          _player.playbackEvent,
        ));

    // Keep the current media item + auto-advance accurate.
    _indexSub = _player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _tracks.length) {
        mediaItem.add(_toMediaItem(_tracks[index]));
      }
    });

    try {
      await _player.setAudioSource(_playlist);
    } catch (_) {
      // Empty source is fine on first run.
    }
  }

  // --- Queue management --------------------------------------------------

  /// Replaces the queue and starts at [initialIndex]. Resolves the first
  /// track immediately; subsequent tracks are resolved lazily / pre-buffered.
  Future<void> setQueueTracks(
    List<Track> tracks, {
    int initialIndex = 0,
  }) async {
    _tracks
      ..clear()
      ..addAll(tracks);

    await _playlist.clear();

    // Build placeholder sources by resolving each lazily on play. To keep it
    // robust we resolve the initial track now and append a resolved source;
    // others are appended as resolved by the pre-buffer controller.
    final initial = tracks[initialIndex];
    final source = await _resolveSource(initial);
    if (source != null) {
      await _playlist.add(source);
    }

    queue.add(tracks.map(_toMediaItem).toList());
    mediaItem.add(_toMediaItem(initial));

    await _player.seek(Duration.zero, index: 0);
    await play();
  }

  /// Appends a resolved source for [track] for gapless playback (pre-buffer).
  Future<void> stageNext(Track track) async {
    // Avoid double-staging the same next track.
    if (_playlist.length >= 2) return;
    final source = await _resolveSource(track);
    if (source != null) {
      await _playlist.add(source);
    }
  }

  Future<AudioSource?> _resolveSource(Track track) async {
    final result = await _resolver.resolve(track);
    final info = result.valueOrNull;
    if (info == null) return null;

    final uri = await AudioByteCacheManager.instance.resolvePlayableUri(info.url);
    return AudioSource.uri(
      uri,
      tag: _toMediaItem(track),
    );
  }

  // --- Transport controls ------------------------------------------------

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // Restart current track if >3s in, else go to previous.
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
    }
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffleModeEnabled(enabled);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 1.0));

  double get volume => _player.volume;

  /// Smoothly ramps volume to [target] over [duration] (network-drop fade).
  Future<void> fadeVolumeTo(double target, Duration duration) async {
    final start = _player.volume;
    final clampedTarget = target.clamp(0.0, 1.0);
    const steps = 15;
    final stepDelay = duration ~/ steps;
    for (var i = 1; i <= steps; i++) {
      final v = start + (clampedTarget - start) * (i / steps);
      await _player.setVolume(v.clamp(0.0, 1.0));
      await Future<void>.delayed(stepDelay);
    }
  }

  Duration get position => _player.position;

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  /// Disposes the engine. Call once on app teardown.
  Future<void> shutdown() async {
    await _eventSub?.cancel();
    await _stateSub?.cancel();
    await _indexSub?.cancel();
    await _player.dispose();
    await _resolver.dispose();
  }

  // --- State mapping -----------------------------------------------------

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: _mapProcessingState(_player.processingState),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }

  void _broadcastError() {
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  MediaItem _toMediaItem(Track track) {
    return MediaItem(
      id: track.id,
      title: track.displayTitle,
      artist: track.displayArtist,
      album: track.album,
      duration: track.duration,
      artUri: track.artworkUrl != null ? Uri.tryParse(track.artworkUrl!) : null,
    );
  }
}

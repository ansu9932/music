import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/play_queue.dart';
import '../../domain/entities/track.dart';

/// Holds the current [PlayQueue]. The audio engine owns actual playback, but
/// this mirror lets the UI and pre-buffer controller reason about ordering,
/// shuffle, and repeat without reaching into the handler.
class QueueController extends Notifier<PlayQueue> {
  @override
  PlayQueue build() => const PlayQueue();

  void setQueue(List<Track> tracks, {int initialIndex = 0}) {
    state = PlayQueue(
      tracks: tracks,
      currentIndex: initialIndex.clamp(0, tracks.isEmpty ? 0 : tracks.length - 1),
      repeatMode: state.repeatMode,
      shuffle: state.shuffle,
    );
  }

  void setCurrentIndex(int index) {
    if (index < 0 || index >= state.tracks.length) return;
    state = state.copyWith(currentIndex: index);
  }

  void setCurrentTrackId(String trackId) {
    final idx = state.tracks.indexWhere((t) => t.id == trackId);
    if (idx >= 0) state = state.copyWith(currentIndex: idx);
  }

  void cycleRepeatMode() {
    final next = switch (state.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    state = state.copyWith(repeatMode: next);
  }

  void toggleShuffle() => state = state.copyWith(shuffle: !state.shuffle);
}

final queueControllerProvider =
    NotifierProvider<QueueController, PlayQueue>(QueueController.new);

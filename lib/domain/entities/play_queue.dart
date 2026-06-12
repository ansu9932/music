import 'package:freezed_annotation/freezed_annotation.dart';

import 'track.dart';

part 'play_queue.freezed.dart';

/// Repeat behavior for the queue.
enum RepeatMode { off, one, all }

/// Immutable representation of the play queue and cursor.
@freezed
class PlayQueue with _$PlayQueue {
  const factory PlayQueue({
    @Default(<Track>[]) List<Track> tracks,
    @Default(0) int currentIndex,
    @Default(RepeatMode.off) RepeatMode repeatMode,
    @Default(false) bool shuffle,
  }) = _PlayQueue;

  const PlayQueue._();

  bool get isEmpty => tracks.isEmpty;
  bool get isNotEmpty => tracks.isNotEmpty;

  Track? get current =>
      (currentIndex >= 0 && currentIndex < tracks.length)
          ? tracks[currentIndex]
          : null;

  bool get hasNext {
    if (isEmpty) return false;
    if (repeatMode == RepeatMode.all || repeatMode == RepeatMode.one) {
      return true;
    }
    return currentIndex < tracks.length - 1;
  }

  bool get hasPrevious {
    if (isEmpty) return false;
    if (repeatMode == RepeatMode.all || repeatMode == RepeatMode.one) {
      return true;
    }
    return currentIndex > 0;
  }

  /// Index of the next track honoring repeat semantics, or null when the queue
  /// has genuinely ended (repeat off + at last track).
  int? get nextIndex {
    if (isEmpty) return null;
    switch (repeatMode) {
      case RepeatMode.one:
        return currentIndex;
      case RepeatMode.all:
        return (currentIndex + 1) % tracks.length;
      case RepeatMode.off:
        final next = currentIndex + 1;
        return next < tracks.length ? next : null;
    }
  }

  /// Track that will play next (for pre-buffering), or null.
  Track? get nextTrack {
    final i = nextIndex;
    if (i == null) return null;
    // For repeat-one, "next" for pre-buffer purposes is the same track; no new
    // resolution needed, so report null to avoid redundant pre-buffering.
    if (repeatMode == RepeatMode.one) return null;
    return tracks[i];
  }
}

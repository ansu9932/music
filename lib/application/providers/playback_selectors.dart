import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playback_state.dart';
import 'audio_providers.dart';

/// Fine-grained selectors derived from [playbackStateProvider] so widgets only
/// rebuild on the slice they care about.

final activeTrackIdProvider = Provider<String?>((ref) {
  return ref.watch(playbackStateProvider).valueOrNull?.track?.id;
});

final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(playbackStateProvider).valueOrNull?.isPlaying ?? false;
});

final isBufferingProvider = Provider<bool>((ref) {
  return ref.watch(playbackStateProvider).valueOrNull?.isBuffering ?? false;
});

/// Current playback state with a safe default.
final currentPlaybackProvider = Provider<PlaybackState>((ref) {
  return ref.watch(playbackStateProvider).valueOrNull ?? const PlaybackState();
});

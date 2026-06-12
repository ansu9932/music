import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/motion_tokens.dart';
import '../../data/connectivity/connectivity_service.dart';
import '../../domain/entities/track.dart';
import 'audio_providers.dart';
import 'connectivity_provider.dart';
import 'queue_controller.dart';
import 'settings_controller.dart';

/// Drives zero-lag, gapless playback by resolving + staging the next track
/// ~30s before the current one ends.
///
/// Activated by reading [preBufferControllerProvider] once at app start (the
/// Now Playing canvas does this). It listens to the position stream and stages
/// exactly one next track per current track.
class PreBufferController extends Notifier<String?> {
  String? _stagedForTrackId;

  @override
  String? build() {
    // Reset staging whenever the active track changes.
    ref.listen(playbackStateProvider, (prev, next) {
      final prevId = prev?.valueOrNull?.track?.id;
      final nextId = next.valueOrNull?.track?.id;
      if (prevId != nextId) {
        _stagedForTrackId = null;
        state = null;
      }
    });

    // High-frequency position checks for the 30s lead trigger.
    ref.listen(positionProvider, (_, posAsync) {
      final position = posAsync.valueOrNull;
      if (position != null) {
        _maybeStageNext(position);
      }
    });

    return null;
  }

  Future<void> _maybeStageNext(Duration position) async {
    final playback = ref.read(playbackStateProvider).valueOrNull;
    if (playback == null || playback.track == null) return;
    if (playback.duration <= Duration.zero) return;

    final currentId = playback.track!.id;
    if (_stagedForTrackId == currentId) return; // already staged

    final remaining = playback.duration - position;
    if (remaining > MotionTokens.preBufferLead) return;

    final Track? next = ref.read(queueControllerProvider).nextTrack;
    if (next == null) return;

    // Metered-connection guard: optionally skip pre-buffering on mobile data.
    final settings = ref.read(settingsControllerProvider);
    final status = ref.read(connectivityStatusProvider).valueOrNull;
    if (status == ConnectivityStatus.metered && !settings.preBufferOnMetered) {
      return;
    }

    // Mark first so concurrent ticks don't double-stage.
    _stagedForTrackId = currentId;
    state = next.id;
    try {
      await ref.read(audioRepositoryProvider).stageNext(next);
    } catch (_) {
      // Pre-buffer failure must never interrupt the current track; retry will
      // happen naturally at the next track transition.
      _stagedForTrackId = null;
      state = null;
    }
  }
}

final preBufferControllerProvider =
    NotifierProvider<PreBufferController, String?>(PreBufferController.new);

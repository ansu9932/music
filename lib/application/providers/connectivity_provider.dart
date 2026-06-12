import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../core/motion/motion_tokens.dart';
import '../../data/connectivity/connectivity_service.dart';
import 'audio_providers.dart';
import 'toast_controller.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Live connectivity status (online / offline / metered).
final connectivityStatusProvider = StreamProvider<ConnectivityStatus>((ref) {
  return ref.watch(connectivityServiceProvider).statusStream;
});

/// Convenience boolean: are we offline right now?
final isOfflineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider).valueOrNull;
  return status == ConnectivityStatus.offline;
});

/// Reacts to connectivity changes during playback:
///  - On drop while playing: fade audio out over 300ms, toast, pause.
///  - On restore: resume from the last known position (bounded retry).
///
/// Activated by reading [resilienceControllerProvider] once at app start.
class ResilienceController extends Notifier<void> {
  bool _droppedWhilePlaying = false;
  Duration _lastPosition = Duration.zero;
  int _retries = 0;
  static const int _maxRetries = 5;
  Timer? _reconnectTimer;

  @override
  void build() {
    ref.onDispose(() => _reconnectTimer?.cancel());

    ref.listen(connectivityStatusProvider, (prev, next) {
      final status = next.valueOrNull;
      if (status == null) return;
      if (status == ConnectivityStatus.offline) {
        _onDrop();
      } else {
        _onRestore();
      }
    });
  }

  Future<void> _onDrop() async {
    final playback = ref.read(playbackStateProvider).valueOrNull;
    if (playback == null || !playback.isPlaying) return;

    _droppedWhilePlaying = true;
    _lastPosition = playback.position;

    final audio = ref.read(audioRepositoryProvider);
    await audio.fadeVolumeTo(0, MotionTokens.audioFadeOut);
    await audio.pause();

    ref.read(toastControllerProvider.notifier).show(
          'Connection lost — will resume when back online',
          kind: FailureKind.network,
        );
  }

  void _onRestore() {
    if (!_droppedWhilePlaying) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_retries >= _maxRetries) {
      _reset();
      ref.read(toastControllerProvider.notifier).show(
            'Could not reconnect',
            kind: FailureKind.network,
          );
      return;
    }
    // Bounded exponential backoff: 1,2,4,8,16s.
    final delay = Duration(seconds: 1 << _retries);
    _retries++;
    _reconnectTimer = Timer(delay, _attemptResume);
  }

  Future<void> _attemptResume() async {
    final status = ref.read(connectivityStatusProvider).valueOrNull;
    if (status == ConnectivityStatus.offline) {
      _scheduleReconnect();
      return;
    }
    try {
      final audio = ref.read(audioRepositoryProvider);
      await audio.seek(_lastPosition);
      await audio.setVolume(1);
      await audio.play();
      _reset();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _reset() {
    _droppedWhilePlaying = false;
    _retries = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
}

final resilienceControllerProvider =
    NotifierProvider<ResilienceController, void>(ResilienceController.new);

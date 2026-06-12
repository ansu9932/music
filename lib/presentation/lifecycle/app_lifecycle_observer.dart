import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/audio_providers.dart';
import '../../application/providers/metadata_providers.dart';
import '../../application/providers/queue_controller.dart';
import '../../application/providers/playback_selectors.dart';
import '../../data/cache/artwork_cache.dart';

/// Observes app lifecycle to release resources deterministically:
///  - `paused`: evict in-memory artwork + palette caches, persist the session,
///    while keeping the audio stream alive.
///  - `detached`: dispose the audio engine.
///
/// The single audio engine is never duplicated; only released on teardown.
class AppLifecycleObserver extends ConsumerStatefulWidget {
  const AppLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLifecycleObserver> createState() =>
      _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends ConsumerState<AppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _onBackground();
      case AppLifecycleState.detached:
        _onDetached();
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _onBackground() {
    // Release non-essential memory; keep audio playing.
    ref.read(paletteServiceProvider).evictMemory();
    // Persist session context for next launch.
    _saveSession();
  }

  Future<void> _saveSession() async {
    final playback = ref.read(currentPlaybackProvider);
    final queue = ref.read(queueControllerProvider);
    await ref.read(sessionRepositoryProvider).save(
          activeTrackId: playback.track?.id,
          queueTrackIds: queue.tracks.map((t) => t.id).toList(),
          positionMs: playback.position.inMilliseconds,
          repeatMode: queue.repeatMode,
          shuffle: queue.shuffle,
        );
  }

  Future<void> _onDetached() async {
    await ArtworkCacheManager.instance.evict();
    await ref.read(audioRepositoryProvider).dispose();
  }

  @override
  void didHaveMemoryPressure() {
    // Low-memory: evict caches but preserve playback continuity.
    ArtworkCacheManager.instance.evict();
    ref.read(paletteServiceProvider).evictMemory();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

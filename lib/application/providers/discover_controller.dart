import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import 'audio_providers.dart';
import 'metadata_providers.dart';
import 'toast_controller.dart';

/// Loads trending charts: emits cached results immediately (if any), then
/// reconciles with a fresh fetch. Never throws — failures surface as toasts
/// and fall back to whatever cache exists.
class DiscoverController extends AsyncNotifier<List<Track>> {
  @override
  Future<List<Track>> build() async {
    // 1. Cached-first: show something instantly.
    final cached = await _readCache();
    if (cached != null && cached.isNotEmpty) {
      // Kick off a background refresh without blocking initial render.
      Future.microtask(refresh);
      return cached;
    }
    // 2. No cache: fetch fresh.
    return _fetch();
  }

  Future<List<Track>?> _readCache() async {
    final result = await ref.read(userRepositoryProvider).getCachedCharts();
    return result?.valueOrNull;
  }

  Future<List<Track>> _fetch() async {
    final result = await ref.read(fetchChartsProvider).call(limit: 30);
    return result.when(
      success: (tracks) {
        // Persist for offline / next launch.
        ref.read(userRepositoryProvider).cacheCharts(tracks);
        return tracks;
      },
      failure: (failure) {
        ref.read(toastControllerProvider.notifier).showFailure(failure);
        // Surface cache if present; otherwise empty (offline state shown).
        return const <Track>[];
      },
    );
  }

  /// Pull-to-refresh / background reconcile.
  Future<void> refresh() async {
    final fresh = await _fetch();
    if (fresh.isNotEmpty) {
      state = AsyncData<List<Track>>(fresh);
    }
  }
}

final discoverControllerProvider =
    AsyncNotifierProvider<DiscoverController, List<Track>>(
  DiscoverController.new,
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/history_entry.dart';
import '../../domain/entities/track.dart';
import 'audio_providers.dart';
import 'toast_controller.dart';

/// Reactive list of favorited tracks (local).
final favoritesProvider = StreamProvider<List<Track>>((ref) {
  return ref.watch(userRepositoryProvider).watchFavorites();
});

/// Whether a given track id is currently favorited (derived from the stream).
final isFavoriteProvider = Provider.family<bool, String>((ref, trackId) {
  final favorites = ref.watch(favoritesProvider).valueOrNull ?? const <Track>[];
  return favorites.any((t) => t.id == trackId);
});

/// Streaming history.
final historyProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  final result = await ref.watch(userRepositoryProvider).getHistory();
  return result.getOrElse(const <HistoryEntry>[]);
});

/// Imperative library actions (favorite toggle, history recording).
class LibraryController {
  LibraryController(this._ref);
  final Ref _ref;

  Future<void> toggleFavorite(Track track) async {
    final result = await _ref.read(userRepositoryProvider).toggleFavorite(track);
    final failure = result.failureOrNull;
    if (failure != null) {
      _ref.read(toastControllerProvider.notifier).showFailure(failure);
    }
  }

  Future<void> recordHistory(Track track) async {
    await _ref.read(userRepositoryProvider).recordHistory(track);
    _ref.invalidate(historyProvider);
  }
}

final libraryControllerProvider = Provider<LibraryController>((ref) {
  return LibraryController(ref);
});

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import 'metadata_providers.dart';
import 'toast_controller.dart';

/// Current search query (driven by the search field).
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Debounced, cancellable search results for [searchQueryProvider].
///
/// Uses `autoDispose` so subscriptions are released when the search field is
/// dismissed. A 300ms debounce avoids hammering the API on every keystroke.
final searchResultsProvider =
    FutureProvider.autoDispose<List<Track>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const <Track>[];

  // Debounce: wait, but bail out if the query changed (provider re-run) or the
  // widget was disposed.
  var cancelled = false;
  ref.onDispose(() => cancelled = true);
  await Future<void>.delayed(const Duration(milliseconds: 300));
  if (cancelled) return const <Track>[];

  final result = await ref.read(searchTracksProvider).call(query, limit: 30);
  return result.when(
    success: (tracks) => tracks,
    failure: (failure) {
      ref.read(toastControllerProvider.notifier).showFailure(failure);
      return const <Track>[];
    },
  );
});

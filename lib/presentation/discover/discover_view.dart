import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/connectivity_provider.dart';
import '../../application/providers/discover_controller.dart';
import '../../application/providers/player_controller.dart';
import '../../application/providers/playback_selectors.dart';
import '../../application/providers/search_controller.dart';
import '../../core/theme/aura_colors.dart';
import '../../domain/entities/track.dart';
import 'offline_state.dart';
import 'track_tile.dart';

/// The unified Discover/Search surface — the app's landing view.
class DiscoverView extends ConsumerStatefulWidget {
  const DiscoverView({super.key});

  @override
  ConsumerState<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends ConsumerState<DiscoverView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _navigating = false; // debounce duplicate taps during Hero flight

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openTrack(Track track, List<Track> context) async {
    if (_navigating) return;
    _navigating = true;

    // Begin resolution + playback immediately.
    await ref.read(playerControllerProvider).playTrack(
          track,
          contextTracks: context,
        );

    if (!mounted) return;
    // Navigate to the Now Playing canvas (shared-element morph via Hero).
    this.context.push('/now-playing');
    _navigating = false;
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final isSearching = query.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _Header(controller: _searchController),
            Expanded(
              child: isSearching
                  ? _SearchResults(onTap: _openTrack)
                  : _Charts(
                      scrollController: _scrollController,
                      onTap: _openTrack,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Aura',
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            onChanged: (value) =>
                ref.read(searchQueryProvider.notifier).state = value,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: AuraColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search tracks, artists…',
              hintStyle: const TextStyle(color: AuraColors.textSecondary),
              prefixIcon:
                  const Icon(Icons.search, color: AuraColors.textSecondary),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close,
                          color: AuraColors.textSecondary, size: 18),
                      onPressed: () {
                        controller.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    ),
              filled: true,
              fillColor: AuraColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Charts extends ConsumerWidget {
  const _Charts({required this.scrollController, required this.onTap});
  final ScrollController scrollController;
  final void Function(Track, List<Track>) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartsAsync = ref.watch(discoverControllerProvider);
    final activeId = ref.watch(activeTrackIdProvider);
    final offline = ref.watch(isOfflineProvider);

    return chartsAsync.when(
      loading: () => const _Loader(),
      error: (_, __) => OfflineState(
        onRetry: () => ref.read(discoverControllerProvider.notifier).refresh(),
        message: 'Could not load charts',
      ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return OfflineState(
            onRetry: () =>
                ref.read(discoverControllerProvider.notifier).refresh(),
            message: offline ? 'You\'re offline' : 'No tracks found',
            icon: offline ? Icons.cloud_off_rounded : Icons.library_music_outlined,
          );
        }
        return RefreshIndicator(
          color: AuraColors.textPrimary,
          backgroundColor: AuraColors.graphite,
          onRefresh: () =>
              ref.read(discoverControllerProvider.notifier).refresh(),
          child: ListView.builder(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 4, bottom: 32),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return TrackTile(
                track: track,
                isActive: track.id == activeId,
                onTap: () => onTap(track, tracks),
              );
            },
          ),
        );
      },
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.onTap});
  final void Function(Track, List<Track>) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider);
    final activeId = ref.watch(activeTrackIdProvider);

    return resultsAsync.when(
      loading: () => const _Loader(),
      error: (_, __) => const OfflineState(
        onRetry: _noop,
        message: 'Search failed',
      ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return const Center(
            child: Text(
              'No results',
              style: TextStyle(color: AuraColors.textSecondary, fontSize: 15),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 32),
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return TrackTile(
              track: track,
              isActive: track.id == activeId,
              onTap: () => onTap(track, tracks),
            );
          },
        );
      },
    );
  }
}

void _noop() {}

class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AuraColors.textSecondary,
        ),
      ),
    );
  }
}

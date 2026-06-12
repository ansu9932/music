import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/audio_providers.dart';
import '../../application/providers/connectivity_provider.dart';
import '../../application/providers/palette_controller.dart';
import '../../application/providers/playback_selectors.dart';
import '../../application/providers/player_controller.dart';
import '../../application/providers/pre_buffer_controller.dart';
import '../../application/providers/queue_controller.dart';
import '../../core/theme/aura_colors.dart';
import '../../domain/entities/aura_palette.dart';
import '../../domain/entities/play_queue.dart';
import '../discover/track_tile.dart';
import 'blur_gradient_background.dart';
import 'favorite_button.dart';
import 'play_pause_morph.dart';
import 'progress_bar.dart';

/// Full-screen immersive playback surface. Reached via the shared-element
/// morph from the Discover list. Dismissed with a downward swipe (playback
/// continues).
class NowPlayingCanvas extends ConsumerStatefulWidget {
  const NowPlayingCanvas({super.key});

  @override
  ConsumerState<NowPlayingCanvas> createState() => _NowPlayingCanvasState();
}

class _NowPlayingCanvasState extends ConsumerState<NowPlayingCanvas> {
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    // Activate the pre-buffer + connection-resilience controllers for the
    // lifetime of this canvas.
    Future.microtask(() {
      ref.read(preBufferControllerProvider);
      ref.read(resilienceControllerProvider);
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (d.primaryDelta == null) return;
    setState(() => _dragOffset = (_dragOffset + d.primaryDelta!).clamp(0, 600));
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    if (_dragOffset > 120 || velocity > 700) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(currentPlaybackProvider);
    final track = playback.track;
    final isPlaying = ref.watch(isPlayingProvider);
    final isBuffering = ref.watch(isBufferingProvider);
    final queue = ref.watch(queueControllerProvider);

    // Palette for the active track's artwork (always resolves; safe default).
    final palette = track == null
        ? AuraPalette.fallback
        : ref
                .watch(paletteProvider((
                  trackId: track.id,
                  artworkUrl: track.artworkUrl,
                )))
                .valueOrNull ??
            AuraPalette.fallback;

    return Scaffold(
      backgroundColor: AuraColors.background,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: BlurGradientBackground(palette: palette)),
          // Subtle scrim for legibility.
          const Positioned.fill(
            child: ColoredBox(color: Color(0x33000000)),
          ),
          GestureDetector(
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: SafeArea(
                child: track == null
                    ? const _EmptyNowPlaying()
                    : _Content(
                        artworkUrl: track.artworkUrl,
                        heroTag: track.heroTag,
                        title: track.displayTitle,
                        artist: track.displayArtist,
                        isPlaying: isPlaying,
                        isBuffering: isBuffering,
                        repeatMode: queue.repeatMode,
                        shuffle: queue.shuffle,
                        favoriteChild: FavoriteButton(track: track),
                        onPlayPause: () =>
                            ref.read(playerControllerProvider).togglePlayPause(
                                  isPlaying,
                                ),
                        onNext: () =>
                            ref.read(playerControllerProvider).next(),
                        onPrevious: () =>
                            ref.read(playerControllerProvider).previous(),
                        onShuffle: () =>
                            ref.read(playerControllerProvider).toggleShuffle(),
                        onRepeat: () =>
                            ref.read(playerControllerProvider).cycleRepeat(),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatefulWidget {
  const _Content({
    required this.artworkUrl,
    required this.heroTag,
    required this.title,
    required this.artist,
    required this.isPlaying,
    required this.isBuffering,
    required this.repeatMode,
    required this.shuffle,
    required this.favoriteChild,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onShuffle,
    required this.onRepeat,
  });

  final String? artworkUrl;
  final String heroTag;
  final String title;
  final String artist;
  final bool isPlaying;
  final bool isBuffering;
  final RepeatMode repeatMode;
  final bool shuffle;
  final Widget favoriteChild;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  bool _secondaryVisible = false; // volume/extra controls hidden by default

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final artSize = width * 0.8;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: <Widget>[
          // Top bar: dismiss affordance + favorite.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: AuraColors.textPrimary, size: 28),
              ),
              widget.favoriteChild,
            ],
          ),
          const Spacer(),
          Hero(
            tag: widget.heroTag,
            child: AuraThumbnail(
              url: widget.artworkUrl,
              size: artSize,
              radius: 16,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            widget.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AuraColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 28),
          const ProgressBar(),
          const SizedBox(height: 20),
          // Primary transport controls.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _SecondaryControl(
                icon: Icons.shuffle,
                active: widget.shuffle,
                onTap: widget.onShuffle,
              ),
              IconButton(
                iconSize: 34,
                onPressed: widget.onPrevious,
                icon: const Icon(Icons.skip_previous,
                    color: AuraColors.textPrimary),
              ),
              SizedBox(
                width: 72,
                height: 72,
                child: widget.isBuffering
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AuraColors.textPrimary,
                          ),
                        ),
                      )
                    : PlayPauseMorph(
                        isPlaying: widget.isPlaying,
                        onTap: widget.onPlayPause,
                      ),
              ),
              IconButton(
                iconSize: 34,
                onPressed: widget.onNext,
                icon: const Icon(Icons.skip_next,
                    color: AuraColors.textPrimary),
              ),
              _SecondaryControl(
                icon: _repeatIcon(widget.repeatMode),
                active: widget.repeatMode != RepeatMode.off,
                onTap: widget.onRepeat,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Secondary controls (volume) hidden until revealed.
          GestureDetector(
            onTap: () => setState(() => _secondaryVisible = !_secondaryVisible),
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _secondaryVisible
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(
                height: 28,
                child: Center(
                  child: Icon(Icons.expand_less,
                      color: AuraColors.textSecondary, size: 20),
                ),
              ),
              secondChild: const _VolumeRow(),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  IconData _repeatIcon(RepeatMode mode) => switch (mode) {
        RepeatMode.one => Icons.repeat_one,
        RepeatMode.all => Icons.repeat_on,
        RepeatMode.off => Icons.repeat,
      };
}

class _SecondaryControl extends StatelessWidget {
  const _SecondaryControl({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 22,
      onPressed: onTap,
      icon: Icon(
        icon,
        color: active ? AuraColors.textPrimary : AuraColors.textSecondary,
      ),
    );
  }
}

class _VolumeRow extends ConsumerStatefulWidget {
  const _VolumeRow();

  @override
  ConsumerState<_VolumeRow> createState() => _VolumeRowState();
}

class _VolumeRowState extends ConsumerState<_VolumeRow> {
  double _volume = 1;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.volume_down,
            color: AuraColors.textSecondary, size: 18),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: AuraColors.textPrimary,
              inactiveTrackColor: AuraColors.graphiteSoft,
              thumbColor: AuraColors.textPrimary,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: _volume,
              onChanged: (v) {
                setState(() => _volume = v);
                ref.read(audioRepositoryProvider).setVolume(v);
              },
            ),
          ),
        ),
        const Icon(Icons.volume_up,
            color: AuraColors.textSecondary, size: 18),
      ],
    );
  }
}

class _EmptyNowPlaying extends StatelessWidget {
  const _EmptyNowPlaying();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Nothing playing',
        style: TextStyle(color: AuraColors.textSecondary, fontSize: 15),
      ),
    );
  }
}

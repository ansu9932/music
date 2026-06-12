import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/audio_providers.dart';
import '../../application/providers/playback_selectors.dart';
import '../../application/providers/player_controller.dart';
import '../../core/theme/aura_colors.dart';

/// A smooth, scrubbable progress bar.
///
/// Position stream events are discrete (~200ms), so the filled portion is
/// glided to the latest value with a short linear tween to avoid snapping.
/// While the user scrubs, a live preview overrides the playback position and
/// the seek is applied on release.
class ProgressBar extends ConsumerStatefulWidget {
  const ProgressBar({super.key});

  @override
  ConsumerState<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends ConsumerState<ProgressBar> {
  double? _dragFraction;

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(currentPlaybackProvider);
    final position = ref.watch(positionProvider).valueOrNull ?? playback.position;
    final total = playback.duration;

    final liveFraction = (total.inMilliseconds <= 0)
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final shownFraction = _dragFraction ?? liveFraction;

    final shownPosition = _dragFraction != null
        ? Duration(
            milliseconds: (_dragFraction! * total.inMilliseconds).round())
        : position;

    return Column(
      children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) => _updateDrag(d.localPosition.dx, width),
              onHorizontalDragUpdate: (d) =>
                  _updateDrag(d.localPosition.dx, width),
              onHorizontalDragEnd: (_) => _commitDrag(total),
              onTapDown: (d) => _updateDrag(d.localPosition.dx, width),
              onTapUp: (_) => _commitDrag(total),
              child: SizedBox(
                height: 24,
                child: Center(
                  child: _dragFraction != null
                      ? _Bar(fraction: shownFraction)
                      // Glide to the latest fraction between stream ticks.
                      : TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                              begin: shownFraction, end: shownFraction),
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.linear,
                          builder: (_, value, __) => _Bar(fraction: value),
                        ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(_fmt(shownPosition), style: _timeStyle),
              Text(_fmt(total), style: _timeStyle),
            ],
          ),
        ),
      ],
    );
  }

  void _updateDrag(double dx, double width) {
    if (width <= 0) return;
    setState(() => _dragFraction = (dx / width).clamp(0.0, 1.0));
  }

  Future<void> _commitDrag(Duration total) async {
    final fraction = _dragFraction;
    if (fraction == null) return;
    final target =
        Duration(milliseconds: (fraction * total.inMilliseconds).round());
    await ref.read(playerControllerProvider).seek(target);
    if (mounted) setState(() => _dragFraction = null);
  }

  static const TextStyle _timeStyle =
      TextStyle(color: AuraColors.textSecondary, fontSize: 11);

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Stack(
        children: <Widget>[
          Container(height: 4, color: AuraColors.graphiteSoft),
          FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: Container(height: 4, color: AuraColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

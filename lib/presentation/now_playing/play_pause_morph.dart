import 'package:flutter/material.dart';

import '../../core/motion/motion_tokens.dart';
import '../../core/theme/aura_colors.dart';

/// Play/pause control whose icon morphs via vector interpolation
/// (`AnimatedIcon`) rather than swapping discrete glyphs.
class PlayPauseMorph extends StatefulWidget {
  const PlayPauseMorph({
    required this.isPlaying,
    required this.onTap,
    this.size = 72,
    super.key,
  });

  final bool isPlaying;
  final VoidCallback onTap;
  final double size;

  @override
  State<PlayPauseMorph> createState() => _PlayPauseMorphState();
}

class _PlayPauseMorphState extends State<PlayPauseMorph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MotionTokens.microInteract,
      value: widget.isPlaying ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant PlayPauseMorph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
          color: AuraColors.textPrimary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AnimatedIcon(
            icon: AnimatedIcons.play_pause,
            progress: _controller,
            size: widget.size * 0.42,
            color: AuraColors.background,
          ),
        ),
      ),
    );
  }
}

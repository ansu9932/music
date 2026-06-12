import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/motion/motion_resolver.dart';
import '../../core/motion/motion_tokens.dart';
import '../../core/theme/aura_colors.dart';
import '../../domain/entities/aura_palette.dart';

/// Live, heavily-blurred, slow-pulsing gradient derived from the active
/// track's [AuraPalette]. Cross-fades when the palette changes. Renders a
/// static gradient when reduce-motion is enabled.
class BlurGradientBackground extends StatefulWidget {
  const BlurGradientBackground({required this.palette, super.key});

  final AuraPalette palette;

  @override
  State<BlurGradientBackground> createState() => _BlurGradientBackgroundState();
}

class _BlurGradientBackgroundState extends State<BlurGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: MotionTokens.backgroundPulse,
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MotionResolver.shouldReduceMotion(context);
    if (reduceMotion) {
      if (_pulse.isAnimating) _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }

    return AnimatedSwitcher(
      duration: MotionTokens.paletteCrossFade,
      child: RepaintBoundary(
        key: ValueKey<int>(widget.palette.dominantArgb),
        child: reduceMotion
            ? _GradientLayer(palette: widget.palette, t: 0.5)
            : AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => _GradientLayer(
                  palette: widget.palette,
                  t: Curves.easeInOut.transform(_pulse.value),
                ),
              ),
      ),
    );
  }
}

class _GradientLayer extends StatelessWidget {
  const _GradientLayer({required this.palette, required this.t});

  final AuraPalette palette;
  final double t; // 0..1 pulse phase

  @override
  Widget build(BuildContext context) {
    // Pulse subtly shifts the gradient focal point + radius.
    final alignment = Alignment(
      _lerp(-0.4, 0.4, t),
      _lerp(-0.6, -0.2, t),
    );
    final radius = _lerp(1.1, 1.5, t);

    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: alignment,
            radius: radius,
            colors: palette.gradientColors,
            stops: const <double>[0.0, 0.4, 0.75, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// Default background shown before a palette resolves.
class DefaultBlurBackground extends StatelessWidget {
  const DefaultBlurBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AuraColors.background,
      child: BlurGradientBackground(palette: AuraPalette.fallback),
    );
  }
}

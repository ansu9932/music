import 'package:flutter/material.dart';

import '../../core/motion/motion_resolver.dart';
import '../../core/motion/motion_tokens.dart';

/// Shared transition for the Discover -> Now Playing morph.
///
/// The album artwork is morphed by a `Hero(tag: track.heroTag)` present on
/// both surfaces; this builder animates the surrounding content with a fade +
/// gentle slide (or a plain cross-fade when reduce-motion is enabled).
///
/// Used both by [MorphPageRoute] (imperative `Navigator.push`) and by the
/// go_router `CustomTransitionPage` so behavior is identical regardless of how
/// the canvas is reached.
Widget buildMorphTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child, {
  bool? reduceMotion,
}) {
  final reduce = reduceMotion ?? MotionResolver.shouldReduceMotion(context);
  final curved = CurvedAnimation(
    parent: animation,
    curve: MotionTokens.canvasMorphCurve,
    reverseCurve: MotionTokens.canvasMorphCurve.flipped,
  );
  if (reduce) {
    return FadeTransition(opacity: curved, child: child);
  }
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

/// Duration of the morph honoring reduce-motion.
Duration morphDuration(BuildContext context) =>
    MotionResolver.shouldReduceMotion(context)
        ? const Duration(milliseconds: 200)
        : MotionTokens.canvasMorph;

/// Imperative variant (kept for non-router navigation / tests).
class MorphPageRoute<T> extends PageRouteBuilder<T> {
  MorphPageRoute({
    required this.builder,
    required bool reduceMotion,
  }) : super(
          opaque: false,
          transitionDuration: reduceMotion
              ? const Duration(milliseconds: 200)
              : MotionTokens.canvasMorph,
          reverseTransitionDuration: reduceMotion
              ? const Duration(milliseconds: 200)
              : MotionTokens.canvasMorph,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondary, child) =>
              buildMorphTransition(
            context,
            animation,
            secondary,
            child,
            reduceMotion: reduceMotion,
          ),
        );

  final WidgetBuilder builder;

  static MorphPageRoute<T> to<T>(
    BuildContext context,
    WidgetBuilder builder,
  ) {
    return MorphPageRoute<T>(
      builder: builder,
      reduceMotion: MotionResolver.shouldReduceMotion(context),
    );
  }
}

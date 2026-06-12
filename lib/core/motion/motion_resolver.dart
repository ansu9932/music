import 'package:flutter/widgets.dart';

/// Resolves whether motion should be reduced, honoring the OS accessibility
/// setting (`disableAnimations`).
///
/// Use [MotionResolver.of] within a widget tree, or [shouldReduceMotion] with
/// a [BuildContext] for one-off checks.
abstract final class MotionResolver {
  const MotionResolver._();

  /// Reads the platform "reduce motion" / "disable animations" preference.
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Returns [full] unless reduce-motion is enabled, in which case [reduced]
  /// (defaulting to [Duration.zero]) is returned.
  static Duration duration(
    BuildContext context,
    Duration full, {
    Duration reduced = Duration.zero,
  }) {
    return shouldReduceMotion(context) ? reduced : full;
  }
}

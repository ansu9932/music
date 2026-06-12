import 'package:flutter/widgets.dart';

/// Monochromatic dark palette for Aura Player.
///
/// Anchored on pure black with soft graphite accents. These tokens are the
/// single source of truth for color across the app.
abstract final class AuraColors {
  const AuraColors._();

  /// Pure pitch black — the canvas everything sits on.
  static const Color background = Color(0xFF000000);

  /// Slightly lifted surface for cards / sheets.
  static const Color surface = Color(0xFF0A0A0A);

  /// Primary graphite accent.
  static const Color graphite = Color(0xFF1C1C1E);

  /// Softer graphite for hover / pressed / secondary fills.
  static const Color graphiteSoft = Color(0xFF2C2C2E);

  /// Primary text (near-white, never pure white to reduce glare).
  static const Color textPrimary = Color(0xFFF2F2F2);

  /// Secondary / supporting text.
  static const Color textSecondary = Color(0xFF8E8E93);

  /// Subtle dividers / outlines.
  static const Color outline = Color(0xFF1F1F22);

  /// Network / error toast accent.
  static const Color error = Color(0xFFFF6B6B);

  /// Default fallback palette colors (used when extraction fails).
  static const Color fallbackDominant = graphite;
  static const Color fallbackVibrant = graphiteSoft;
  static const Color fallbackMuted = surface;
}

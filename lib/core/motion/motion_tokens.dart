import 'package:flutter/animation.dart';

/// Centralized motion design tokens.
///
/// Every animated surface references these so timing stays consistent and the
/// "soothing, fluid" feel is preserved app-wide.
abstract final class MotionTokens {
  const MotionTokens._();

  /// Library <-> Now Playing shared-element morph.
  static const Duration canvasMorph = Duration(milliseconds: 320);
  static const Curve canvasMorphCurve = Curves.easeOutCubic;

  /// Small control state changes (toggles, taps).
  static const Duration microInteract = Duration(milliseconds: 180);
  static const Curve microInteractCurve = Curves.easeOut;

  /// Smooth fade applied when a network drop interrupts audio.
  static const Duration audioFadeOut = Duration(milliseconds: 300);

  /// Slow pulse of the Now Playing blurred background.
  static const Duration backgroundPulse = Duration(seconds: 10);
  static const Curve backgroundPulseCurve = Curves.easeInOut;

  /// Palette / background cross-fade when the active track changes.
  static const Duration paletteCrossFade = Duration(milliseconds: 600);

  /// Toast lifecycle.
  static const Duration toastFadeIn = Duration(milliseconds: 200);
  static const Duration toastHold = Duration(milliseconds: 2600);
  static const Duration toastFadeOut = Duration(milliseconds: 200);

  /// Lead time before the current track ends to begin pre-buffering the next.
  static const Duration preBufferLead = Duration(seconds: 30);
}

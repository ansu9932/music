import 'package:flutter/painting.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/theme/aura_colors.dart';

part 'aura_palette.freezed.dart';

/// Dominant colors extracted from an artwork image, used to paint the
/// Now Playing blurred gradient background.
@freezed
class AuraPalette with _$AuraPalette {
  const factory AuraPalette({
    required int dominantArgb,
    required int vibrantArgb,
    required int mutedArgb,
  }) = _AuraPalette;

  const AuraPalette._();

  factory AuraPalette.fromColors({
    required Color dominant,
    required Color vibrant,
    required Color muted,
  }) {
    return AuraPalette(
      dominantArgb: dominant.value,
      vibrantArgb: vibrant.value,
      mutedArgb: muted.value,
    );
  }

  /// The default graphite-on-black palette used when extraction fails.
  static const AuraPalette fallback = AuraPalette(
    dominantArgb: 0xFF1C1C1E,
    vibrantArgb: 0xFF2C2C2E,
    mutedArgb: 0xFF0A0A0A,
  );

  Color get dominant => Color(dominantArgb);
  Color get vibrant => Color(vibrantArgb);
  Color get muted => Color(mutedArgb);

  /// Gradient stops for the blurred background, always darkened toward pure
  /// black at the edges to preserve the monochromatic identity.
  List<Color> get gradientColors => <Color>[
        Color.lerp(dominant, AuraColors.background, 0.35)!,
        Color.lerp(vibrant, AuraColors.background, 0.55)!,
        Color.lerp(muted, AuraColors.background, 0.7)!,
        AuraColors.background,
      ];
}

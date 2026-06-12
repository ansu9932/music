import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'aura_colors.dart';

/// Builds the single dark [ThemeData] used app-wide.
///
/// Typography uses Inter (bundled) with the platform San Francisco family as a
/// graceful fallback on macOS when the Inter assets are absent.
abstract final class AuraTheme {
  const AuraTheme._();

  static const String _fontFamily = 'Inter';

  /// Fallbacks resolve to San Francisco on Apple platforms, Roboto elsewhere.
  static const List<String> _fontFallback = <String>[
    '.SF Pro Text',
    '.SF UI Text',
    'SF Pro Text',
    'Roboto',
  ];

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      surface: AuraColors.background,
      primary: AuraColors.textPrimary,
      secondary: AuraColors.graphiteSoft,
      error: AuraColors.error,
      onSurface: AuraColors.textPrimary,
      onPrimary: AuraColors.background,
      outline: AuraColors.outline,
    );

    final baseTextTheme = _textTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AuraColors.background,
      canvasColor: AuraColors.background,
      colorScheme: colorScheme,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFallback,
      textTheme: baseTextTheme,
      splashFactory: InkSparkle.splashFactory,
      // Generous whitespace + anti-aliasing are the defaults; we simply avoid
      // dividers and heavy chrome.
      dividerTheme: const DividerThemeData(
        color: AuraColors.outline,
        thickness: 0.5,
        space: 0.5,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AuraColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      iconTheme: const IconThemeData(color: AuraColors.textPrimary),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AuraColors.textPrimary,
        selectionColor: AuraColors.graphiteSoft,
        selectionHandleColor: AuraColors.graphiteSoft,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 34,
        height: 1.1,
        letterSpacing: -0.5,
        color: AuraColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 22,
        letterSpacing: -0.3,
        color: AuraColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 17,
        color: AuraColors.textPrimary,
      ),
      // Track tile title.
      bodyLarge: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 15,
        color: AuraColors.textPrimary,
      ),
      // Track tile artist / supporting text.
      bodyMedium: TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 13,
        color: AuraColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 13,
        color: AuraColors.textSecondary,
      ),
    );
  }
}

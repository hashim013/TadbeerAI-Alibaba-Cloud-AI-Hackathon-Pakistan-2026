import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography for Tadbeer AI 2.0 — Inter (Google Fonts), sized for a
/// premium fintech feel on mobile.
abstract final class AppTypography {
  /// Base Inter text theme for the given brightness.
  static TextTheme inter(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;
    final theme = GoogleFonts.interTextTheme(base);

    return theme.copyWith(
      displaySmall: theme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.15,
        textBaseline: TextBaseline.alphabetic,
      ),
      headlineLarge: theme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
        textBaseline: TextBaseline.alphabetic,
      ),
      headlineMedium: theme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.25,
        textBaseline: TextBaseline.alphabetic,
      ),
      headlineSmall: theme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.25,
        textBaseline: TextBaseline.alphabetic,
      ),
      titleLarge: theme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        textBaseline: TextBaseline.alphabetic,
      ),
      titleMedium: theme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.3,
        textBaseline: TextBaseline.alphabetic,
      ),
      titleSmall: theme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.35,
        textBaseline: TextBaseline.alphabetic,
      ),
      bodyLarge: theme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.45,
        textBaseline: TextBaseline.alphabetic,
      ),
      bodyMedium: theme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.4,
        textBaseline: TextBaseline.alphabetic,
      ),
      bodySmall: theme.bodySmall?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.35,
        textBaseline: TextBaseline.alphabetic,
      ),
      labelLarge: theme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.2,
        textBaseline: TextBaseline.alphabetic,
      ),
      labelMedium: theme.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        height: 1.2,
        textBaseline: TextBaseline.alphabetic,
      ),
      labelSmall: theme.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        height: 1.2,
        textBaseline: TextBaseline.alphabetic,
      ),
    );
  }

  /// One-line marketing tagline with a teal accent on the brand name.
  static Widget brandTagline({
    required String tagline,
    required TextStyle style,
  }) {
    return Text(
      tagline,
      style: style.copyWith(color: AppColors.textOnDarkSecondary),
      textAlign: TextAlign.center,
    );
  }
}

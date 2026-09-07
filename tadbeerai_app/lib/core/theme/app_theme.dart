import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Material themes for Tadbeer AI 2.0.
///
/// Dark is the primary direction (deep navy canvas, teal accents); the light
/// variant uses a luminous teal-to-blue gradient canvas with carefully tuned
/// contrast so every text element stays readable.
abstract final class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textTheme = AppTypography.inter(brightness);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: brightness,
      primary: isDark ? AppColors.teal : AppColors.navyBg,
      onPrimary: isDark ? AppColors.navyBg : Colors.white,
      secondary: isDark ? AppColors.mint : AppColors.blue,
      onSecondary: Colors.white,
      surface: isDark ? AppColors.navySurface : AppColors.lightSurface,
      onSurface: isDark ? AppColors.textOnDark : AppColors.textOnLight,
      surfaceContainerHighest:
          isDark ? AppColors.navyElevated : AppColors.lightSurfaceVariant,
      onSurfaceVariant: isDark
          ? AppColors.textOnDarkSecondary
          : AppColors.textOnLightSecondary,
      error: AppColors.danger,
      onError: isDark ? AppColors.navyBg : Colors.white,
      outline: isDark ? AppColors.borderDark : AppColors.borderLight,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppColors.navyBg : AppColors.lightBg,
      textTheme: textTheme,
      canvasColor: isDark ? AppColors.navyBg : AppColors.lightBg,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.navyBg : Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: buttonShape,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
          elevation: isDark ? 0 : 2,
          shadowColor: isDark ? null : AppColors.navyBg.withValues(alpha: 0.25),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: scheme.primary, width: 1.4),
          shape: buttonShape,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.navyCard : AppColors.lightCard,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: _inputBorder(
          isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        enabledBorder: _inputBorder(
          isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        focusedBorder: _inputBorder(scheme.primary, width: 1.6),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.6),
        prefixIconColor: isDark
            ? AppColors.textOnDarkSecondary
            : AppColors.textOnLightSecondary,
        suffixIconColor: isDark
            ? AppColors.textOnDarkSecondary
            : AppColors.textOnLightSecondary,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: isDark
              ? AppColors.textOnDarkTertiary
              : AppColors.textOnLightTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: isDark
              ? AppColors.textOnDarkSecondary
              : AppColors.textOnLightSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: scheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.danger,
          fontWeight: FontWeight.w500,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.navySurface : AppColors.lightCard,
        indicatorColor: Colors.transparent,
        elevation: isDark ? 0 : 1,
        shadowColor: isDark ? null : AppColors.lightCardShadow,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? IconThemeData(size: 25, color: scheme.primary)
              : IconThemeData(
                  size: 25,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : AppColors.textOnLightTertiary,
                ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : (isDark
                    ? const Color(0xFF64748B)
                    : AppColors.textOnLightTertiary),
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.navyElevated : AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.navyCard : AppColors.lightCard,
        elevation: isDark ? 0 : 2,
        margin: EdgeInsets.zero,
        shadowColor: isDark ? null : const Color(0x140F2740),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.borderDark : AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.navyElevated : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? AppColors.navyElevated : AppColors.textOnLight,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? AppColors.textOnDark : Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: isDark
            ? AppColors.textOnDarkSecondary
            : AppColors.textOnLightSecondary,
        textColor: scheme.onSurface,
      ),
      iconTheme: IconThemeData(
        color: isDark
            ? AppColors.textOnDarkSecondary
            : AppColors.textOnLightSecondary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor:
            isDark ? AppColors.navyCard : AppColors.lightSurfaceVariant,
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.navyElevated : AppColors.textOnLight,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: isDark ? AppColors.textOnDark : Colors.white,
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Global scroll behavior that enforces clamping physics and eliminates
/// infinite stretching, rubber-banding, and overscroll bounce across the whole app.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

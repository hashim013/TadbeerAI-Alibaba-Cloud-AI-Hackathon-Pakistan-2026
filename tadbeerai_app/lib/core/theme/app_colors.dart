import 'package:flutter/material.dart';

/// Tadbeer AI 2.0 brand palette.
///
/// Derived from the official logo: a deep navy canvas with teal/turquoise
/// and mint accents. Dark is the primary product direction; the light variant
/// uses a luminous teal-to-blue gradient canvas with high-contrast text.
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────
  static const Color teal = Color(0xFF2DD4BF);
  static const Color tealDark = Color(0xFF14B8A6);
  static const Color tealDeep = Color(0xFF0D9488);
  static const Color mint = Color(0xFF6EE7B7);
  static const Color emerald = Color(0xFF26BD83);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueDeep = Color(0xFF1D4ED8);

  // ── Dark canvas (Exact Tadbeer AI Logo Background: #010717) ───────────
  static const Color navyBg = Color(0xFF010717);
  static const Color navySurface = Color(0xFF071224);
  static const Color navyCard = Color(0xFF0D1C34);
  static const Color navyElevated = Color(0xFF142746);

  // ── Light canvas (Teal Light + Blue Light Background) ────────────────
  static const Color lightBg = Color(0xFFB0D0D8); // Bold pastel teal canvas
  static const Color lightSurface = Color(0xFFC2DCE0); // Soft teal surface
  static const Color lightCard = Color(0xFFFFFFFF); // Pure white cards
  static const Color lightSurfaceVariant =
      Color(0xFFA4C6D0); // Teal-tinted variant
  static const Color lightBlueSurface = Color(0xFFB4CAE4); // Airy blue surface
  static const Color lightCardElevated =
      Color(0xFFD8E8EC); // Elevated card tone

  // ── Light Theme Gradient (Teal Light + Blue Light Background) ─────────
  static const LinearGradient lightThemeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF94D0C2), // Bold pastel teal
      Color(0xFFA8CED6), // Aqua-teal blend
      Color(0xFFA2C2DE), // Bold sky blue
      Color(0xFFB8CFEA), // Pearl blue
    ],
    stops: [0.0, 0.35, 0.72, 1.0],
  );

  // ── Text ─────────────────────────────────────────────────────────────
  static const Color textOnDark = Color(0xFFF8FAFC);
  static const Color textOnDarkSecondary = Color(0xFFCBD5E1);
  static const Color textOnDarkTertiary = Color(0xFF94A3B8);
  static const Color textOnLight = Color(0xFF0F2740); // Deep navy on light
  static const Color textOnLightSecondary =
      Color(0xFF3E5C76); // Muted slate-blue
  static const Color textOnLightTertiary = Color(0xFF6B8AAB); // Light tertiary

  // ── Semantic ─────────────────────────────────────────────────────────
  static const Color success = mint;
  static const Color danger = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);
  static const Color info = Color(0xFF60A5FA);

  // ── Lines & glows ────────────────────────────────────────────────────
  static const Color borderDark = Color(0x3338BDF8);
  static const Color borderLight =
      Color(0x30356B8A); // Slightly stronger for visibility
  static const Color tealGlow = Color(0x332DD4BF);

  // ── Light-mode shadow helper ──────────────────────────────────────────
  static const Color lightCardShadow =
      Color(0x0A0E243D); // Subtle blue-tinted shadow
}

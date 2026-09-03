import 'package:flutter/material.dart';

/// Tadbeer AI 2.0 brand palette.
///
/// Derived from the official logo: a deep navy canvas with teal/turquoise
/// and mint accents. Dark is the primary product direction.
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────
  static const Color teal = Color(0xFF2DD4BF);
  static const Color tealDark = Color(0xFF14B8A6);
  static const Color tealDeep = Color(0xFF0D9488);
  static const Color mint = Color(0xFF6EE7B7);
  static const Color emerald = Color(0xFF26BD83);

  // ── Dark canvas (Exact Tadbeer AI Logo Background: #010717) ───────────
  static const Color navyBg = Color(0xFF010717);
  static const Color navySurface = Color(0xFF071224);
  static const Color navyCard = Color(0xFF0D1C34);
  static const Color navyElevated = Color(0xFF142746);

  // ── Light canvas ──────────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF6F8FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);

  // ── Text ─────────────────────────────────────────────────────────────
  static const Color textOnDark = Color(0xFFF8FAFC);
  static const Color textOnDarkSecondary = Color(0xFFCBD5E1);
  static const Color textOnDarkTertiary = Color(0xFF94A3B8);
  static const Color textOnLight = Color(0xFF0B1526);
  static const Color textOnLightSecondary = Color(0xFF5B6B84);

  // ── Semantic ─────────────────────────────────────────────────────────
  static const Color success = mint;
  static const Color danger = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);
  static const Color info = Color(0xFF60A5FA);

  // ── Lines & glows ────────────────────────────────────────────────────
  static const Color borderDark = Color(0x3338BDF8);
  static const Color borderLight = Color(0x14213550);
  static const Color tealGlow = Color(0x332DD4BF);
}

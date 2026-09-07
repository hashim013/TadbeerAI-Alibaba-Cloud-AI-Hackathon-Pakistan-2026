import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Full-screen ambient canvas for Tadbeer AI screens.
///
/// In Dark mode, renders the deep midnight navy canvas (`AppColors.navyBg`).
/// In Light mode, renders the luminous teal-to-blue gradient (`AppColors.lightThemeGradient`).
class AppCanvas extends StatelessWidget {
  const AppCanvas({
    super.key,
    required this.child,
    this.useSafeArea = false,
  });

  final Widget child;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.navyBg : null,
        gradient: isDark ? null : AppColors.lightThemeGradient,
      ),
      child: child,
    );

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }
}

import 'package:flutter/material.dart';

import '../../core/utils/l10n_context.dart';
import 'section_intro_screen.dart';

/// Market tab — PSX intelligence and watchlist.
class MarketTab extends StatelessWidget {
  const MarketTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SectionIntroScreen(
      icon: Icons.candlestick_chart_rounded,
      title: l10n.marketSectionTitle,
      message: l10n.marketSectionBody,
    );
  }
}

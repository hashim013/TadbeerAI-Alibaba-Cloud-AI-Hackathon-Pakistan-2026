import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/data_status_badge.dart';
import '../../../domain/entities/economic_overview.dart';
import '../../../domain/services/economic_impact_service.dart';
import '../../../providers/economic_providers.dart';
import '../finance/widgets/finance_widgets.dart';
import 'widgets/economy_widgets.dart';

/// The Economy tab root: Pakistan's key indicators at a glance, with a
/// personalized impact preview.
class EconomicPulseScreen extends ConsumerWidget {
  const EconomicPulseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(economicPulseProvider);

    return Scaffold(
      body: SafeArea(
        child: asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _EconomyErrorView(
            message: context.l10n.errorTitle,
            onRetry: () => ref.invalidate(economicPulseProvider),
          ),
          data: (economy) => _EconomicPulseContent(economy: economy),
        ),
      ),
    );
  }
}

class _EconomicPulseContent extends ConsumerWidget {
  const _EconomicPulseContent({required this.economy});

  final EconomicOverview economy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final input = ref.watch(economicImpactInputProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.economyPulseTitle,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            DataStatusBadge(status: economy.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.economyPulseSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark
                ? AppColors.textOnDarkSecondary
                : AppColors.textOnLightSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.economyUpdatedAt(
              economyRelativeDayLabel(l10n, economy.updatedAt)),
          style: theme.textTheme.labelSmall?.copyWith(
            color: isDark
                ? AppColors.textOnDarkTertiary
                : AppColors.textOnLightSecondary,
          ),
        ),
        const SizedBox(height: 16),

        // ── Key indicator cards ───────────────────────────────────────────
        SectionHeader(l10n.economyKeyIndicatorsTitle),
        ..._indicatorGrid(context, economy),
        const SizedBox(height: 24),

        // ── Trend charts for the headline indicators ─────────────────────
        SectionHeader(l10n.economyDetailHistory),
        ..._chartCards(context, economy),
        const SizedBox(height: 24),

        // ── Personalized impact preview ──────────────────────────────────
        if (input != null) ...[
          SectionHeader(l10n.economyImpactTitle),
          _ImpactPreviewCard(input: input),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: l10n.economyAskCta,
              onPressed: () => context.go('/ask'),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── What's changing? ─────────────────────────────────────────────
        SectionHeader(l10n.economyEventsTitle),
        ..._eventCards(context, economy),
        const SizedBox(height: 16),

        // ── Trust footer ─────────────────────────────────────────────────
        SourceFooter(
          source:
              economy.indicators.isEmpty ? '' : economy.indicators.first.source,
        ),
      ],
    );
  }

  List<Widget> _indicatorGrid(BuildContext context, EconomicOverview economy) {
    final rows = <Widget>[];
    for (var i = 0; i < economy.indicators.length; i += 2) {
      final left = economy.indicators[i];
      final hasRight = i + 1 < economy.indicators.length;
      rows.add(
        Padding(
          padding: EdgeInsets.only(
              bottom: hasRight || i + 1 < economy.indicators.length ? 10 : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: IndicatorCard(
                  indicator: left,
                  onTap: () => context.push('/economy/indicator/${left.id}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: hasRight
                    ? IndicatorCard(
                        indicator: economy.indicators[i + 1],
                        onTap: () => context.push(
                            '/economy/indicator/${economy.indicators[i + 1].id}'),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  List<Widget> _chartCards(BuildContext context, EconomicOverview economy) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final charts = <Widget>[];

    for (final id in const ['inflation', 'usdPkr', 'policyRate']) {
      final indicator = economy.indicatorById(id);
      if (indicator == null) continue;
      if (charts.isNotEmpty) charts.add(const SizedBox(height: 12));
      charts.add(
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
                child: Row(
                  children: [
                    Icon(economyIndicatorIcon(indicator),
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        economyIndicatorName(l10n, indicator),
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TrendChip(indicator: indicator),
                  ],
                ),
              ),
              IndicatorTrendChart(indicator: indicator),
            ],
          ),
        ),
      );
    }
    return charts;
  }

  List<Widget> _eventCards(BuildContext context, EconomicOverview economy) {
    final cards = <Widget>[];
    for (final event in economy.events) {
      final indicator = economy.indicatorById(event.indicatorId);
      if (indicator == null) continue;
      if (cards.isNotEmpty) cards.add(const SizedBox(height: 12));
      cards.add(
        EconomicEventCard(
          event: event,
          indicator: indicator,
          onOpenDetail: () =>
              context.push('/economy/indicator/${event.indicatorId}'),
          onAsk: () => context.go('/ask'),
        ),
      );
    }
    return cards;
  }
}

/// The inflation scenario preview derived from the user's current finances.
class _ImpactPreviewCard extends StatelessWidget {
  const _ImpactPreviewCard({required this.input});

  final EconomicImpactInput input;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final impact = EconomicImpactService.inflationImpact(input);
    final delta = (EconomicImpactService.demoInflationDelta * 100).round();

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImpactFinanceRows(
            income: input.monthlyIncome,
            expenses: input.monthlyExpenses,
            savings: input.monthlySavings,
          ),
          const Divider(height: 20),
          Text(
            l10n.economyImpactInflationBody(
              delta,
              CurrencyFormat.pkr(impact.estimatedMonthlyPressure),
              CurrencyFormat.pkr(impact.estimatedSavingsCapacity),
              CurrencyFormat.pkr(input.monthlySavings),
            ),
            style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.economyImpactDisclaimer,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark
                  ? AppColors.textOnDarkTertiary
                  : AppColors.textOnLightSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EconomyErrorView extends StatelessWidget {
  const _EconomyErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(l10n.retryAction)),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/economic_indicator.dart';
import '../../../domain/services/economic_impact_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/economic_providers.dart';
import '../finance/widgets/finance_widgets.dart';
import 'widgets/economy_widgets.dart';

/// Reusable detail view for a single economic indicator.
class EconomicDetailScreen extends ConsumerWidget {
  const EconomicDetailScreen({super.key, required this.indicatorId});

  final String indicatorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(economicPulseProvider);
    final l10n = context.l10n;
    final indicator = asyncData.value?.indicatorById(indicatorId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          indicator == null
              ? l10n.economyPulseTitle
              : economyIndicatorName(l10n, indicator),
        ),
      ),
      body: SafeArea(
        child: asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _EconomyDetailErrorView(
            message: l10n.errorTitle,
            onRetry: () => ref.invalidate(economicPulseProvider),
          ),
          data: (economy) {
            final resolved = economy.indicatorById(indicatorId);
            if (resolved == null) {
              return Center(child: Text(l10n.errorTitle));
            }
            return _EconomicDetailContent(indicator: resolved);
          },
        ),
      ),
    );
  }
}

class _EconomicDetailContent extends ConsumerWidget {
  const _EconomicDetailContent({required this.indicator});

  final EconomicIndicator indicator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final input = ref.watch(economicImpactInputProvider);
    final trendColor = economyTrendColor(context, indicator);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // ── Headline value ────────────────────────────────────────────────
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(economyIndicatorIcon(indicator),
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      economyIndicatorName(l10n, indicator),
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TrendChip(indicator: indicator),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                economyValueLabel(indicator),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: trendColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    switch (indicator.trend) {
                      TrendDirection.rising => Icons.arrow_upward_rounded,
                      TrendDirection.falling => Icons.arrow_downward_rounded,
                      TrendDirection.stable => Icons.trending_flat_rounded,
                    },
                    size: 14,
                    color: trendColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    economyChangeLabel(indicator),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: trendColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    l10n.economyLastUpdated(
                        economyRelativeDayLabel(l10n, indicator.updatedAt)),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppColors.textOnDarkTertiary
                          : AppColors.textOnLightSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── Current / previous / change ───────────────────────────────────
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l10n.economyCurrentValue,
                value: economyValueLabel(indicator),
                icon: Icons.circle_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: l10n.economyPreviousValue,
                value: economyNumberLabel(indicator, indicator.previousValue),
                icon: Icons.history_rounded,
                color: isDark
                    ? AppColors.textOnDarkSecondary
                    : AppColors.textOnLightSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: l10n.economyChangeLabel,
                value: economyChangeLabel(indicator),
                icon: Icons.swap_vert_rounded,
                color: trendColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── History chart ────────────────────────────────────────────────
        SectionHeader(l10n.economyDetailHistory),
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
          child: IndicatorTrendChart(indicator: indicator),
        ),
        const SizedBox(height: 24),

        // ── Plain-language description ──────────────────────────────────
        Text(
          economyIndicatorDesc(l10n, indicator),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark
                ? AppColors.textOnDarkSecondary
                : AppColors.textOnLightSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        // ── Why it matters ───────────────────────────────────────────────
        SectionHeader(l10n.economyWhyItMatters),
        Text(
          economyIndicatorWhy(l10n, indicator),
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 24),

        // ── Impact on me ─────────────────────────────────────────────────
        if (input != null) ...[
          SectionHeader(l10n.economyImpactDetailTitle),
          _ImpactSectionCard(indicator: indicator, input: input),
          const SizedBox(height: 24),
        ],

        // ── Source / trust ───────────────────────────────────────────────
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.economySourceFooter(indicator.source),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textOnDarkSecondary
                      : AppColors.textOnLightSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.economyStatusDemo,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppColors.textOnDarkTertiary
                      : AppColors.textOnLightSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Personalized scenario card: the user's finances, the possible impact and a
/// suggested action, all from deterministic Phase-2 numbers.
class _ImpactSectionCard extends StatelessWidget {
  const _ImpactSectionCard({
    required this.indicator,
    required this.input,
  });

  final EconomicIndicator indicator;
  final EconomicImpactInput input;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelStyle =
        theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700);
    final action = _suggestedAction(l10n);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.economyYourFinances, style: labelStyle),
          const SizedBox(height: 8),
          ImpactFinanceRows(
            income: input.monthlyIncome,
            expenses: input.monthlyExpenses,
            savings: input.monthlySavings,
          ),
          const Divider(height: 20),
          Text(l10n.economyPossibleImpact, style: labelStyle),
          const SizedBox(height: 8),
          ..._impactSentence(context),
          if (action != null) ...[
            const Divider(height: 20),
            Text(l10n.economySuggestedAction, style: labelStyle),
            const SizedBox(height: 8),
            Text(
              action,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ],
          const SizedBox(height: 12),
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

  List<Widget> _impactSentence(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45);

    switch (indicator.id) {
      case 'inflation':
        final impact = EconomicImpactService.inflationImpact(input);
        return [
          Text(
            l10n.economyImpactInflationBody(
              (EconomicImpactService.demoInflationDelta * 100).round(),
              CurrencyFormat.pkr(impact.estimatedMonthlyPressure),
              CurrencyFormat.pkr(impact.estimatedSavingsCapacity),
              CurrencyFormat.pkr(input.monthlySavings),
            ),
            style: style,
          ),
        ];
      case 'usdPkr':
        final impact = EconomicImpactService.exchangeRateImpact(input);
        return [
          Text(
            l10n.economyImpactCurrencyBody(
              (EconomicImpactService.demoExchangeRateDelta * 100).round(),
              CurrencyFormat.pkr(impact.estimatedMonthlyPressure),
              CurrencyFormat.pkr(impact.estimatedSavingsCapacity),
              CurrencyFormat.pkr(input.monthlySavings),
            ),
            style: style,
          ),
        ];
      case 'policyRate':
      case 'kibor':
        final impact = EconomicImpactService.policyRateImpact(input);
        return [
          Text(
            l10n.economyImpactRatesBody(
              (EconomicImpactService.demoPolicyRateDelta * 100).round(),
              CurrencyFormat.pkr(
                  EconomicImpactService.typicalLoanBalance.toDouble()),
              CurrencyFormat.pkr(impact.estimatedMonthlyPressure),
              CurrencyFormat.pkr(impact.estimatedSavingsCapacity),
              CurrencyFormat.pkr(input.monthlySavings),
            ),
            style: style,
          ),
        ];
      case 'fxReserves':
        return [Text(l10n.economyImpactReservesBody, style: style)];
      default:
        return [Text(l10n.economyImpactRemittancesBody, style: style)];
    }
  }

  String? _suggestedAction(AppLocalizations l10n) => switch (indicator.id) {
        'inflation' => l10n.economyImpactInflationAction,
        'usdPkr' => l10n.economyImpactCurrencyAction,
        'policyRate' || 'kibor' => l10n.economyImpactRatesAction,
        _ => null,
      };
}

class _EconomyDetailErrorView extends StatelessWidget {
  const _EconomyDetailErrorView({
    required this.message,
    required this.onRetry,
  });

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

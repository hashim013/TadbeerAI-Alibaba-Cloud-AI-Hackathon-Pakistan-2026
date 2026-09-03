import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/economic_event.dart';
import '../../../domain/entities/economic_indicator.dart';
import '../../../l10n/app_localizations.dart';

// ── Indicator presentation helpers ─────────────────────────────────────────

/// Localized display name for an indicator (stable id → string).
String economyIndicatorName(
        AppLocalizations l10n, EconomicIndicator indicator) =>
    switch (indicator.id) {
      'inflation' => l10n.indicatorInflation,
      'usdPkr' => l10n.indicatorUsdPkr,
      'policyRate' => l10n.indicatorPolicyRate,
      'kibor' => l10n.indicatorKibor,
      'fxReserves' => l10n.indicatorFxReserves,
      'remittances' => l10n.indicatorRemittances,
      _ => indicator.name,
    };

/// Localized one-line description (detail screen).
String economyIndicatorDesc(
        AppLocalizations l10n, EconomicIndicator indicator) =>
    switch (indicator.id) {
      'inflation' => l10n.indicatorInflationDesc,
      'usdPkr' => l10n.indicatorUsdPkrDesc,
      'policyRate' => l10n.indicatorPolicyRateDesc,
      'kibor' => l10n.indicatorKiborDesc,
      'fxReserves' => l10n.indicatorFxReservesDesc,
      'remittances' => l10n.indicatorRemittancesDesc,
      _ => indicator.name,
    };

/// Localized "why it matters" copy (detail screen).
String economyIndicatorWhy(
        AppLocalizations l10n, EconomicIndicator indicator) =>
    switch (indicator.id) {
      'inflation' => l10n.indicatorInflationWhy,
      'usdPkr' => l10n.indicatorUsdPkrWhy,
      'policyRate' => l10n.indicatorPolicyRateWhy,
      'kibor' => l10n.indicatorKiborWhy,
      'fxReserves' => l10n.indicatorFxReservesWhy,
      'remittances' => l10n.indicatorRemittancesWhy,
      _ => indicator.name,
    };

IconData economyIndicatorIcon(EconomicIndicator indicator) =>
    switch (indicator.id) {
      'inflation' => Icons.price_change_rounded,
      'usdPkr' => Icons.currency_exchange_rounded,
      'policyRate' => Icons.account_balance_rounded,
      'kibor' => Icons.percent_rounded,
      'fxReserves' => Icons.account_balance_wallet_rounded,
      'remittances' => Icons.send_rounded,
      _ => Icons.public_rounded,
    };

/// Whether a rising value is good news for the household (external buffers
/// help; rising prices and rates hurt).
bool economyRisingIsGood(EconomicIndicator indicator) =>
    indicator.id == 'fxReserves' || indicator.id == 'remittances';

/// Semantic trend color: mint when the direction helps the household, danger
/// when it hurts; stable stays neutral.
Color economyTrendColor(BuildContext context, EconomicIndicator indicator) {
  switch (indicator.trend) {
    case TrendDirection.stable:
      return Theme.of(context).colorScheme.onSurfaceVariant;
    case TrendDirection.rising:
      return economyRisingIsGood(indicator) ? AppColors.mint : AppColors.danger;
    case TrendDirection.falling:
      return economyRisingIsGood(indicator) ? AppColors.danger : AppColors.mint;
  }
}

/// Compact value label for a raw observation, e.g. "11.2%", "278.50",
/// "9.8 bn".
String economyNumberLabel(EconomicIndicator indicator, double value) =>
    switch (indicator.id) {
      'usdPkr' => value.toStringAsFixed(2),
      'fxReserves' || 'remittances' => '${value.toStringAsFixed(1)} bn',
      _ => '${value.toStringAsFixed(1)}%',
    };

/// Compact label for the indicator's current value, e.g. "11.2%".
String economyValueLabel(EconomicIndicator indicator) =>
    economyNumberLabel(indicator, indicator.currentValue);

/// Signed change label, e.g. "+0.8%", "+1.20", "-0.5 bn".
String economyChangeLabel(EconomicIndicator indicator) {
  final change = indicator.change;
  final sign = change >= 0 ? '+' : '-';
  return switch (indicator.id) {
    'usdPkr' => '$sign${change.abs().toStringAsFixed(2)}',
    'fxReserves' ||
    'remittances' =>
      '$sign${change.abs().toStringAsFixed(1)} bn',
    _ => '$sign${change.abs().toStringAsFixed(1)}%',
  };
}

/// "Today", "Yesterday" or "{n} days ago" — demo dates are relative to now.
String economyRelativeDayLabel(AppLocalizations l10n, DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return l10n.today;
  if (days == 1) return l10n.yesterday;
  return l10n.daysAgoLabel(days);
}

// ── Widgets ───────────────────────────────────────────────────────────────

/// Small chip showing trend direction + localized label.
class TrendChip extends StatelessWidget {
  const TrendChip({super.key, required this.indicator});

  final EconomicIndicator indicator;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = economyTrendColor(context, indicator);
    final (icon, label) = switch (indicator.trend) {
      TrendDirection.rising => (Icons.trending_up_rounded, l10n.trendRising),
      TrendDirection.falling => (
          Icons.trending_down_rounded,
          l10n.trendFalling
        ),
      TrendDirection.stable => (Icons.trending_flat_rounded, l10n.trendStable),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Compact indicator tile: name, current value, change and trend chip.
class IndicatorCard extends StatelessWidget {
  const IndicatorCard({super.key, required this.indicator, this.onTap});

  final EconomicIndicator indicator;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isDark = theme.brightness == Brightness.dark;
    final trendColor = economyTrendColor(context, indicator);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(economyIndicatorIcon(indicator),
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  economyIndicatorName(l10n, indicator),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? AppColors.textOnDarkSecondary
                        : AppColors.textOnLightSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              economyValueLabel(indicator),
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                economyChangeLabel(indicator),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: trendColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TrendChip(indicator: indicator),
            ],
          ),
        ],
      ),
    );
  }
}

/// Six-month line chart of one indicator with month labels on the x-axis.
class IndicatorTrendChart extends StatelessWidget {
  const IndicatorTrendChart({super.key, required this.indicator});

  final EconomicIndicator indicator;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor =
        isDark ? AppColors.textOnDarkSecondary : AppColors.textOnLightSecondary;
    final history = indicator.history;

    var minValue = double.maxFinite;
    var maxValue = -double.maxFinite;
    for (final point in history) {
      if (point.value < minValue) minValue = point.value;
      if (point.value > maxValue) maxValue = point.value;
    }
    final span = maxValue - minValue;
    final pad = span > 0 ? span * 0.25 : 1.0;
    final minY = minValue - pad;
    final maxY = maxValue + pad;
    final interval = (maxY - minY) / 3;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: interval,
                getTitlesWidget: (value, meta) => Text(
                  _yLabel(value),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: labelColor,
                        fontSize: 10,
                      ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= history.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('MMM').format(history[index].month),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: labelColor,
                            fontSize: 11,
                          ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < history.length; i++)
                  FlSpot(i.toDouble(), history[i].value),
              ],
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.teal,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.teal,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.teal.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _yLabel(double value) =>
      value.abs() >= 100 ? value.round().toString() : value.toStringAsFixed(1);
}

/// One item of the "What's changing?" feed.
class EconomicEventCard extends StatelessWidget {
  const EconomicEventCard({
    super.key,
    required this.event,
    required this.indicator,
    required this.onOpenDetail,
    required this.onAsk,
  });

  final EconomicEvent event;
  final EconomicIndicator indicator;
  final VoidCallback onOpenDetail;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (title, description, impact) = switch (event.id) {
      'inflationUp' => (
          l10n.eventInflationUpTitle,
          l10n.eventInflationUpDesc,
          l10n.eventInflationUpImpact
        ),
      'rupeeSlip' => (
          l10n.eventRupeeSlipTitle,
          l10n.eventRupeeSlipDesc,
          l10n.eventRupeeSlipImpact
        ),
      'rateCut' => (
          l10n.eventRateCutTitle,
          l10n.eventRateCutDesc,
          l10n.eventRateCutImpact
        ),
      _ => (
          l10n.eventRemittancesUpTitle,
          l10n.eventRemittancesUpDesc,
          l10n.eventRemittancesUpImpact
        ),
    };

    return AppCard(
      onTap: onOpenDetail,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(economyIndicatorIcon(indicator),
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: theme.textTheme.titleSmall),
              ),
              Text(
                economyRelativeDayLabel(l10n, event.occurredAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppColors.textOnDarkTertiary
                      : AppColors.textOnLightSecondary,
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            impact,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.textOnDarkSecondary
                  : AppColors.textOnLightSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onAsk,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 14),
            label: Text(l10n.eventAskAction),
          ),
        ],
      ),
    );
  }
}

/// Income / expenses / savings rows showing the position scenarios run on.
class ImpactFinanceRows extends StatelessWidget {
  const ImpactFinanceRows({
    super.key,
    required this.income,
    required this.expenses,
    required this.savings,
  });

  final double income;
  final double expenses;
  final double savings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        _ImpactRow(
            label: l10n.income,
            value: CurrencyFormat.pkr(income),
            color: AppColors.teal),
        const Divider(height: 14),
        _ImpactRow(
            label: l10n.expenses,
            value: CurrencyFormat.pkr(expenses),
            color: AppColors.danger),
        const Divider(height: 14),
        _ImpactRow(
            label: l10n.savings,
            value: CurrencyFormat.pkr(savings),
            color: AppColors.mint),
      ],
    );
  }
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Small trust footer attributing the synthetic dataset.
class SourceFooter extends StatelessWidget {
  const SourceFooter({super.key, required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      context.l10n.economySourceFooter(source),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isDark
                ? AppColors.textOnDarkTertiary
                : AppColors.textOnLightSecondary,
          ),
      textAlign: TextAlign.center,
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/finance_data.dart';
import '../../../domain/services/finance_calculations.dart';
import '../../../providers/finance_providers.dart';
import 'finance_category_visuals.dart';
import 'widgets/finance_widgets.dart';

/// Full financial overview: totals, monthly summary, breakdown and trends.
class MyFinancesScreen extends ConsumerWidget {
  const MyFinancesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(financeControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMyFinancesTitle)),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.errorTitle)),
        data: (data) => _MyFinancesContent(data: data),
      ),
    );
  }
}

class _MyFinancesContent extends StatelessWidget {
  const _MyFinancesContent({required this.data});

  final FinanceData data;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();

    final totalIncome = FinanceCalculations.totalIncome(data.transactions);
    final totalExpenses = FinanceCalculations.totalExpenses(data.transactions);
    final savings = FinanceCalculations.currentSavings(
        data.openingSavingsBalance, data.transactions);
    final monthIncome =
        FinanceCalculations.monthlyIncome(data.transactions, now);
    final monthExpenses =
        FinanceCalculations.monthlyExpenses(data.transactions, now);
    final breakdown =
        FinanceCalculations.categoryBreakdown(data.transactions, now);
    final series = FinanceCalculations.monthlySeries(data.transactions,
        from: now, monthCount: 3);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // ── All-time snapshot ──────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l10n.totalIncome,
                value: CurrencyFormat.pkr(totalIncome),
                icon: Icons.south_west_rounded,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: l10n.totalExpenses,
                value: CurrencyFormat.pkr(totalExpenses),
                icon: Icons.north_east_rounded,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l10n.savings,
                value: CurrencyFormat.pkr(savings),
                icon: Icons.savings_rounded,
                color: AppColors.mint,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: l10n.availableBalance,
                value: CurrencyFormat.pkr(savings),
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── This month ────────────────────────────────────────────────────
        SectionHeader(l10n.monthlySummary),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _SummaryRow(
                label: l10n.income,
                value: CurrencyFormat.pkr(monthIncome),
                color: AppColors.teal,
              ),
              const Divider(height: 20),
              _SummaryRow(
                label: l10n.expenses,
                value: CurrencyFormat.pkr(monthExpenses),
                color: AppColors.danger,
              ),
              const Divider(height: 20),
              _SummaryRow(
                label: l10n.savings,
                value: CurrencyFormat.pkr(monthIncome - monthExpenses),
                color: AppColors.mint,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Income vs expenses trend ──────────────────────────────────────
        SectionHeader(l10n.incomeVsExpenses),
        _IncomeExpenseChart(series: series),
        const SizedBox(height: 24),

        // ── Savings trend ─────────────────────────────────────────────────
        SectionHeader(l10n.savingsTrend),
        _SavingsTrendChart(series: series),
        const SizedBox(height: 24),

        // ── Category breakdown ────────────────────────────────────────────
        SectionHeader(l10n.categoryBreakdown),
        _CategoryBreakdown(
          breakdown: breakdown,
          monthLabel: DateFormat('MMMM').format(now),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
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

/// Grouped bars of income vs expenses per month.
class _IncomeExpenseChart extends StatelessWidget {
  const _IncomeExpenseChart({required this.series});

  final List<MonthlyPoint> series;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor =
        isDark ? AppColors.textOnDarkSecondary : AppColors.textOnLightSecondary;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: _niceMax(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: _niceMax() / 4,
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
                  interval: _niceMax() / 4,
                  getTitlesWidget: (value, meta) => Text(
                    NumberFormat.compact().format(value),
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
                    if (index < 0 || index >= series.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        DateFormat('MMM').format(series[index].month),
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
            barGroups: [
              for (var i = 0; i < series.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: series[i].income,
                      color: AppColors.teal,
                      width: 10,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    BarChartRodData(
                      toY: series[i].expenses,
                      color: AppColors.danger.withValues(alpha: 0.75),
                      width: 10,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _niceMax() {
    final peak =
        series.fold<double>(0, (max, p) => p.income > max ? p.income : max);
    return peak <= 0 ? 100 : peak * 1.15;
  }
}

/// Line of monthly savings over the last months.
class _SavingsTrendChart extends StatelessWidget {
  const _SavingsTrendChart({required this.series});

  final List<MonthlyPoint> series;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor =
        isDark ? AppColors.textOnDarkSecondary : AppColors.textOnLightSecondary;
    final maxValue = series.fold<double>(
        0, (max, p) => p.savings.abs() > max ? p.savings.abs() : max);
    final niceMax = maxValue <= 0 ? 100.0 : maxValue * 1.2;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      child: SizedBox(
        height: 170,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: niceMax,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: niceMax / 3,
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
                  interval: niceMax / 3,
                  getTitlesWidget: (value, meta) => Text(
                    NumberFormat.compact().format(value),
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
                    if (index < 0 || index >= series.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        DateFormat('MMM').format(series[index].month),
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
                  for (var i = 0; i < series.length; i++)
                    FlSpot(i.toDouble(), series[i].savings),
                ],
                isCurved: true,
                preventCurveOverShooting: true,
                color: AppColors.mint,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.mint,
                    strokeWidth: 0,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.mint.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Donut of current-month expenses by category with a legend beside it.
class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.breakdown, required this.monthLabel});

  final List<CategorySlice> breakdown;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    if (breakdown.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        child: Text(
          l10n.noTransactionsBody,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Show the top slices individually; fold the tail into "Other".
    const maxSlices = 5;
    final slices = breakdown.length <= maxSlices
        ? breakdown
        : breakdown.sublist(0, maxSlices);
    final tail = breakdown.length <= maxSlices
        ? <CategorySlice>[]
        : breakdown.sublist(maxSlices);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 44,
                      startDegreeOffset: -90,
                      sections: [
                        for (var i = 0; i < slices.length; i++)
                          PieChartSectionData(
                            value: slices[i].amount,
                            color: CategoryVisuals.chartColor(
                                slices[i].category, i),
                            radius: 15,
                            showTitle: false,
                          ),
                        if (tail.isNotEmpty)
                          PieChartSectionData(
                            value: tail.fold<double>(
                                0, (sum, s) => sum + s.amount),
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.35),
                            radius: 15,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < slices.length; i++)
                        _LegendRow(
                          color:
                              CategoryVisuals.chartColor(slices[i].category, i),
                          label:
                              CategoryVisuals.nameOf(l10n, slices[i].category),
                          share: slices[i].share,
                        ),
                      if (tail.isNotEmpty)
                        _LegendRow(
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.35),
                          label: l10n.catOther,
                          share:
                              tail.fold<double>(0, (sum, s) => sum + s.share),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.share,
  });

  final Color color;
  final String label;
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${(share * 100).round()}%',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

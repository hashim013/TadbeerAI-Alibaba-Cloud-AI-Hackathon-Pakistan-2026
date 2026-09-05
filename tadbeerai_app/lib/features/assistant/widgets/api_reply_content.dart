import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/data_status_badge.dart';
import '../../../domain/entities/assistant_api_models.dart';
import '../../../domain/entities/assistant_message.dart';
import '../../../l10n/app_localizations.dart';
import 'assistant_widgets.dart';

/// The assistant's answer from the live backend: answer text first, then —
/// where present — the What-If scenario card, key numbers, recommendations
/// and sources, closing with a data-status footer.
///
/// Every number, label and source comes from the backend response; Flutter
/// only formats values for display (it never recalculates them).
class ApiAssistantBubble extends StatelessWidget {
  const ApiAssistantBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final api = message.reply!.api!;
    final scenario = api.scenario;
    final isScenario =
        api.dataStatus == DataStatusKind.scenario && scenario != null;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.85;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: assistantBubbleDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              api.answer,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            if (isScenario) ...[
              const SizedBox(height: 12),
              ScenarioCard(
                scenario: scenario,
                recommendations: api.recommendations,
              ),
            ],
            if (!isScenario) ...[
              _KeyNumbers(metrics: api.metrics),
              _Recommendations(recommendations: api.recommendations),
            ],
            if (api.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionLabel(label: l10n.apiSourcesTitle),
              const SizedBox(height: 6),
              for (final source in api.sources) _SourceRow(source: source),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Flexible(child: DataStatusBadge(status: api.dataStatus)),
                const SizedBox(width: 8),
                Text(
                  DateFormat('jm').format(message.timestamp),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? AppColors.textOnDarkTertiary
                        : AppColors.textOnLightSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The deterministic What-If result: highly visible label plus the
/// "not a forecast" caveat, then assumption / current situation / what
/// changes / estimated impact rows from the backend's structured payload.
class ScenarioCard extends StatelessWidget {
  const ScenarioCard({
    super.key,
    required this.scenario,
    required this.recommendations,
  });

  final ScenarioPayload scenario;

  /// Backend recommendations, rendered as the card's next steps.
  final List<String> recommendations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColors.textOnDarkSecondary
        : AppColors.textOnLightSecondary;
    final calculated = scenario.status == 'calculated';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded,
                  size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Text(
                l10n.scenarioLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.scenarioNotForecast,
            style: theme.textTheme.bodySmall?.copyWith(
              color: secondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
          _SectionLabel(label: l10n.scenarioAssumption),
          const SizedBox(height: 4),
          Text(
            _assumptionText(l10n, scenario),
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          ..._calculatedSections(l10n),
          if (!calculated && scenario.limitations.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SectionLabel(label: l10n.scenarioLimitations),
            const SizedBox(height: 4),
            for (final limitation in scenario.limitations)
              _BulletText(text: limitation),
          ],
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SectionLabel(label: l10n.scenarioNextSteps),
            const SizedBox(height: 4),
            for (final step in recommendations)
              _BulletText(text: step, emphasized: true),
          ],
        ],
      ),
    );
  }

  /// The user's stated assumption as a sentence — numbers straight from the
  /// backend payload, only formatted for display.
  static String _assumptionText(
    AppLocalizations l10n,
    ScenarioPayload scenario,
  ) {
    switch (scenario.scenarioType) {
      case 'save_more':
        final amount = _asDouble(
              scenario.assumptions['additional_monthly_savings_pkr'],
            ) ??
            _asDouble(scenario.outputs['additional_monthly_savings']);
        if (amount != null) {
          return l10n.scenarioSaveMoreAssumption(CurrencyFormat.pkr(amount));
        }
      case 'expense_shock':
        final pct = _asDouble(scenario.assumptions['expense_change_pct']) ??
            _asDouble(scenario.outputs['expense_shock_pct']);
        if (pct != null) {
          final value = _plain(pct.abs());
          return pct >= 0
              ? l10n.scenarioExpenseAssumptionIncrease(value)
              : l10n.scenarioExpenseAssumptionDecrease(value);
        }
      case 'rate_shock':
        final points =
            _asDouble(scenario.assumptions['rate_change_percentage_points']) ??
                _asDouble(scenario.outputs['rate_change_percentage_points']);
        if (points != null) {
          final value = _plain(points.abs());
          return points >= 0
              ? l10n.scenarioRateAssumptionIncrease(value)
              : l10n.scenarioRateAssumptionDecrease(value);
        }
    }
    return scenario.scenarioType;
  }

  /// Current situation / what changes / estimated impact rows for a
  /// successfully calculated scenario, per scenario family.
  List<Widget> _calculatedSections(AppLocalizations l10n) {
    if (scenario.status != 'calculated') return const [];

    final outputs = scenario.outputs;
    final current = <(String, String)>[];
    final changes = <(String, String)>[];
    final impact = <(String, String)>[];

    switch (scenario.scenarioType) {
      case 'save_more':
        _addMoney(current, l10n.scenarioRowCurrentSavings,
            outputs['current_monthly_savings']);
        _addPercent(current, l10n.scenarioRowCurrentRate,
            outputs['current_savings_rate_pct']);
        _addMoney(changes, l10n.scenarioRowAdditional,
            outputs['additional_monthly_savings']);
        _addMoney(
            impact, l10n.scenarioRowNewSavings, outputs['new_monthly_savings']);
        _addPercent(
            impact, l10n.scenarioRowNewRate, outputs['new_savings_rate_pct']);
        _addMoney(impact, l10n.scenarioRowAfterMonths(6),
            outputs['additional_savings_6_months']);
        _addMoney(impact, l10n.scenarioRowAfterMonths(12),
            outputs['additional_savings_12_months']);
        for (final (months, value) in _customMonthValues(outputs)) {
          _addMoney(impact, l10n.scenarioRowAfterMonths(months), value);
        }
      case 'expense_shock':
        _addMoney(current, l10n.scenarioRowCurrentExpenses,
            outputs['current_monthly_expenses']);
        _addMoney(current, l10n.scenarioRowCurrentSurplus,
            outputs['current_monthly_surplus']);
        _addPercent(current, l10n.scenarioRowCurrentRate,
            outputs['current_savings_rate_pct']);
        _addMonths(current, l10n.scenarioRowCurrentRunway,
            outputs['current_runway_months'], l10n.metricUnitMonths);
        _addMoney(changes, l10n.scenarioRowAdditionalExpense,
            outputs['additional_monthly_expense']);
        _addMoney(changes, l10n.scenarioRowNewExpenses,
            outputs['new_monthly_expenses']);
        _addMoney(impact, l10n.scenarioRowProjectedSurplus,
            outputs['projected_monthly_surplus']);
        _addPercent(impact, l10n.scenarioRowNewRate,
            outputs['projected_savings_rate_pct']);
        _addMonths(impact, l10n.scenarioRowProjectedRunway,
            outputs['projected_runway_months'], l10n.metricUnitMonths);
      case 'rate_shock':
        // Never "calculated" — the borrowing impact is not quantified
        // without loan details, so only the assumption + limitations render.
        break;
    }

    return [
      for (final (title, rows) in [
        (l10n.scenarioCurrent, current),
        (l10n.scenarioChanges, changes),
        (l10n.scenarioImpact, impact),
      ])
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SectionLabel(label: title),
          const SizedBox(height: 4),
          for (final (label, value) in rows)
            _ValueRow(label: label, value: value),
        ],
    ];
  }
}

// ── Key numbers ────────────────────────────────────────────────────────────

/// Compact chips for the well-known economic and personal metrics the
/// backend emits. Values are formatted, never recalculated; scenario flat
/// outputs are intentionally skipped (they render in the What-If card).
class _KeyNumbers extends StatelessWidget {
  const _KeyNumbers({required this.metrics});

  final Map<String, Object?> metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rows = knownMetricRows(l10n, metrics);
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: l10n.keyNumbersTitle),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (label, value) in rows)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$label ',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.brightness == Brightness.dark
                              ? AppColors.textOnDarkSecondary
                              : AppColors.textOnLightSecondary,
                        ),
                      ),
                      Text(
                        value,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Metric keys in display order.
const List<String> _metricOrder = [
  'inflation_rate_pct',
  'policy_rate_pct',
  'kibor_3m_pct',
  'usd_pkr',
  'fx_reserves_usd_bn',
  'remittances_usd_bn',
  'monthly_savings',
  'savings_rate_pct',
  'expense_ratio_pct',
  'runway_months',
];

/// Curated (label, formatted value) rows for the metrics present in the
/// backend response — empty when none of the known keys apply.
List<(String, String)> knownMetricRows(
  AppLocalizations l10n,
  Map<String, Object?> metrics,
) {
  final rows = <(String, String)>[];
  for (final key in _metricOrder) {
    final value = _asDouble(metrics[key]);
    if (value == null) continue;
    rows.add((_metricLabel(l10n, key), _metricValue(l10n, key, value)));
  }
  return rows;
}

String _metricLabel(AppLocalizations l10n, String key) => switch (key) {
      'inflation_rate_pct' => l10n.indicatorInflation,
      'policy_rate_pct' => l10n.indicatorPolicyRate,
      'kibor_3m_pct' => l10n.indicatorKibor,
      'usd_pkr' => l10n.indicatorUsdPkr,
      'fx_reserves_usd_bn' => l10n.indicatorFxReserves,
      'remittances_usd_bn' => l10n.indicatorRemittances,
      'monthly_savings' => l10n.metricMonthlySavings,
      'savings_rate_pct' => l10n.metricSavingsRate,
      'expense_ratio_pct' => l10n.metricExpenseRatio,
      'runway_months' => l10n.metricRunwayMonths,
      _ => key,
    };

String _metricValue(AppLocalizations l10n, String key, double value) =>
    switch (key) {
      'monthly_savings' => CurrencyFormat.pkr(value),
      'usd_pkr' => value.toStringAsFixed(1),
      'fx_reserves_usd_bn' =>
        '${value.toStringAsFixed(1)} ${l10n.metricUnitBnUsd}',
      'remittances_usd_bn' =>
        '${value.toStringAsFixed(1)} ${l10n.metricUnitBnUsd}',
      'runway_months' => '${value.toStringAsFixed(1)} ${l10n.metricUnitMonths}',
      _ => '${_plain(value)}%',
    };

/// ── Recommendations ───────────────────────────────────────────────────────

class _Recommendations extends StatelessWidget {
  const _Recommendations({required this.recommendations});

  final List<String> recommendations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (recommendations.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: l10n.apiRecommendationsTitle),
          const SizedBox(height: 6),
          for (final recommendation in recommendations)
            _BulletText(text: recommendation, emphasized: true),
        ],
      ),
    );
  }
}

// ── Shared bits ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.brightness == Brightness.dark
            ? AppColors.textOnDarkSecondary
            : AppColors.textOnLightSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// One "label — value" line inside the scenario card.
class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.brightness == Brightness.dark
                    ? AppColors.textOnDarkSecondary
                    : AppColors.textOnLightSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText({required this.text, this.emphasized = false});

  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColors.textOnDarkSecondary
        : AppColors.textOnLightSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            emphasized
                ? Icons.arrow_forward_rounded
                : Icons.info_outline_rounded,
            size: 13,
            color: emphasized ? theme.colorScheme.primary : secondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: emphasized
                  ? theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)
                  : theme.textTheme.bodySmall?.copyWith(color: secondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColors.textOnDarkSecondary
        : AppColors.textOnLightSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.link_rounded, size: 13, color: secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              source,
              style: theme.textTheme.bodySmall?.copyWith(color: secondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Value helpers ──────────────────────────────────────────────────────────

/// Numeric coercion for JSON values (num, or numeric strings).
double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// 10 → "10", 10.4 → "10.4".
String _plain(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

void _addMoney(List<(String, String)> rows, String label, Object? value) {
  final number = _asDouble(value);
  if (number != null) rows.add((label, CurrencyFormat.pkr(number)));
}

void _addPercent(List<(String, String)> rows, String label, Object? value) {
  final number = _asDouble(value);
  if (number != null) rows.add((label, '${_plain(number)}%'));
}

/// Months are display units, not translations of the value itself.
void _addMonths(
  List<(String, String)> rows,
  String label,
  Object? value,
  String unit,
) {
  final number = _asDouble(value);
  if (number != null) {
    rows.add((label, '${number.toStringAsFixed(1)} $unit'));
  }
}

/// Custom accumulation horizons (any "additional_savings_N_months" key the
/// backend emits besides 6 and 12), sorted by month.
List<(int, double)> _customMonthValues(Map<String, Object?> outputs) {
  final values = <(int, double)>[];
  final pattern = RegExp(r'^additional_savings_(\d+)_months$');
  for (final entry in outputs.entries) {
    final match = pattern.firstMatch(entry.key);
    if (match == null) continue;
    final months = int.tryParse(match.group(1)!);
    final value = _asDouble(entry.value);
    if (months == null || value == null || months == 6 || months == 12) {
      continue;
    }
    values.add((months, value));
  }
  values.sort((a, b) => a.$1.compareTo(b.$1));
  return values;
}

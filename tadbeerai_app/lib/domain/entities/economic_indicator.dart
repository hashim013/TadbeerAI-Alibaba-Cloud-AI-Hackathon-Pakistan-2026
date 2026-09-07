import 'assistant_api_models.dart';

/// Direction an economic indicator is heading.
enum TrendDirection { rising, falling, stable }

/// Provenance of the numbers backing an indicator.
typedef DataStatus = DataStatusKind;

/// One historical observation of an indicator (annual or monthly granularity).
class IndicatorPoint {
  const IndicatorPoint({required this.month, required this.value});

  /// The observation's period as a timestamp: `DateTime(year)` for annual
  /// series, or any moment inside the month (normalized to day 1) for monthly.
  final DateTime month;
  final double value;
}

/// A single macroeconomic indicator (inflation, USD/PKR, …) with its recent
/// history.
///
/// [id] is a stable storage key; localized display names are resolved by the
/// UI. Values are the raw numbers — formatting is a presentation concern.
class EconomicIndicator {
  const EconomicIndicator({
    required this.id,
    required this.name,
    required this.currentValue,
    required this.previousValue,
    required this.unit,
    required this.category,
    required this.source,
    required this.dataStatus,
    required this.updatedAt,
    required this.history,
    this.period = '',
    this.notes = '',
    this.frequency = '',
    this.sourceUrl = '',
  });

  /// 'inflation' | 'usdPkr' | 'policyRate' | 'kibor' | 'fxReserves'
  /// | 'remittances'.
  final String id;

  /// English fallback name; the UI prefers the localized name.
  final String name;

  /// Latest observation (the last point of [history]).
  final double currentValue;

  /// The observation before [currentValue].
  final double previousValue;

  /// Display hint: '%', 'PKR', 'USD bn'.
  final String unit;

  /// Grouping key: 'prices' | 'currency' | 'rates' | 'external'.
  final String category;

  /// Attribution shown to the user (demo dataset for now).
  final String source;

  final DataStatus dataStatus;

  /// Reporting period (e.g. 'monthly', 'daily', 'bi-weekly').
  final String period;

  /// Technical notes or source methodology.
  final String notes;

  /// Natural reporting cadence of the source ('annual', 'monthly', 'daily',
  /// 'policy announcement'); empty when the source did not state one.
  final String frequency;

  /// Official, human-verifiable source URL (empty when none is published).
  /// Rendered as selectable text — never launched, never fabricated.
  final String sourceUrl;

  /// When this value was (nominally) published.
  final DateTime updatedAt;

  /// Historical observations, oldest first, ending with the current value.
  /// Annual for World Bank series, monthly for the demo dataset; empty or
  /// single-point when the source published no trend (UI then says so).
  final List<IndicatorPoint> history;

  /// Absolute movement since the previous period, in the indicator's unit.
  double get change => currentValue - previousValue;

  /// [change] relative to [previousValue], in percent.
  double get changePercentage =>
      previousValue != 0 ? change / previousValue * 100 : 0;

  /// Direction derived from the change; moves under 0.1% count as stable.
  TrendDirection get trend {
    if (previousValue == 0) return TrendDirection.stable;
    final relative = (change / previousValue).abs();
    if (relative < 0.001) return TrendDirection.stable;
    return change > 0 ? TrendDirection.rising : TrendDirection.falling;
  }
}

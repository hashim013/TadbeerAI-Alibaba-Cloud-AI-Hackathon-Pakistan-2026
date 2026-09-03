import '../../domain/entities/economic_event.dart';
import '../../domain/entities/economic_indicator.dart';
import '../../domain/entities/economic_overview.dart';

/// The single source of truth for Phase-3 DEMO economic data.
///
/// Widgets never hardcode values; everything flows from here through the
/// repository layer. The dataset is SYNTHETIC — it models a plausible
/// Pakistani macro picture but must never be presented as live data:
///
/// * All values are clearly attributed to a "Demo Dataset" source.
/// * History is generated RELATIVE to [now] (six monthly observations,
///   oldest first, ending with the current month) so the demo always
///   looks current without fake timestamps.
/// * Trends are deliberately mixed (inflation and USD/PKR rising, policy
///   rate and KIBOR easing, reserves and remittances improving) so every
///   trend direction is demonstrable.
abstract final class MockEconomicData {
  /// Attribution string for the synthetic dataset.
  static const String demoSource = 'Demo Dataset';

  /// Combined demonstration trim suggested by the savings answer.
  static const double saveMoreSuggestion = 2000;

  /// Months of history each indicator carries.
  static const int historyMonths = 6;

  static EconomicOverview seed(DateTime now) => EconomicOverview(
        indicators: seedIndicators(now),
        events: seedEvents(now),
        updatedAt: now,
      );

  // ── Indicators ──────────────────────────────────────────────────────────

  static List<EconomicIndicator> seedIndicators(DateTime now) {
    // Six months ending with the current one, oldest first.
    final months = [
      for (var i = historyMonths - 1; i >= 0; i--)
        DateTime(now.year, now.month - i),
    ];

    return [
      _indicator(
        id: 'inflation',
        name: 'Inflation',
        unit: '%',
        category: 'prices',
        values: const [9.8, 10.1, 10.4, 10.7, 10.4, 11.2],
        months: months,
        now: now,
      ),
      _indicator(
        id: 'usdPkr',
        name: 'USD / PKR',
        unit: 'PKR',
        category: 'currency',
        values: const [275.0, 276.2, 277.1, 278.1, 277.3, 278.5],
        months: months,
        now: now,
      ),
      _indicator(
        id: 'policyRate',
        name: 'Policy Rate',
        unit: '%',
        category: 'rates',
        values: const [22.0, 21.5, 21.0, 20.5, 20.5, 20.0],
        months: months,
        now: now,
      ),
      _indicator(
        id: 'kibor',
        name: 'KIBOR (3-month)',
        unit: '%',
        category: 'rates',
        values: const [22.4, 21.9, 21.4, 20.9, 20.7, 20.3],
        months: months,
        now: now,
      ),
      _indicator(
        id: 'fxReserves',
        name: 'FX Reserves',
        unit: 'USD bn',
        category: 'external',
        values: const [8.1, 8.3, 8.6, 9.1, 9.4, 9.8],
        months: months,
        now: now,
      ),
      _indicator(
        id: 'remittances',
        name: 'Remittances',
        unit: 'USD bn',
        category: 'external',
        values: const [2.1, 2.2, 2.4, 2.3, 2.5, 2.6],
        months: months,
        now: now,
      ),
    ];
  }

  /// Builds an indicator whose current/previous values are the last two
  /// observations of its history.
  static EconomicIndicator _indicator({
    required String id,
    required String name,
    required String unit,
    required String category,
    required List<double> values,
    required List<DateTime> months,
    required DateTime now,
  }) {
    final history = [
      for (var i = 0; i < values.length; i++)
        IndicatorPoint(month: months[i], value: values[i]),
    ];
    return EconomicIndicator(
      id: id,
      name: name,
      currentValue: values.last,
      previousValue: values[values.length - 2],
      unit: unit,
      category: category,
      source: demoSource,
      dataStatus: DataStatus.demo,
      updatedAt: now,
      history: history,
    );
  }

  // ── Events ──────────────────────────────────────────────────────────────

  static List<EconomicEvent> seedEvents(DateTime now) => [
        EconomicEvent(
          id: 'inflationUp',
          indicatorId: 'inflation',
          occurredAt: DateTime(now.year, now.month, now.day - 2),
        ),
        EconomicEvent(
          id: 'rupeeSlip',
          indicatorId: 'usdPkr',
          occurredAt: DateTime(now.year, now.month, now.day - 5),
        ),
        EconomicEvent(
          id: 'rateCut',
          indicatorId: 'policyRate',
          occurredAt: DateTime(now.year, now.month, now.day - 9),
        ),
        EconomicEvent(
          id: 'remittancesUp',
          indicatorId: 'remittances',
          occurredAt: DateTime(now.year, now.month, now.day - 14),
        ),
      ];
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/data/repositories/mock_economic_repository.dart';
import 'package:tadbeerai/domain/entities/economic_indicator.dart';

/// Tests for the mock economic repository and the indicator model getters:
/// the bundled dataset must stay deterministic, attributed to the synthetic
/// demo source and internally consistent (current/previous derived from the
/// history series, events newest first).
void main() {
  // A fixed "today" keeps the relative demo dataset deterministic.
  final now = DateTime(2026, 3, 15);

  late MockEconomicRepository repository;

  setUp(() {
    repository = MockEconomicRepository(now: () => now, latency: Duration.zero);
  });

  group('overview', () {
    test('serves six indicators in display-priority order', () async {
      final overview = await repository.getOverview();

      expect(
        overview.indicators.map((i) => i.id).toList(),
        [
          'inflation',
          'usdPkr',
          'policyRate',
          'kibor',
          'fxReserves',
          'remittances',
        ],
      );
      expect(overview.updatedAt, now);
    });

    test(
        'every indicator carries six monthly points ending at the current '
        'value', () async {
      final overview = await repository.getOverview();

      for (final indicator in overview.indicators) {
        expect(indicator.history, hasLength(6), reason: indicator.id);
        expect(indicator.currentValue, indicator.history.last.value,
            reason: indicator.id);
        expect(indicator.previousValue, indicator.history[4].value,
            reason: indicator.id);

        // Months are consecutive, oldest first, ending with this month.
        for (var i = 0; i < indicator.history.length; i++) {
          expect(
            indicator.history[i].month,
            DateTime(now.year, now.month - (5 - i)),
            reason: '${indicator.id} point $i',
          );
        }
      }
    });

    test('indicators are attributed to the synthetic demo dataset', () async {
      final overview = await repository.getOverview();

      for (final indicator in overview.indicators) {
        expect(indicator.source, 'Demo Dataset', reason: indicator.id);
        expect(indicator.dataStatus, DataStatus.demo, reason: indicator.id);
      }
    });

    test('trends are mixed so every direction is demonstrable', () async {
      final overview = await repository.getOverview();
      final byId = {
        for (final indicator in overview.indicators) indicator.id: indicator,
      };

      expect(byId['inflation']!.trend, TrendDirection.rising);
      expect(byId['usdPkr']!.trend, TrendDirection.rising);
      expect(byId['policyRate']!.trend, TrendDirection.falling);
      expect(byId['kibor']!.trend, TrendDirection.falling);
      expect(byId['fxReserves']!.trend, TrendDirection.rising);
      expect(byId['remittances']!.trend, TrendDirection.rising);
    });

    test('current values and changes match the seeded series', () async {
      final overview = await repository.getOverview();

      final inflation = overview.indicatorById('inflation')!;
      expect(inflation.currentValue, 11.2);
      expect(inflation.previousValue, 10.4);
      expect(inflation.change, closeTo(0.8, 0.0001));
      expect(inflation.changePercentage, closeTo(0.8 / 10.4 * 100, 0.0001));

      final usdPkr = overview.indicatorById('usdPkr')!;
      expect(usdPkr.currentValue, 278.5);
      expect(usdPkr.previousValue, 277.3);
      expect(usdPkr.change, closeTo(1.2, 0.0001));
    });

    test('indicatorById returns null for unknown ids', () async {
      final overview = await repository.getOverview();

      expect(overview.indicatorById('oil'), isNull);
    });
  });

  group('events', () {
    test('four recent events arrive newest first', () async {
      final overview = await repository.getOverview();

      expect(overview.events.map((e) => e.id).toList(), [
        'inflationUp',
        'rupeeSlip',
        'rateCut',
        'remittancesUp',
      ]);
      expect(
        overview.events.map((e) => e.indicatorId).toSet(),
        {'inflation', 'usdPkr', 'policyRate', 'remittances'},
      );

      // Strictly newest first…
      for (var i = 1; i < overview.events.length; i++) {
        expect(
          overview.events[i].occurredAt
              .isBefore(overview.events[i - 1].occurredAt),
          isTrue,
        );
      }
      // …and none older than two weeks.
      expect(
        overview.events.last.occurredAt
            .isAfter(now.subtract(const Duration(days: 15))),
        isTrue,
      );
    });
  });

  group('getIndicator', () {
    test('fetches a single indicator by id', () async {
      final kibor = await repository.getIndicator('kibor');

      expect(kibor, isNotNull);
      expect(kibor!.currentValue, 20.3);
      expect(kibor.unit, '%');
    });

    test('returns null for unknown ids', () async {
      expect(await repository.getIndicator('gold'), isNull);
    });
  });

  group('indicator getters', () {
    EconomicIndicator indicatorWith(double previous, double current) =>
        EconomicIndicator(
          id: 'test',
          name: 'Test',
          currentValue: current,
          previousValue: previous,
          unit: '%',
          category: 'prices',
          source: 'Demo Dataset',
          dataStatus: DataStatus.demo,
          updatedAt: now,
          history: [
            IndicatorPoint(
                month: DateTime(now.year, now.month - 1), value: previous),
            IndicatorPoint(month: now, value: current),
          ],
        );

    test('rising and falling movements expose signed change and percent', () {
      final rising = indicatorWith(10, 11);
      expect(rising.trend, TrendDirection.rising);
      expect(rising.change, 1);
      expect(rising.changePercentage, 10);

      final falling = indicatorWith(11, 10);
      expect(falling.trend, TrendDirection.falling);
      expect(falling.change, -1);
      expect(falling.changePercentage, closeTo(-100 / 11, 0.0001));
    });

    test('moves under 0.1% count as stable', () {
      final tiny = indicatorWith(1000, 1000.5); // +0.05%
      expect(tiny.trend, TrendDirection.stable);

      final flat = indicatorWith(10, 10);
      expect(flat.trend, TrendDirection.stable);
      expect(flat.change, 0);
      expect(flat.changePercentage, 0);
    });

    test('a zero previous value is stable, never a divide-by-zero', () {
      final fromZero = indicatorWith(0, 5);

      expect(fromZero.trend, TrendDirection.stable);
      expect(fromZero.changePercentage, 0);
    });
  });
}

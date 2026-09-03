import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/domain/services/economic_impact_service.dart';

/// Tests for the deterministic "impact on you" engine. Every scenario runs
/// against the same demo household the Finance tab shows (Rs 80,000 income /
/// Rs 65,000 expenses / Rs 10,100 discretionary) so the numbers asserted
/// here are exactly the numbers the Economy and Ask screens display.
void main() {
  const demo = EconomicImpactInput(
    monthlyIncome: 80000,
    monthlyExpenses: 65000,
    discretionarySpending: 10100,
  );

  group('input getters', () {
    test('monthly savings and essential expenses are derived', () {
      expect(demo.monthlySavings, 15000);
      expect(demo.essentialExpenses, 54900);
    });
  });

  group('inflation scenario', () {
    test('demo +2-point rise adds Rs 1,098 of monthly pressure', () {
      final result = EconomicImpactService.inflationImpact(demo);

      expect(result.monthlyIncome, 80000);
      expect(result.estimatedMonthlyPressure, closeTo(1098, 0.001));
      expect(result.estimatedSavingsCapacity, closeTo(13902, 0.001));
      expect(result.pressureShareOfIncome, closeTo(1098 / 80000, 0.000001));
    });

    test('custom deltas scale linearly and easing inflation gives relief', () {
      final relief =
          EconomicImpactService.inflationImpact(demo, inflationDelta: -0.02);

      expect(relief.estimatedMonthlyPressure, closeTo(-1098, 0.001));
      expect(relief.estimatedSavingsCapacity, closeTo(16098, 0.001));

      final severe =
          EconomicImpactService.inflationImpact(demo, inflationDelta: 0.05);
      expect(severe.estimatedMonthlyPressure, closeTo(2745, 0.001));
    });
  });

  group('exchange-rate scenario', () {
    test('demo 2% rupee depreciation adds Rs 325 of monthly pressure', () {
      final result = EconomicImpactService.exchangeRateImpact(demo);

      expect(result.estimatedMonthlyPressure, closeTo(325, 0.001));
      expect(result.estimatedSavingsCapacity, closeTo(14675, 0.001));
    });

    test('exposure is a quarter of total expenses', () {
      final result = EconomicImpactService.exchangeRateImpact(demo);

      // 65,000 × 25% imported-goods share × 2% depreciation = 325.
      expect(
        result.estimatedMonthlyPressure,
        closeTo(
          65000 * EconomicImpactService.importedGoodsShare * 0.02,
          0.001,
        ),
      );
    });
  });

  group('policy-rate scenario', () {
    test('demo +1-point rise adds balance × 1% / 12 of monthly pressure', () {
      final result = EconomicImpactService.policyRateImpact(demo);
      const expectedPressure =
          EconomicImpactService.typicalLoanBalance * 0.01 / 12;

      expect(result.estimatedMonthlyPressure, closeTo(expectedPressure, 0.001));
      expect(
        result.estimatedSavingsCapacity,
        closeTo(15000 - expectedPressure, 0.001),
      );
    });
  });

  group('edge cases', () {
    test('a strained budget can show negative savings capacity', () {
      const strained = EconomicImpactInput(
        monthlyIncome: 40000,
        monthlyExpenses: 39500,
        discretionarySpending: 3000,
      );

      final result =
          EconomicImpactService.inflationImpact(strained, inflationDelta: 0.10);

      expect(result.estimatedSavingsCapacity, lessThan(0));
    });

    test('zero income yields a zero pressure share', () {
      final result = EconomicImpactService.inflationImpact(
        const EconomicImpactInput(
          monthlyIncome: 0,
          monthlyExpenses: 65000,
          discretionarySpending: 10100,
        ),
      );

      expect(result.pressureShareOfIncome, 0);
    });
  });
}

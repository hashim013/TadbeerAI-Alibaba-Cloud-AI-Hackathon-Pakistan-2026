import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/data/mock/mock_finance_data.dart';
import 'package:tadbeerai/domain/entities/budget.dart';
import 'package:tadbeerai/domain/entities/finance_category.dart';
import 'package:tadbeerai/domain/entities/goal.dart';
import 'package:tadbeerai/domain/services/finance_calculations.dart';
import 'package:tadbeerai/domain/services/financial_health_calculator.dart';
import 'package:tadbeerai/domain/services/insight_generator.dart';

/// The health score must be deterministic, explainable and free of any LLM —
/// these tests pin the formula to exact numbers.
void main() {
  group('FinancialHealthCalculator on the bundled demo data', () {
    // A fixed "today" keeps the relative demo dataset deterministic.
    final now = DateTime(2026, 3, 15);
    final data = MockFinanceData.seed(now);

    FinancialHealthInput input() => FinancialHealthInput(
          monthlyIncome:
              FinanceCalculations.monthlyIncome(data.transactions, now),
          monthlyExpenses:
              FinanceCalculations.monthlyExpenses(data.transactions, now),
          savingsBalance: FinanceCalculations.currentSavings(
              data.openingSavingsBalance, data.transactions),
          discretionarySpending: FinanceCalculations.discretionarySpending(
              data.transactions,
              now,
              FinanceCategories.discretionaryExpenseIds),
          budgets: data.budgets,
          spentByCategory:
              FinanceCalculations.spentByCategory(data.transactions, now),
          goals: data.goals,
        );

    test('is deterministic — identical inputs produce identical output', () {
      final first = FinancialHealthCalculator.calculate(input());
      final second = FinancialHealthCalculator.calculate(input());

      expect(second.score, first.score);
      expect(
        second.components.map((c) => c.score).toList(),
        first.components.map((c) => c.score).toList(),
      );
    });

    test('scores the demo profile 76 "Good" with explainable components', () {
      final result = FinancialHealthCalculator.calculate(input());

      expect(result.score, 76);
      expect(result.rating, HealthRating.good);

      // The five components in documentation order.
      expect(
        result.components.map((c) => c.key).toList(),
        ['savings', 'budget', 'emergency', 'goals', 'spending'],
      );
      // Hand-derived from the seed: savings rate 18.75% → 94; 7 of 9 budgets
      // on track with two mild overspends → 96; 3.0 months of expenses
      // covered vs a 6-month ideal → 51; average goal progress 33.75% → 34;
      // discretionary share 12.6% inside the 10–30% band → 87.
      expect(
        result.components.map((c) => c.score).toList(),
        [94, 96, 51, 34, 87],
      );

      // The weights always describe the full formula.
      final totalWeight =
          result.components.fold<double>(0, (sum, c) => sum + c.weight);
      expect(totalWeight, 1.0);

      // Detail parameters are what the localized sentences interpolate.
      final byKey = {for (final c in result.components) c.key: c};
      expect(byKey['budget']!.detailParams['onTrack'], '7');
      expect(byKey['budget']!.detailParams['total'], '9');
      expect(byKey['emergency']!.detailParams['months'], '3.0');
      expect(byKey['goals']!.detailParams['percent'], '34');
    });
  });

  group('FinancialHealthCalculator components', () {
    test('no budgets and no goals score the neutral 50', () {
      final result = FinancialHealthCalculator.calculate(
        FinancialHealthInput.fromValues(
          monthlyIncome: 100000,
          monthlyExpenses: 80000,
          savingsBalance: 480000, // six months covered
          discretionarySpending: 10000,
        ),
      );

      final byKey = {for (final c in result.components) c.key: c};
      expect(byKey['budget']!.score, 50);
      expect(byKey['goals']!.score, 50);
    });

    test('a perfect profile scores 100', () {
      final result = FinancialHealthCalculator.calculate(
        FinancialHealthInput.fromValues(
          monthlyIncome: 100000,
          monthlyExpenses: 40000, // 60% saved
          savingsBalance: 240000, // six months covered
          discretionarySpending: 5000, // 5% of income
          budgets: const [
            Budget(id: 'b1', category: 'rent', monthlyLimit: 18000),
          ],
          spentByCategory: {'rent': 18000},
          goals: [
            Goal(
              id: 'g1',
              title: 'Done',
              targetAmount: 10000,
              savedAmount: 10000,
              targetDate: DateTime(2027, 1, 1),
            ),
          ],
        ),
      );

      expect(result.score, 100);
      expect(result.rating, HealthRating.excellent);
    });

    test('over-budget categories lose one point per percent overspent', () {
      final result = FinancialHealthCalculator.calculate(
        FinancialHealthInput.fromValues(
          monthlyIncome: 100000,
          monthlyExpenses: 60000,
          savingsBalance: 360000,
          discretionarySpending: 10000,
          budgets: const [
            Budget(id: 'b1', category: 'dining', monthlyLimit: 1000),
          ],
          spentByCategory: {'dining': 1500}, // 50% over
        ),
      );

      final budget = result.components.firstWhere((c) => c.key == 'budget');
      expect(budget.score, 50);
    });

    test('zero income yields zero savings and spending scores', () {
      final result = FinancialHealthCalculator.calculate(
        FinancialHealthInput.fromValues(
          monthlyIncome: 0,
          monthlyExpenses: 0,
          savingsBalance: 0,
          discretionarySpending: 0,
        ),
      );

      final byKey = {for (final c in result.components) c.key: c};
      expect(byKey['savings']!.score, 0);
      // Nothing is being spent, so the fund trivially covers everything.
      expect(byKey['emergency']!.score, 100);
      expect(byKey['spending']!.score, 0);
    });

    test('rating bands map score thresholds', () {
      FinancialHealthResult resultAt(int score) =>
          FinancialHealthResult(score: score, components: const []);

      expect(resultAt(100).rating, HealthRating.excellent);
      expect(resultAt(85).rating, HealthRating.excellent);
      expect(resultAt(84).rating, HealthRating.good);
      expect(resultAt(65).rating, HealthRating.good);
      expect(resultAt(64).rating, HealthRating.fair);
      expect(resultAt(45).rating, HealthRating.fair);
      expect(resultAt(44).rating, HealthRating.needsAttention);
      expect(resultAt(0).rating, HealthRating.needsAttention);
    });
  });

  group('InsightGenerator', () {
    test('over-budget categories take priority over every other rule', () {
      final insight = InsightGenerator.generate(
        budgets: const [
          Budget(id: 'b1', category: 'transport', monthlyLimit: 5000),
        ],
        spentByCategory: {'transport': 6500},
        monthlyIncome: 100000,
        monthlyExpenses: 95000, // also a low savings rate…
        savingsBalance: 10000, // …and a thin emergency fund.
      );

      expect(insight, isNotNull);
      expect(insight!.type, InsightType.warning);
      expect(insight.key, 'overBudget');
      expect(insight.params['count'], '1');
      expect(insight.params['categories'], 'transport');
    });

    test('a low savings rate surfaces when budgets are fine', () {
      final insight = InsightGenerator.generate(
        budgets: const [
          Budget(id: 'b1', category: 'rent', monthlyLimit: 5000),
        ],
        spentByCategory: {'rent': 4000},
        monthlyIncome: 100000,
        monthlyExpenses: 95000, // 5% saved
        savingsBalance: 300000, // healthy fund
      );

      expect(insight!.key, 'lowSavings');
      expect(insight.type, InsightType.warning);
      expect(insight.params['rate'], '5.0');
    });

    test('a thin emergency fund surfaces when the savings rate is healthy', () {
      final insight = InsightGenerator.generate(
        budgets: const [],
        spentByCategory: const {},
        monthlyIncome: 100000,
        monthlyExpenses: 50000, // 50% saved
        savingsBalance: 100000, // two months of expenses
      );

      expect(insight!.key, 'emergencyLow');
      expect(insight.type, InsightType.tip);
      expect(insight.params['months'], '2.0');
    });

    test('healthy finances get positive reinforcement', () {
      final insight = InsightGenerator.generate(
        budgets: const [],
        spentByCategory: const {},
        monthlyIncome: 100000,
        monthlyExpenses: 85000, // 15% saved
        savingsBalance: 300000, // six months of expenses
      );

      expect(insight!.key, 'goodPace');
      expect(insight.type, InsightType.positive);
      expect(insight.params['rate'], '15.0');
    });

    test('returns null when nothing can be judged', () {
      final insight = InsightGenerator.generate(
        budgets: const [],
        spentByCategory: const {},
        monthlyIncome: 0,
        monthlyExpenses: 0,
        savingsBalance: 0,
      );

      expect(insight, isNull);
    });
  });
}

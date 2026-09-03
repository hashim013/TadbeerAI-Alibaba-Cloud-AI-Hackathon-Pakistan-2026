import '../entities/budget.dart';
import '../entities/goal.dart';

/// Input for the health score — derived from [FinanceData] or built directly
/// in tests.
class FinancialHealthInput {
  const FinancialHealthInput({
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.savingsBalance,
    required this.discretionarySpending,
    required this.budgets,
    required this.spentByCategory,
    required this.goals,
  });

  factory FinancialHealthInput.fromValues({
    required double monthlyIncome,
    required double monthlyExpenses,
    required double savingsBalance,
    required double discretionarySpending,
    List<Budget> budgets = const [],
    Map<String, double> spentByCategory = const {},
    List<Goal> goals = const [],
  }) =>
      FinancialHealthInput(
        monthlyIncome: monthlyIncome,
        monthlyExpenses: monthlyExpenses,
        savingsBalance: savingsBalance,
        discretionarySpending: discretionarySpending,
        budgets: budgets,
        spentByCategory: spentByCategory,
        goals: goals,
      );

  final double monthlyIncome;
  final double monthlyExpenses;
  final double savingsBalance;

  /// Current-month spending on discretionary ("wants") categories.
  final double discretionarySpending;

  final List<Budget> budgets;

  /// Current-month spending per expense category, keyed by category id.
  final Map<String, double> spentByCategory;

  final List<Goal> goals;
}

/// How well one dimension of financial health is doing.
enum HealthRating { excellent, good, fair, needsAttention }

/// One scored dimension of the overall Financial Health Score.
class HealthComponent {
  const HealthComponent({
    required this.key,
    required this.score,
    required this.weight,
    required this.detailParams,
  });

  /// 'savings' | 'budget' | 'emergency' | 'goals' | 'spending' — the UI maps
  /// this to a localized title and detail sentence.
  final String key;

  /// 0..100.
  final int score;

  /// Fraction of the total score, e.g. 0.25.
  final double weight;

  /// Values interpolated into the localized detail sentence.
  final Map<String, String> detailParams;
}

/// The explainable result of the health calculation.
class FinancialHealthResult {
  const FinancialHealthResult({
    required this.score,
    required this.components,
  });

  /// Overall score, 0..100.
  final int score;
  final List<HealthComponent> components;

  HealthRating get rating {
    if (score >= 85) return HealthRating.excellent;
    if (score >= 65) return HealthRating.good;
    if (score >= 45) return HealthRating.fair;
    return HealthRating.needsAttention;
  }
}

/// Deterministic, explainable Financial Health Score.
///
/// Formula (fixed — identical inputs always produce the identical score):
///
/// | Component          | Weight | Score                                                     |
/// |--------------------|--------|-----------------------------------------------------------|
/// | Savings behavior   | 25%    | monthly savings rate vs. a 20% ideal                      |
/// | Budget discipline  | 25%    | per-budget adherence (on budget = 100, over = penalised)  |
/// | Emergency fund     | 20%    | months of expenses covered vs. a 6-month ideal            |
/// | Goal progress      | 15%    | average progress across active goals                      |
/// | Spending behavior  | 15%    | discretionary share of income vs. a 10–30% acceptable band|
///
/// No LLM is involved anywhere; this is pure, unit-testable arithmetic.
abstract final class FinancialHealthCalculator {
  static const _savingsWeight = 0.25;
  static const _budgetWeight = 0.25;
  static const _emergencyWeight = 0.20;
  static const _goalsWeight = 0.15;
  static const _spendingWeight = 0.15;

  /// Ideal monthly savings rate (20% of income).
  static const _idealSavingsRate = 0.20;

  /// Ideal emergency-fund coverage in months of expenses.
  static const _idealEmergencyMonths = 6.0;

  /// Discretionary share of income scoring band: ≤10% scores 100,
  /// ≥30% scores 0.
  static const _discretionaryFloor = 0.10;
  static const _discretionaryCeiling = 0.30;

  /// Neutral score used when a component carries no signal (e.g. no goals).
  static const _neutralScore = 50;

  static double _clampScore(double value) => value.clamp(0.0, 100.0);

  static FinancialHealthResult calculate(FinancialHealthInput input) {
    final savings = _savingsComponent(input);
    final budget = _budgetComponent(input);
    final emergency = _emergencyComponent(input);
    final goals = _goalsComponent(input);
    final spending = _spendingComponent(input);

    final total = savings.score * _savingsWeight +
        budget.score * _budgetWeight +
        emergency.score * _emergencyWeight +
        goals.score * _goalsWeight +
        spending.score * _spendingWeight;

    return FinancialHealthResult(
      score: total.round(),
      components: [savings, budget, emergency, goals, spending],
    );
  }

  // ── Components ───────────────────────────────────────────────────────────

  static HealthComponent _savingsComponent(FinancialHealthInput input) {
    double score = 0;
    var rate = 0.0;
    if (input.monthlyIncome > 0) {
      rate =
          (input.monthlyIncome - input.monthlyExpenses) / input.monthlyIncome;
      score = _clampScore(rate / _idealSavingsRate * 100);
    }
    return HealthComponent(
      key: 'savings',
      score: score.round(),
      weight: _savingsWeight,
      detailParams: {'rate': _formatPercent(rate)},
    );
  }

  static HealthComponent _budgetComponent(FinancialHealthInput input) {
    if (input.budgets.isEmpty) {
      return const HealthComponent(
        key: 'budget',
        score: _neutralScore,
        weight: _budgetWeight,
        detailParams: {'onTrack': '0', 'total': '0'},
      );
    }
    var onTrack = 0;
    var sum = 0.0;
    for (final budget in input.budgets) {
      final spent = input.spentByCategory[budget.category] ?? 0;
      final utilization =
          budget.monthlyLimit > 0 ? spent / budget.monthlyLimit : 0.0;
      if (spent <= budget.monthlyLimit) {
        onTrack++;
        sum += 100;
      } else {
        // Over budget: score loses 1 point per percentage point overspent.
        sum += _clampScore(100 - (utilization - 1) * 100);
      }
    }
    return HealthComponent(
      key: 'budget',
      score: (sum / input.budgets.length).round(),
      weight: _budgetWeight,
      detailParams: {
        'onTrack': '$onTrack',
        'total': '${input.budgets.length}',
      },
    );
  }

  static HealthComponent _emergencyComponent(FinancialHealthInput input) {
    double score;
    var months = 0.0;
    if (input.monthlyExpenses <= 0) {
      // Nothing being spent — the fund trivially covers everything.
      score = 100;
      months = _idealEmergencyMonths;
    } else {
      months = input.savingsBalance / input.monthlyExpenses;
      score = _clampScore(months / _idealEmergencyMonths * 100);
    }
    return HealthComponent(
      key: 'emergency',
      score: score.round(),
      weight: _emergencyWeight,
      detailParams: {'months': months.toStringAsFixed(1)},
    );
  }

  static HealthComponent _goalsComponent(FinancialHealthInput input) {
    if (input.goals.isEmpty) {
      return const HealthComponent(
        key: 'goals',
        score: _neutralScore,
        weight: _goalsWeight,
        detailParams: {'percent': '0'},
      );
    }
    final progress = input.goals.fold<double>(
        0,
        (sum, goal) =>
            sum +
            (goal.targetAmount > 0
                ? (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0)
                : 1.0));
    final avg = (progress / input.goals.length) * 100;
    return HealthComponent(
      key: 'goals',
      score: avg.round(),
      weight: _goalsWeight,
      detailParams: {'percent': avg.round().toString()},
    );
  }

  static HealthComponent _spendingComponent(FinancialHealthInput input) {
    double score = 0;
    var share = 0.0;
    if (input.monthlyIncome > 0) {
      share = input.discretionarySpending / input.monthlyIncome;
      score = _clampScore((_discretionaryCeiling - share) /
          (_discretionaryCeiling - _discretionaryFloor) *
          100);
    }
    return HealthComponent(
      key: 'spending',
      score: score.round(),
      weight: _spendingWeight,
      detailParams: {'percent': _formatPercent(share)},
    );
  }

  static String _formatPercent(double fraction) =>
      (fraction * 100).toStringAsFixed(1);
}

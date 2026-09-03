import '../entities/budget.dart';

/// Severity of a generated insight — drives color and icon in the UI.
enum InsightType { positive, warning, tip }

/// A deterministic, rule-based financial insight.
///
/// Phase 2 insights come from fixed rules over the user's demo data — no AI
/// involved. The [key] + [params] are resolved to localized copy in the UI.
class FinanceInsight {
  const FinanceInsight({
    required this.type,
    required this.key,
    required this.params,
  });

  final InsightType type;

  /// 'overBudget' | 'lowSavings' | 'emergencyLow' | 'goodPace'.
  final String key;
  final Map<String, String> params;
}

/// Generates one personalized, deterministic insight for the dashboard.
///
/// Priority: over-budget categories > low savings rate > thin emergency
/// fund > positive reinforcement. Rules are evaluated top-down and the
/// first match wins, so the output is fully explainable.
abstract final class InsightGenerator {
  /// Categories over budget are capped in the message so it stays readable.
  static const _maxOverBudgetListed = 2;

  static FinanceInsight? generate({
    required List<Budget> budgets,
    required Map<String, double> spentByCategory,
    required double monthlyIncome,
    required double monthlyExpenses,
    required double savingsBalance,
  }) {
    // 1. Over-budget categories.
    final overCategories = budgets
        .where((b) => (spentByCategory[b.category] ?? 0) > b.monthlyLimit)
        .map((b) => b.category)
        .toList();
    if (overCategories.isNotEmpty) {
      return FinanceInsight(
        type: InsightType.warning,
        key: 'overBudget',
        params: {
          'categories': overCategories.take(_maxOverBudgetListed).join(', '),
          'count': '${overCategories.length}',
        },
      );
    }

    // 2. Savings rate below 10%.
    if (monthlyIncome > 0) {
      final rate = (monthlyIncome - monthlyExpenses) / monthlyIncome;
      if (rate < 0.10) {
        return FinanceInsight(
          type: InsightType.warning,
          key: 'lowSavings',
          params: {'rate': (rate * 100).toStringAsFixed(1)},
        );
      }
    }

    // 3. Emergency coverage under 3 months.
    if (monthlyExpenses > 0) {
      final months = savingsBalance / monthlyExpenses;
      if (months < 3) {
        return FinanceInsight(
          type: InsightType.tip,
          key: 'emergencyLow',
          params: {'months': months.toStringAsFixed(1)},
        );
      }
    }

    // 4. Positive reinforcement.
    if (monthlyIncome > 0) {
      final rate = (monthlyIncome - monthlyExpenses) / monthlyIncome;
      if (rate >= 0.10) {
        return FinanceInsight(
          type: InsightType.positive,
          key: 'goodPace',
          params: {'rate': (rate * 100).toStringAsFixed(1)},
        );
      }
    }

    return null;
  }
}

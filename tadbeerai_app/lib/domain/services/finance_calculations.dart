import '../entities/budget.dart';
import '../entities/goal.dart';
import '../entities/transaction.dart';

/// One month of aggregated finance activity.
class MonthlyPoint {
  const MonthlyPoint({
    required this.month,
    required this.income,
    required this.expenses,
  });

  /// Any moment inside the month (normalized to day 1).
  final DateTime month;
  final double income;
  final double expenses;

  double get savings => income - expenses;
}

/// One slice of a category breakdown.
class CategorySlice {
  const CategorySlice({
    required this.category,
    required this.amount,
    required this.share,
  });

  final String category;
  final double amount;

  /// Fraction of the total, 0..1.
  final double share;
}

/// Derived status for a single category budget.
class BudgetStatus {
  const BudgetStatus({
    required this.spent,
    required this.limit,
  });

  final double spent;
  final double limit;

  double get remaining => limit - spent;

  /// Spent / limit — 1.0 means exactly on budget.
  double get utilization => limit > 0 ? spent / limit : 0;

  bool get isOver => spent > limit;

  /// True when utilization is within a small epsilon of (or over) 100%.
  bool get isNearLimit => utilization >= 0.9 && !isOver;
}

/// Derived status for a savings goal.
class GoalStatus {
  const GoalStatus({
    required this.progress,
    required this.remainingAmount,
    required this.monthsLeft,
    required this.requiredMonthly,
  });

  /// Fraction saved, clamped to 0..1.
  final double progress;
  final double remainingAmount;

  /// Whole months until the target date (never negative).
  final int monthsLeft;

  /// Amount to save per month to finish exactly on time.
  final double requiredMonthly;

  bool get isComplete => remainingAmount <= 0;
}

/// Deterministic finance math — pure functions, no LLM, no Flutter.
///
/// Every widget-level number in the finance features flows through these
/// helpers so the arithmetic stays testable and explainable.
abstract final class FinanceCalculations {
  static bool _inMonth(DateTime d, DateTime month) =>
      d.year == month.year && d.month == month.month;

  // ── Totals ──────────────────────────────────────────────────────────────

  static double totalIncome(Iterable<Transaction> transactions) =>
      _sumOf(transactions.where((t) => t.type == TransactionType.income));

  static double totalExpenses(Iterable<Transaction> transactions) =>
      _sumOf(transactions.where((t) => t.type == TransactionType.expense));

  static double _sumOf(Iterable<Transaction> transactions) =>
      transactions.fold(0, (sum, t) => sum + t.amount);

  /// Money currently set aside: opening balance + net of all activity.
  static double currentSavings(
          double openingBalance, Iterable<Transaction> transactions) =>
      openingBalance + totalIncome(transactions) - totalExpenses(transactions);

  // ── Month-scoped ─────────────────────────────────────────────────────────

  static double monthlyIncome(List<Transaction> transactions, DateTime month) =>
      _sumOf(transactions.where(
          (t) => t.type == TransactionType.income && _inMonth(t.date, month)));

  static double monthlyExpenses(
          List<Transaction> transactions, DateTime month) =>
      _sumOf(transactions.where(
          (t) => t.type == TransactionType.expense && _inMonth(t.date, month)));

  /// Expense totals per category for [month].
  static Map<String, double> spentByCategory(
      List<Transaction> transactions, DateTime month) {
    final result = <String, double>{};
    for (final t in transactions) {
      if (t.type != TransactionType.expense || !_inMonth(t.date, month)) {
        continue;
      }
      result[t.category] = (result[t.category] ?? 0) + t.amount;
    }
    return result;
  }

  /// Spending on discretionary ("wants") categories for [month].
  static double discretionarySpending(List<Transaction> transactions,
      DateTime month, Set<String> discretionaryCategoryIds) {
    final spent = spentByCategory(transactions, month);
    return spent.entries
        .where((e) => discretionaryCategoryIds.contains(e.key))
        .fold(0, (sum, e) => sum + e.value);
  }

  /// The [monthCount] months ending with [from]'s month, oldest first.
  static List<MonthlyPoint> monthlySeries(List<Transaction> transactions,
      {required DateTime from, int monthCount = 3}) {
    final points = <MonthlyPoint>[];
    for (var i = monthCount - 1; i >= 0; i--) {
      final month = DateTime(from.year, from.month - i);
      points.add(MonthlyPoint(
        month: month,
        income: monthlyIncome(transactions, month),
        expenses: monthlyExpenses(transactions, month),
      ));
    }
    return points;
  }

  /// Expense category breakdown for [month], largest slice first.
  static List<CategorySlice> categoryBreakdown(
      List<Transaction> transactions, DateTime month) {
    final spent = spentByCategory(transactions, month);
    final total = spent.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return const [];
    final slices = spent.entries
        .map((e) => CategorySlice(
              category: e.key,
              amount: e.value,
              share: e.value / total,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return slices;
  }

  // ── Budgets & goals ──────────────────────────────────────────────────────

  static BudgetStatus budgetStatus(Budget budget, double spent) =>
      BudgetStatus(spent: spent, limit: budget.monthlyLimit);

  static GoalStatus goalStatus(Goal goal, DateTime now) {
    final remaining = (goal.targetAmount - goal.savedAmount)
        .clamp(0.0, goal.targetAmount)
        .toDouble();
    final progress = goal.targetAmount > 0
        ? (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0).toDouble()
        : 1.0;
    final daysLeft = goal.targetDate.difference(now).inDays;
    final monthsLeft = daysLeft <= 0 ? 0 : (daysLeft / 30.44).ceil();
    final requiredMonthly = monthsLeft > 0 ? remaining / monthsLeft : remaining;
    return GoalStatus(
      progress: progress,
      remainingAmount: remaining,
      monthsLeft: monthsLeft,
      requiredMonthly: requiredMonthly,
    );
  }
}

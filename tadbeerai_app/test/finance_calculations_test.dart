import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/domain/entities/budget.dart';
import 'package:tadbeerai/domain/entities/goal.dart';
import 'package:tadbeerai/domain/entities/transaction.dart';
import 'package:tadbeerai/domain/services/finance_calculations.dart';

/// Pure-arithmetic tests for every number the finance widgets display:
/// totals, month scoping, breakdowns, budget adherence and goal progress.
void main() {
  Transaction tx(
    String id,
    double amount,
    TransactionType type,
    String category,
    DateTime date,
  ) =>
      Transaction(
        id: id,
        title: id,
        amount: amount,
        type: type,
        category: category,
        date: date,
      );

  group('totals', () {
    test('totalIncome and totalExpenses only sum their own type', () {
      final transactions = [
        tx('a', 80000, TransactionType.income, 'salary', DateTime(2026, 3, 1)),
        tx('b', 5000, TransactionType.income, 'freelance',
            DateTime(2026, 3, 12)),
        tx('c', 18000, TransactionType.expense, 'rent', DateTime(2026, 3, 1)),
        tx('d', 1200, TransactionType.expense, 'groceries',
            DateTime(2026, 2, 2)),
      ];

      expect(FinanceCalculations.totalIncome(transactions), 85000);
      expect(FinanceCalculations.totalExpenses(transactions), 19200);
    });

    test('currentSavings adds the opening balance to net activity', () {
      final transactions = [
        tx('a', 80000, TransactionType.income, 'salary', DateTime(2026, 3, 1)),
        tx('b', 65000, TransactionType.expense, 'rent', DateTime(2026, 3, 1)),
      ];

      expect(
        FinanceCalculations.currentSavings(10000, transactions),
        25000,
      );
    });
  });

  group('month scoping', () {
    test('monthlyIncome and monthlyExpenses ignore other months', () {
      final transactions = [
        tx('a', 80000, TransactionType.income, 'salary', DateTime(2026, 3, 1)),
        tx('b', 20000, TransactionType.income, 'salary', DateTime(2026, 2, 1)),
        tx('c', 30000, TransactionType.expense, 'rent', DateTime(2026, 3, 2)),
        tx('d', 15000, TransactionType.expense, 'rent', DateTime(2026, 2, 2)),
        tx('e', 1000, TransactionType.expense, 'rent', DateTime(2025, 3, 2)),
      ];

      final month = DateTime(2026, 3, 15);
      expect(FinanceCalculations.monthlyIncome(transactions, month), 80000);
      expect(FinanceCalculations.monthlyExpenses(transactions, month), 30000);
    });

    test('spentByCategory aggregates expenses per category for the month', () {
      final month = DateTime(2026, 3, 15);
      final transactions = [
        tx('a', 3900, TransactionType.expense, 'groceries',
            DateTime(2026, 3, 2)),
        tx('b', 3900, TransactionType.expense, 'groceries',
            DateTime(2026, 3, 9)),
        tx('c', 18000, TransactionType.expense, 'rent', DateTime(2026, 3, 1)),
        tx('d', 5000, TransactionType.expense, 'groceries',
            DateTime(2026, 2, 2)),
        tx('e', 5000, TransactionType.income, 'salary', DateTime(2026, 3, 1)),
      ];

      final spent = FinanceCalculations.spentByCategory(transactions, month);

      expect(spent['groceries'], 7800);
      expect(spent['rent'], 18000);
      expect(spent.containsKey('salary'), isFalse);
    });

    test('discretionarySpending sums only the wants categories', () {
      final month = DateTime(2026, 3, 15);
      final transactions = [
        tx('a', 500, TransactionType.expense, 'dining', DateTime(2026, 3, 2)),
        tx('b', 300, TransactionType.expense, 'shopping', DateTime(2026, 3, 3)),
        tx('c', 700, TransactionType.expense, 'groceries',
            DateTime(2026, 3, 4)),
        tx('d', 100, TransactionType.expense, 'dining', DateTime(2026, 2, 4)),
      ];

      final result = FinanceCalculations.discretionarySpending(
        transactions,
        month,
        const {'dining', 'shopping'},
      );

      expect(result, 800);
    });

    test('monthlySeries returns oldest-first months across a year rollover',
        () {
      final transactions = [
        tx('a', 100, TransactionType.income, 'salary', DateTime(2026, 1, 5)),
        tx('b', 40, TransactionType.expense, 'rent', DateTime(2026, 1, 6)),
        tx('c', 200, TransactionType.income, 'salary', DateTime(2025, 12, 5)),
        tx('d', 80, TransactionType.expense, 'rent', DateTime(2025, 12, 6)),
      ];

      final series = FinanceCalculations.monthlySeries(
        transactions,
        from: DateTime(2026, 1, 15),
        monthCount: 2,
      );

      expect(series, hasLength(2));
      expect(series[0].month, DateTime(2025, 12, 1));
      expect(series[1].month, DateTime(2026, 1, 1));
      expect(series[0].income, 200);
      expect(series[0].expenses, 80);
      expect(series[0].savings, 120);
      expect(series[1].savings, 60);
    });
  });

  group('category breakdown', () {
    test('slices are sorted by amount and shares sum to one', () {
      final month = DateTime(2026, 3, 15);
      final transactions = [
        tx('a', 3000, TransactionType.expense, 'groceries',
            DateTime(2026, 3, 2)),
        tx('b', 1000, TransactionType.expense, 'transport',
            DateTime(2026, 3, 3)),
        tx('c', 500, TransactionType.expense, 'groceries',
            DateTime(2026, 2, 2)),
        tx('d', 900, TransactionType.income, 'salary', DateTime(2026, 3, 1)),
      ];

      final breakdown =
          FinanceCalculations.categoryBreakdown(transactions, month);

      expect(breakdown, hasLength(2));
      expect(breakdown[0].category, 'groceries');
      expect(breakdown[0].amount, 3000);
      expect(breakdown[0].share, 0.75);
      expect(breakdown[1].category, 'transport');
      expect(breakdown[1].share, 0.25);

      final totalShare =
          breakdown.fold<double>(0, (sum, slice) => sum + slice.share);
      expect(totalShare, 1.0);
    });

    test('a month without expenses yields no slices', () {
      expect(
        FinanceCalculations.categoryBreakdown(
          const [],
          DateTime(2026, 3, 15),
        ),
        isEmpty,
      );
    });
  });

  group('budgetStatus', () {
    const budget = Budget(id: 'b1', category: 'dining', monthlyLimit: 1000);

    test('an on-track budget reports remaining and near-limit state', () {
      final status = FinanceCalculations.budgetStatus(budget, 900);

      expect(status.remaining, 100);
      expect(status.utilization, 0.9);
      expect(status.isOver, isFalse);
      expect(status.isNearLimit, isTrue);
    });

    test('an over-budget budget reports negative remaining', () {
      final status = FinanceCalculations.budgetStatus(budget, 1200);

      expect(status.isOver, isTrue);
      expect(status.isNearLimit, isFalse);
      expect(status.remaining, -200);
      expect(status.utilization, 1.2);
    });

    test('spending exactly the limit is on budget but not over', () {
      final status = FinanceCalculations.budgetStatus(budget, 1000);

      expect(status.isOver, isFalse);
      expect(status.utilization, 1.0);
    });
  });

  group('goalStatus', () {
    final now = DateTime(2026, 3, 15);

    test('reports progress, remaining, months left and required monthly', () {
      final goal = Goal(
        id: 'g1',
        title: 'Laptop',
        targetAmount: 100000,
        savedAmount: 40000,
        targetDate: DateTime(2026, 5, 16), // 62 days away
      );

      final status = FinanceCalculations.goalStatus(goal, now);

      expect(status.progress, 0.4);
      expect(status.remainingAmount, 60000);
      expect(status.monthsLeft, 3); // ceil(62 / 30.44)
      expect(status.requiredMonthly, 20000);
      expect(status.isComplete, isFalse);
    });

    test('progress above 100 percent is clamped to a complete goal', () {
      final goal = Goal(
        id: 'g1',
        title: 'Oversaved',
        targetAmount: 10000,
        savedAmount: 12000,
        targetDate: DateTime(2026, 12, 31),
      );

      final status = FinanceCalculations.goalStatus(goal, now);

      expect(status.progress, 1.0);
      expect(status.remainingAmount, 0);
      expect(status.isComplete, isTrue);
    });

    test('a past target date makes the remainder due immediately', () {
      final goal = Goal(
        id: 'g1',
        title: 'Late',
        targetAmount: 10000,
        savedAmount: 2000,
        targetDate: DateTime(2026, 1, 1),
      );

      final status = FinanceCalculations.goalStatus(goal, now);

      expect(status.monthsLeft, 0);
      expect(status.requiredMonthly, 8000);
    });
  });
}

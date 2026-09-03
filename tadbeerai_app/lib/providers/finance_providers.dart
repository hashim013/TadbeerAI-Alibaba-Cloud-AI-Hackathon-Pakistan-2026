import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/mock_finance_repository.dart';
import '../domain/entities/budget.dart';
import '../domain/entities/finance_category.dart';
import '../domain/entities/finance_data.dart';
import '../domain/entities/goal.dart';
import '../domain/entities/transaction.dart';
import '../domain/repositories/finance_repository.dart';
import '../domain/services/finance_calculations.dart';
import '../domain/services/financial_health_calculator.dart';
import '../domain/services/insight_generator.dart';
import 'repository_providers.dart';

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => MockFinanceRepository(ref.watch(sharedPrefsProvider)),
);

/// Owns the finance ledger: transactions, budgets and goals.
///
/// Mutations go through the repository and keep the in-memory state in
/// sync so the UI reacts instantly.
class FinanceController extends AsyncNotifier<FinanceData> {
  FinanceRepository get _repo => ref.read(financeRepositoryProvider);

  @override
  Future<FinanceData> build() => _repo.getFinanceData();

  // ── Transactions ────────────────────────────────────────────────────────

  Future<void> addTransaction(Transaction transaction) async {
    await _guarded(() async {
      await _repo.addTransaction(transaction);
      _apply((data) =>
          data.copyWith(transactions: [...data.transactions, transaction]));
    });
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await _guarded(() async {
      await _repo.updateTransaction(transaction);
      _apply((data) => data.copyWith(
          transactions: data.transactions
              .map((t) => t.id == transaction.id ? transaction : t)
              .toList()));
    });
  }

  Future<void> deleteTransaction(String id) async {
    await _guarded(() async {
      await _repo.deleteTransaction(id);
      _apply((data) => data.copyWith(
          transactions: data.transactions.where((t) => t.id != id).toList()));
    });
  }

  // ── Budgets ──────────────────────────────────────────────────────────────

  Future<void> upsertBudget(Budget budget) async {
    await _guarded(() async {
      await _repo.upsertBudget(budget);
      _apply((data) {
        final remaining = data.budgets
            .where((b) => b.id != budget.id && b.category != budget.category)
            .toList();
        return data.copyWith(budgets: [...remaining, budget]);
      });
    });
  }

  Future<void> deleteBudget(String id) async {
    await _guarded(() async {
      await _repo.deleteBudget(id);
      _apply((data) => data.copyWith(
          budgets: data.budgets.where((b) => b.id != id).toList()));
    });
  }

  // ── Goals ────────────────────────────────────────────────────────────────

  Future<void> addGoal(Goal goal) async {
    await _guarded(() async {
      await _repo.addGoal(goal);
      _apply((data) => data.copyWith(goals: [...data.goals, goal]));
    });
  }

  Future<void> updateGoal(Goal goal) async {
    await _guarded(() async {
      await _repo.updateGoal(goal);
      _apply((data) => data.copyWith(
          goals: data.goals.map((g) => g.id == goal.id ? goal : g).toList()));
    });
  }

  Future<void> deleteGoal(String id) async {
    await _guarded(() async {
      await _repo.deleteGoal(id);
      _apply((data) =>
          data.copyWith(goals: data.goals.where((g) => g.id != id).toList()));
    });
  }

  // ── Demo data ────────────────────────────────────────────────────────────

  Future<void> resetDemoData() async {
    state = const AsyncLoading();
    try {
      await _repo.resetDemoData();
      state = AsyncData(await _repo.getFinanceData());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _guarded(Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  void _apply(FinanceData Function(FinanceData) transform) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(transform(current));
  }
}

final financeControllerProvider =
    AsyncNotifierProvider<FinanceController, FinanceData>(
        FinanceController.new);

/// The current month's Financial Health Score, recomputed whenever the
/// underlying finance data changes.
final financialHealthProvider = Provider<FinancialHealthResult?>((ref) {
  final data = ref.watch(financeControllerProvider).value;
  if (data == null) return null;

  final now = DateTime.now();
  final input = FinancialHealthInput.fromValues(
    monthlyIncome: FinanceCalculations.monthlyIncome(data.transactions, now),
    monthlyExpenses:
        FinanceCalculations.monthlyExpenses(data.transactions, now),
    savingsBalance: FinanceCalculations.currentSavings(
        data.openingSavingsBalance, data.transactions),
    discretionarySpending: FinanceCalculations.discretionarySpending(
        data.transactions, now, FinanceCategories.discretionaryExpenseIds),
    budgets: data.budgets,
    spentByCategory:
        FinanceCalculations.spentByCategory(data.transactions, now),
    goals: data.goals,
  );
  return FinancialHealthCalculator.calculate(input);
});

/// One rule-based, personalized insight for the dashboard (no AI — fixed
/// rules over the user's demo data).
final financeInsightProvider = Provider<FinanceInsight?>((ref) {
  final data = ref.watch(financeControllerProvider).value;
  if (data == null) return null;

  final now = DateTime.now();
  return InsightGenerator.generate(
    budgets: data.budgets,
    spentByCategory:
        FinanceCalculations.spentByCategory(data.transactions, now),
    monthlyIncome: FinanceCalculations.monthlyIncome(data.transactions, now),
    monthlyExpenses:
        FinanceCalculations.monthlyExpenses(data.transactions, now),
    savingsBalance: FinanceCalculations.currentSavings(
        data.openingSavingsBalance, data.transactions),
  );
});

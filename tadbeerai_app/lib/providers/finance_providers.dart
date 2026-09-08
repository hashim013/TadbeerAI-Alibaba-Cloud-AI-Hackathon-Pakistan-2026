import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/api_config.dart';
import '../data/repositories/api_finance_repository.dart';
import '../data/repositories/mock_finance_repository.dart';
import '../domain/entities/budget.dart';
import '../domain/entities/finance_category.dart';
import '../domain/entities/finance_data.dart';
import '../domain/entities/financial_profile.dart';
import '../domain/entities/goal.dart';
import '../domain/entities/transaction.dart';
import '../domain/repositories/finance_repository.dart';
import '../domain/services/finance_calculations.dart';
import '../domain/services/financial_health_calculator.dart';
import '../domain/services/insight_generator.dart';
import '../features/auth/auth_controller.dart';
import 'assistant_providers.dart';
import 'profile_providers.dart';
import 'repository_providers.dart';

/// Finance ledger source: `live` (default) syncs the per-user ledger with the
/// backend (Firestore) through an offline-first local cache;
/// `--dart-define=FINANCE_MODE=demo` keeps the on-device mock ledger for UI
/// development and headless tests.
final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  if (ApiConfig.useMockFinance) {
    return MockFinanceRepository(ref.watch(sharedPrefsProvider));
  }
  final repo = ApiFinanceRepository(
    dio: ref.watch(apiDioProvider),
    prefs: ref.watch(sharedPrefsProvider),
    uidProvider: () => ref.read(authControllerProvider)?.id,
  );
  ref.onDispose(repo.dispose);
  return repo;
});

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
      await ref
          .read(financialProfileControllerProvider.notifier)
          .syncWithTransaction(transaction);
    });
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await _guarded(() async {
      final old = state.valueOrNull?.transactions.firstWhere(
        (t) => t.id == transaction.id,
        orElse: () => transaction,
      );
      await _repo.updateTransaction(transaction);
      _apply((data) => data.copyWith(
          transactions: data.transactions
              .map((t) => t.id == transaction.id ? transaction : t)
              .toList()));
      if (old != null && old != transaction) {
        await ref
            .read(financialProfileControllerProvider.notifier)
            .syncTransactionUpdate(
              oldTransaction: old,
              newTransaction: transaction,
            );
      }
    });
  }

  Future<void> deleteTransaction(String id) async {
    await _guarded(() async {
      final toDelete = state.valueOrNull?.transactions.firstWhere(
        (t) => t.id == id,
        orElse: () => Transaction(
          id: id,
          title: '',
          amount: 0.0,
          type: TransactionType.expense,
          category: '',
          date: DateTime.now(),
        ),
      );
      await _repo.deleteTransaction(id);
      _apply((data) => data.copyWith(
          transactions: data.transactions.where((t) => t.id != id).toList()));
      if (toDelete != null && toDelete.amount > 0) {
        await ref
            .read(financialProfileControllerProvider.notifier)
            .syncWithTransaction(toDelete, isReversal: true);
      }
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
/// underlying finance data or user financial persona changes.
final financialHealthProvider = Provider<FinancialHealthResult?>((ref) {
  final data = ref.watch(financeControllerProvider).value;
  final profile = ref.watch(financialProfileControllerProvider).valueOrNull;

  if (data == null && profile == null) return null;

  final now = DateTime.now();
  final txIncome = data != null
      ? FinanceCalculations.monthlyIncome(data.transactions, now)
      : 0.0;
  final txExpenses = data != null
      ? FinanceCalculations.monthlyExpenses(data.transactions, now)
      : 0.0;
  final txSavings = data != null
      ? FinanceCalculations.currentSavings(
          data.openingSavingsBalance, data.transactions)
      : 0.0;
  final txDiscretionary = data != null
      ? FinanceCalculations.discretionarySpending(
          data.transactions, now, FinanceCategories.discretionaryExpenseIds)
      : 0.0;

  // Prefer profile values if set (which contain persona baseline + synchronized transactions);
  // fallback to raw transaction sums if profile is not completed yet.
  final monthlyIncome =
      (profile?.monthlyIncome != null && profile!.monthlyIncome! > 0)
          ? profile.monthlyIncome!
          : txIncome;
  final monthlyExpenses = (profile?.monthlyEssentialExpenses != null &&
          profile!.monthlyEssentialExpenses! > 0)
      ? profile.monthlyEssentialExpenses!
      : txExpenses;
  final savingsBalance =
      (profile?.totalSavings != null && profile!.totalSavings! > 0)
          ? profile.totalSavings!
          : (txSavings > 0 ? txSavings : 0.0);
  final discretionarySpending = txDiscretionary > 0
      ? txDiscretionary
      : (monthlyIncome > monthlyExpenses
          ? (monthlyIncome - monthlyExpenses) * 0.25
          : 0.0);

  // Effective budgets: use existing budgets, or construct baseline from persona essential expenses
  final budgets = (data?.budgets.isNotEmpty == true)
      ? data!.budgets
      : (monthlyExpenses > 0
          ? [
              Budget(
                id: 'persona_essentials',
                category: 'essentials',
                monthlyLimit: monthlyExpenses,
              ),
            ]
          : <Budget>[]);

  // Effective spent by category
  final spentByCategory = (data?.transactions.isNotEmpty == true)
      ? FinanceCalculations.spentByCategory(data!.transactions, now)
      : (monthlyExpenses > 0
          ? {'essentials': monthlyExpenses}
          : <String, double>{});

  // Effective goals: use existing goals, or derive goal from persona primaryGoal
  final goals = (data?.goals.isNotEmpty == true)
      ? data!.goals
      : (profile?.primaryGoal != null
          ? [
              Goal(
                id: 'primary_goal',
                title: _goalTitle(profile!.primaryGoal!),
                targetAmount:
                    (monthlyExpenses > 0 ? monthlyExpenses * 4 : 100000),
                savedAmount: savingsBalance.clamp(
                  0.0,
                  (monthlyExpenses > 0 ? monthlyExpenses * 4 : 100000),
                ),
                targetDate: now.add(const Duration(days: 180)),
              ),
            ]
          : <Goal>[]);

  final input = FinancialHealthInput.fromValues(
    monthlyIncome: monthlyIncome,
    monthlyExpenses: monthlyExpenses,
    savingsBalance: savingsBalance,
    discretionarySpending: discretionarySpending,
    budgets: budgets,
    spentByCategory: spentByCategory,
    goals: goals,
  );
  return FinancialHealthCalculator.calculate(input, persona: profile?.persona);
});

String _goalTitle(PrimaryGoal goal) => switch (goal) {
      PrimaryGoal.emergencyFund => 'Emergency Fund',
      PrimaryGoal.saveMore => 'Savings Target',
      PrimaryGoal.education => 'Education Fund',
      PrimaryGoal.newDevice => 'Device Purchase',
      PrimaryGoal.businessGrowth => 'Business Expansion',
      PrimaryGoal.reduceSpending => 'Expense Reduction',
      PrimaryGoal.other => 'Personal Goal',
    };

/// One rule-based, personalized insight for the dashboard (no AI — fixed
/// rules over the user's data and financial persona).
final financeInsightProvider = Provider<FinanceInsight?>((ref) {
  final data = ref.watch(financeControllerProvider).value;
  final profile = ref.watch(financialProfileControllerProvider).valueOrNull;
  if (data == null && profile == null) return null;

  final now = DateTime.now();
  final txIncome = data != null
      ? FinanceCalculations.monthlyIncome(data.transactions, now)
      : 0.0;
  final txExpenses = data != null
      ? FinanceCalculations.monthlyExpenses(data.transactions, now)
      : 0.0;
  final txSavings = data != null
      ? FinanceCalculations.currentSavings(
          data.openingSavingsBalance, data.transactions)
      : 0.0;

  final monthlyIncome =
      txIncome > 0 ? txIncome : (profile?.monthlyIncome ?? 0.0);
  final monthlyExpenses =
      txExpenses > 0 ? txExpenses : (profile?.monthlyEssentialExpenses ?? 0.0);
  final savingsBalance =
      txSavings > 0 ? txSavings : (profile?.totalSavings ?? 0.0);

  final budgets = data?.budgets ?? const [];
  final spentByCategory = data != null
      ? FinanceCalculations.spentByCategory(data.transactions, now)
      : const <String, double>{};

  return InsightGenerator.generate(
    budgets: budgets,
    spentByCategory: spentByCategory,
    monthlyIncome: monthlyIncome,
    monthlyExpenses: monthlyExpenses,
    savingsBalance: savingsBalance,
  );
});

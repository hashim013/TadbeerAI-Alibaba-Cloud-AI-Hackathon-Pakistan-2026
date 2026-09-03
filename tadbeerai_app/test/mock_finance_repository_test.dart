import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/core/constants/app_constants.dart';
import 'package:tadbeerai/data/mock/mock_finance_data.dart';
import 'package:tadbeerai/data/repositories/mock_finance_repository.dart';
import 'package:tadbeerai/domain/entities/budget.dart';
import 'package:tadbeerai/domain/entities/goal.dart';
import 'package:tadbeerai/domain/entities/transaction.dart';
import 'package:tadbeerai/domain/services/finance_calculations.dart';

/// Behavioural tests for the mock finance repository: seeding, CRUD and
/// on-device persistence (every mutation must survive a fresh instance,
/// which proves the SharedPreferences round-trip through JSON).
void main() {
  // A fixed "today" keeps the relative demo dataset deterministic.
  final now = DateTime(2026, 3, 15);

  late SharedPreferences prefs;
  late MockFinanceRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = MockFinanceRepository(prefs, now: () => now);
  });

  /// A brand-new repository over the same storage — simulates an app restart.
  MockFinanceRepository freshRepository() =>
      MockFinanceRepository(prefs, now: () => now);

  group('seeding', () {
    test('first launch seeds the full demo dataset', () async {
      final data = await repository.getFinanceData();

      expect(data.transactions, hasLength(88)); // 4 months x 22 entries
      expect(data.budgets, hasLength(9));
      expect(data.goals, hasLength(4));
      expect(data.openingSavingsBalance, MockFinanceData.openingSavingsBalance);
    });

    test('current-month totals are exactly 80k income / 65k expenses',
        () async {
      final data = await repository.getFinanceData();

      expect(
        FinanceCalculations.monthlyIncome(data.transactions, now),
        80000,
      );
      expect(
        FinanceCalculations.monthlyExpenses(data.transactions, now),
        65000,
      );
      expect(
        FinanceCalculations.monthlyIncome(data.transactions, now) -
            FinanceCalculations.monthlyExpenses(data.transactions, now),
        15000,
      );
    });

    test('exactly two seeded categories are over budget', () async {
      final data = await repository.getFinanceData();
      final spent = FinanceCalculations.spentByCategory(data.transactions, now);

      final over = data.budgets
          .where((b) => (spent[b.category] ?? 0) > b.monthlyLimit)
          .map((b) => b.category)
          .toSet();

      expect(over, {'transport', 'shopping'});
    });

    test('the seed never contains future transactions', () async {
      final data = await repository.getFinanceData();

      for (final t in data.transactions) {
        expect(t.date.isAfter(now), isFalse,
            reason: '"${t.title}" is dated ${t.date}');
      }
    });
  });

  group('transaction persistence', () {
    Transaction coffee(double amount) => Transaction(
          id: 'tx-extra',
          title: 'Coffee',
          amount: amount,
          type: TransactionType.expense,
          category: 'dining',
          date: now,
        );

    test('an added transaction survives a fresh repository instance', () async {
      await repository.addTransaction(coffee(550));

      final reloaded = await freshRepository().getFinanceData();

      expect(reloaded.transactions, hasLength(89));
      expect(reloaded.transactions.any((t) => t.id == 'tx-extra'), isTrue);
      expect(
        FinanceCalculations.monthlyExpenses(reloaded.transactions, now),
        65550,
      );
    });

    test('an updated transaction replaces the stored version', () async {
      await repository.addTransaction(coffee(550));
      await repository.updateTransaction(coffee(1050).copyWith(
        title: 'Coffee & cake',
      ));

      final reloaded = await freshRepository().getFinanceData();
      final updated =
          reloaded.transactions.firstWhere((t) => t.id == 'tx-extra');

      expect(reloaded.transactions, hasLength(89));
      expect(updated.amount, 1050);
      expect(updated.title, 'Coffee & cake');
    });

    test('a deleted transaction disappears from storage', () async {
      await repository.addTransaction(coffee(550));
      await repository.deleteTransaction('tx-extra');

      final reloaded = await freshRepository().getFinanceData();

      expect(reloaded.transactions, hasLength(88));
      expect(reloaded.transactions.any((t) => t.id == 'tx-extra'), isFalse);
    });
  });

  group('budget persistence', () {
    test('upserting a budget replaces the same category', () async {
      await repository.upsertBudget(const Budget(
        id: 'budget-shopping',
        category: 'shopping',
        monthlyLimit: 4000,
      ));

      final reloaded = await freshRepository().getFinanceData();

      expect(reloaded.budgets, hasLength(9));
      final shopping =
          reloaded.budgets.firstWhere((b) => b.category == 'shopping');
      expect(shopping.monthlyLimit, 4000);

      // Raising the limit leaves only transport over budget.
      final spent =
          FinanceCalculations.spentByCategory(reloaded.transactions, now);
      final over = reloaded.budgets
          .where((b) => (spent[b.category] ?? 0) > b.monthlyLimit)
          .map((b) => b.category)
          .toSet();
      expect(over, {'transport'});
    });

    test('a budget can be deleted', () async {
      await repository.deleteBudget('budget-education');

      final reloaded = await freshRepository().getFinanceData();

      expect(reloaded.budgets, hasLength(8));
      expect(
        reloaded.budgets.any((b) => b.id == 'budget-education'),
        isFalse,
      );
    });
  });

  group('goal persistence', () {
    test('goals round-trip through add, update and delete', () async {
      await repository.addGoal(Goal(
        id: 'goal-test',
        title: 'Bicycle',
        targetAmount: 50000,
        savedAmount: 5000,
        targetDate: DateTime(2026, 12, 31),
      ));

      var reloaded = await freshRepository().getFinanceData();
      expect(reloaded.goals, hasLength(5));

      await repository.updateGoal(Goal(
        id: 'goal-test',
        title: 'Bicycle',
        targetAmount: 50000,
        savedAmount: 10000,
        targetDate: DateTime(2026, 12, 31),
      ));

      reloaded = await freshRepository().getFinanceData();
      expect(
        reloaded.goals.firstWhere((g) => g.id == 'goal-test').savedAmount,
        10000,
      );

      await repository.deleteGoal('goal-test');

      reloaded = await freshRepository().getFinanceData();
      expect(reloaded.goals, hasLength(4));
    });
  });

  group('reset and recovery', () {
    test('resetDemoData restores the pristine seed after mutations', () async {
      await repository.addTransaction(Transaction(
        id: 'tx-extra',
        title: 'Coffee',
        amount: 550,
        type: TransactionType.expense,
        category: 'dining',
        date: now,
      ));
      await repository.deleteBudget('budget-education');
      await repository.deleteGoal('goal-travel');

      await repository.resetDemoData();

      final reloaded = await freshRepository().getFinanceData();
      expect(reloaded.transactions, hasLength(88));
      expect(reloaded.budgets, hasLength(9));
      expect(reloaded.goals, hasLength(4));
    });

    test('corrupt persisted JSON falls back to reseeding', () async {
      await repository.getFinanceData(); // seed and persist
      await prefs.setString(AppConstants.prefFinanceData, '{ not json');

      final reloaded = await freshRepository().getFinanceData();

      expect(reloaded.transactions, hasLength(88));
      expect(reloaded.budgets, hasLength(9));
    });
  });
}

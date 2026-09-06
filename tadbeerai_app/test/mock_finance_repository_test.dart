import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/core/constants/app_constants.dart';
import 'package:tadbeerai/data/repositories/mock_finance_repository.dart';
import 'package:tadbeerai/domain/entities/budget.dart';
import 'package:tadbeerai/domain/entities/goal.dart';
import 'package:tadbeerai/domain/entities/transaction.dart';

/// Behavioural tests for the demo-mode finance repository.
///
/// Since the bundled demo seed was dropped (see the Real Finance Backend
/// Migration plan), a fresh repository now starts from an EMPTY ledger rather
/// than the 88-transaction demo dataset. Every CRUD mutation must still
/// survive a fresh instance, which proves the SharedPreferences JSON
/// round-trip; `resetDemoData` now CLEARS instead of re-seeding.
void main() {
  final now = DateTime(2026, 3, 15);

  late SharedPreferences prefs;
  late MockFinanceRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = MockFinanceRepository(prefs);
  });

  /// A brand-new repository over the same storage — simulates an app restart.
  MockFinanceRepository freshRepository() => MockFinanceRepository(prefs);

  group('empty start', () {
    test('first launch starts from an empty ledger (no demo seed)', () async {
      final data = await repository.getFinanceData();

      expect(data.transactions, isEmpty);
      expect(data.budgets, isEmpty);
      expect(data.goals, isEmpty);
      expect(data.openingSavingsBalance, 0);
    });

    test('the empty ledger is persisted to storage', () async {
      await repository.getFinanceData();

      expect(prefs.getString(AppConstants.prefFinanceData), isNotNull);
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

      expect(reloaded.transactions, hasLength(1));
      expect(reloaded.transactions.single.id, 'tx-extra');
      expect(reloaded.transactions.single.amount, 550);
    });

    test('an updated transaction replaces the stored version', () async {
      await repository.addTransaction(coffee(550));
      await repository
          .updateTransaction(coffee(1050).copyWith(title: 'Coffee & cake'));

      final reloaded = await freshRepository().getFinanceData();

      expect(reloaded.transactions, hasLength(1));
      expect(reloaded.transactions.single.amount, 1050);
      expect(reloaded.transactions.single.title, 'Coffee & cake');
    });

    test('a deleted transaction disappears from storage', () async {
      await repository.addTransaction(coffee(550));
      await repository.deleteTransaction('tx-extra');

      final reloaded = await freshRepository().getFinanceData();

      expect(reloaded.transactions, isEmpty);
    });
  });

  group('budget persistence', () {
    test('upserting a budget replaces the same category', () async {
      await repository.upsertBudget(const Budget(
        id: 'budget-shopping',
        category: 'shopping',
        monthlyLimit: 3000,
      ));
      await repository.upsertBudget(const Budget(
        id: 'budget-shopping-v2',
        category: 'shopping',
        monthlyLimit: 4000,
      ));

      final reloaded = await freshRepository().getFinanceData();

      expect(reloaded.budgets, hasLength(1));
      expect(reloaded.budgets.single.category, 'shopping');
      expect(reloaded.budgets.single.monthlyLimit, 4000);
    });

    test('a budget can be deleted', () async {
      await repository.upsertBudget(const Budget(
        id: 'budget-food',
        category: 'food',
        monthlyLimit: 5000,
      ));
      await repository.deleteBudget('budget-food');

      final reloaded = await freshRepository().getFinanceData();

      expect(reloaded.budgets, isEmpty);
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
      expect(reloaded.goals, hasLength(1));

      await repository.updateGoal(Goal(
        id: 'goal-test',
        title: 'Bicycle',
        targetAmount: 50000,
        savedAmount: 10000,
        targetDate: DateTime(2026, 12, 31),
      ));

      reloaded = await freshRepository().getFinanceData();
      expect(reloaded.goals.single.savedAmount, 10000);

      await repository.deleteGoal('goal-test');

      reloaded = await freshRepository().getFinanceData();
      expect(reloaded.goals, isEmpty);
    });
  });

  group('reset and recovery', () {
    test('resetDemoData clears the ledger to empty after mutations', () async {
      await repository.addTransaction(Transaction(
        id: 'tx-extra',
        title: 'Coffee',
        amount: 550,
        type: TransactionType.expense,
        category: 'dining',
        date: now,
      ));
      await repository.upsertBudget(const Budget(
        id: 'budget-food',
        category: 'food',
        monthlyLimit: 5000,
      ));
      await repository.addGoal(Goal(
        id: 'goal-test',
        title: 'Bicycle',
        targetAmount: 50000,
        savedAmount: 0,
        targetDate: DateTime(2026, 12, 31),
      ));

      await repository.resetDemoData();

      final reloaded = await freshRepository().getFinanceData();
      expect(reloaded.transactions, isEmpty);
      expect(reloaded.budgets, isEmpty);
      expect(reloaded.goals, isEmpty);
      expect(reloaded.openingSavingsBalance, 0);
    });

    test('corrupt persisted JSON falls back to an empty ledger', () async {
      await repository.getFinanceData(); // seed and persist
      await prefs.setString(AppConstants.prefFinanceData, '{ not json');

      final reloaded = await freshRepository().getFinanceData();

      expect(reloaded.transactions, isEmpty);
      expect(reloaded.budgets, isEmpty);
      expect(reloaded.goals, isEmpty);
    });
  });
}

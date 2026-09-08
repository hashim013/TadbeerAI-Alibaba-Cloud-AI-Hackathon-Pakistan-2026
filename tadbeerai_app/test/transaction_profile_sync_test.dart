import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/data/repositories/mock_finance_repository.dart';
import 'package:tadbeerai/data/repositories/prefs_financial_profile_repository.dart';
import 'package:tadbeerai/domain/entities/financial_profile.dart';
import 'package:tadbeerai/domain/entities/transaction.dart';
import 'package:tadbeerai/providers/finance_providers.dart';
import 'package:tadbeerai/providers/profile_providers.dart';
import 'package:tadbeerai/providers/repository_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late PrefsFinancialProfileRepository profileRepo;
  late MockFinanceRepository financeRepo;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    profileRepo = PrefsFinancialProfileRepository(prefs);
    financeRepo = MockFinanceRepository(prefs);

    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        financialProfileRepositoryProvider.overrideWithValue(profileRepo),
        financeRepositoryProvider.overrideWithValue(financeRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('FinancialProfileController - Intelligent Transaction Synchronization', () {
    test('adding income transaction increases monthlyIncome and totalSavings in profile',
        () async {
      // 1. Set baseline profile
      const initialProfile = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 100000,
        monthlyEssentialExpenses: 50000,
        totalSavings: 40000,
        profileCompleted: true,
      );
      await container
          .read(financialProfileControllerProvider.notifier)
          .saveProfile(initialProfile);

      // 2. Add an income transaction of 25,000
      final tx = Transaction(
        id: 'tx_inc_1',
        title: 'Freelance Design',
        amount: 25000,
        type: TransactionType.income,
        category: 'income_freelance',
        date: DateTime.now(),
      );

      await container
          .read(financialProfileControllerProvider.notifier)
          .syncWithTransaction(tx);

      final updated = container.read(financialProfileControllerProvider).value;
      expect(updated, isNotNull);
      // Monthly income: 100,000 + 25,000 = 125,000
      expect(updated!.monthlyIncome, 125000);
      // Expenses unchanged: 50,000
      expect(updated.monthlyEssentialExpenses, 50000);
      // Savings stash increased: 40,000 + 25,000 = 65,000
      expect(updated.totalSavings, 65000);
      expect(updated.profileCompleted, isTrue);

      // Verify persisted to repository
      final loadedFromRepo = await profileRepo.loadProfile();
      expect(loadedFromRepo?.monthlyIncome, 125000);
      expect(loadedFromRepo?.totalSavings, 65000);
    });

    test(
        'adding expense transaction increases monthlyEssentialExpenses and draws down totalSavings',
        () async {
      const initialProfile = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 120000,
        monthlyEssentialExpenses: 40000,
        totalSavings: 50000,
        profileCompleted: true,
      );
      await container
          .read(financialProfileControllerProvider.notifier)
          .saveProfile(initialProfile);

      final tx = Transaction(
        id: 'tx_exp_1',
        title: 'Grocery Bill',
        amount: 15000,
        type: TransactionType.expense,
        category: 'food',
        date: DateTime.now(),
      );

      await container
          .read(financialProfileControllerProvider.notifier)
          .syncWithTransaction(tx);

      final updated = container.read(financialProfileControllerProvider).value;
      expect(updated, isNotNull);
      // Income unchanged: 120,000
      expect(updated!.monthlyIncome, 120000);
      // Monthly expenses: 40,000 + 15,000 = 55,000
      expect(updated.monthlyEssentialExpenses, 55000);
      // Total savings drawn down: 50,000 - 15,000 = 35,000
      expect(updated.totalSavings, 35000);
    });

    test('reversing/deleting income transaction subtracts from income and savings',
        () async {
      const profile = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 150000,
        monthlyEssentialExpenses: 60000,
        totalSavings: 70000,
        profileCompleted: true,
      );
      await container
          .read(financialProfileControllerProvider.notifier)
          .saveProfile(profile);

      final tx = Transaction(
        id: 'tx_inc_to_delete',
        title: 'Bonus',
        amount: 30000,
        type: TransactionType.income,
        category: 'salary',
        date: DateTime.now(),
      );

      await container
          .read(financialProfileControllerProvider.notifier)
          .syncWithTransaction(tx, isReversal: true);

      final updated = container.read(financialProfileControllerProvider).value;
      expect(updated!.monthlyIncome, 120000);
      expect(updated.totalSavings, 40000);
      expect(updated.monthlyEssentialExpenses, 60000);
    });

    test(
        'reversing/deleting expense transaction subtracts from expenses and refunds savings',
        () async {
      const profile = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 100000,
        monthlyEssentialExpenses: 70000,
        totalSavings: 20000,
        profileCompleted: true,
      );
      await container
          .read(financialProfileControllerProvider.notifier)
          .saveProfile(profile);

      final tx = Transaction(
        id: 'tx_exp_refunded',
        title: 'Cancelled Subscription',
        amount: 10000,
        type: TransactionType.expense,
        category: 'entertainment',
        date: DateTime.now(),
      );

      await container
          .read(financialProfileControllerProvider.notifier)
          .syncWithTransaction(tx, isReversal: true);

      final updated = container.read(financialProfileControllerProvider).value;
      // Expenses reduced: 70,000 - 10,000 = 60,000
      expect(updated!.monthlyEssentialExpenses, 60000);
      // Savings restored: 20,000 + 10,000 = 30,000
      expect(updated.totalSavings, 30000);
    });

    test('updating transaction applies delta between old and new transaction',
        () async {
      const profile = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 100000,
        monthlyEssentialExpenses: 50000,
        totalSavings: 30000,
        profileCompleted: true,
      );
      await container
          .read(financialProfileControllerProvider.notifier)
          .saveProfile(profile);

      final oldTx = Transaction(
        id: 'tx_1',
        title: 'Electricity Bill',
        amount: 8000,
        type: TransactionType.expense,
        category: 'utilities',
        date: DateTime.now(),
      );
      final newTx = Transaction(
        id: 'tx_1',
        title: 'Electricity Bill Corrected',
        amount: 12000,
        type: TransactionType.expense,
        category: 'utilities',
        date: DateTime.now(),
      );

      await container
          .read(financialProfileControllerProvider.notifier)
          .syncTransactionUpdate(oldTransaction: oldTx, newTransaction: newTx);

      final updated = container.read(financialProfileControllerProvider).value;
      // Net change: expenses +4,000 (from 50,000 -> 54,000)
      expect(updated!.monthlyEssentialExpenses, 54000);
      // Net change: savings -4,000 (from 30,000 -> 26,000)
      expect(updated.totalSavings, 26000);
    });

    test('syncing transaction when profile is null initializes a baseline profile',
        () async {
      // Ensure no profile exists
      await container
          .read(financialProfileControllerProvider.notifier)
          .clearProfile();

      final tx = Transaction(
        id: 'tx_first',
        title: 'First Freelance Payment',
        amount: 45000,
        type: TransactionType.income,
        category: 'income_freelance',
        date: DateTime.now(),
      );

      await container
          .read(financialProfileControllerProvider.notifier)
          .syncWithTransaction(tx);

      final updated = container.read(financialProfileControllerProvider).value;
      expect(updated, isNotNull);
      expect(updated!.monthlyIncome, 45000);
      expect(updated.monthlyEssentialExpenses, 0);
      expect(updated.totalSavings, 45000);
      expect(updated.profileCompleted, isFalse);
    });
  });

  group('FinanceController Integration - Ledger to Profile Auto-Sync', () {
    test(
        'calling FinanceController.addTransaction automatically updates profile and health score',
        () async {
      // Initial state: profile completed with 100,000 income, 50,000 expenses, 40,000 savings
      const profile = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 100000,
        monthlyEssentialExpenses: 50000,
        totalSavings: 40000,
        profileCompleted: true,
      );
      await container
          .read(financialProfileControllerProvider.notifier)
          .saveProfile(profile);

      // Wait for FinanceController to build
      await container.read(financeControllerProvider.future);

      // Add transaction via FinanceController
      final newTx = Transaction(
        id: 'tx_ledger_1',
        title: 'Bonus Check',
        amount: 20000,
        type: TransactionType.income,
        category: 'salary',
        date: DateTime.now(),
      );

      await container
          .read(financeControllerProvider.notifier)
          .addTransaction(newTx);

      // Verify transaction added to FinanceController state
      final financeData = container.read(financeControllerProvider).value;
      expect(financeData?.transactions.any((t) => t.id == 'tx_ledger_1'), isTrue);

      // Verify profile was automatically updated
      final updatedProfile =
          container.read(financialProfileControllerProvider).value;
      expect(updatedProfile?.monthlyIncome, 120000);
      expect(updatedProfile?.totalSavings, 60000);

      // Verify health score recalculates using the updated figures
      final health = container.read(financialHealthProvider);
      expect(health, isNotNull);
      expect(health!.score, isNonNegative);
    });

    test('calling FinanceController.deleteTransaction reverses profile impacts',
        () async {
      const profile = FinancialProfile(
        persona: Persona.salaried,
        monthlyIncome: 100000,
        monthlyEssentialExpenses: 50000,
        totalSavings: 50000,
        profileCompleted: true,
      );
      await container
          .read(financialProfileControllerProvider.notifier)
          .saveProfile(profile);

      await container.read(financeControllerProvider.future);

      // Add an expense
      final expenseTx = Transaction(
        id: 'tx_exp_del',
        title: 'Extra Flight Ticket',
        amount: 30000,
        type: TransactionType.expense,
        category: 'transport',
        date: DateTime.now(),
      );
      await container
          .read(financeControllerProvider.notifier)
          .addTransaction(expenseTx);

      expect(
        container
            .read(financialProfileControllerProvider)
            .value
            ?.monthlyEssentialExpenses,
        80000,
      );

      // Delete the expense
      await container
          .read(financeControllerProvider.notifier)
          .deleteTransaction('tx_exp_del');

      // Profile should be restored back to 50,000 expenses
      final restoredProfile =
          container.read(financialProfileControllerProvider).value;
      expect(restoredProfile?.monthlyEssentialExpenses, 50000);
      expect(restoredProfile?.totalSavings, 50000);
    });
  });
}

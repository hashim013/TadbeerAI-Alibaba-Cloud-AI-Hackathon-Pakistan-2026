import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tadbeerai/domain/entities/budget.dart';
import 'package:tadbeerai/domain/entities/finance_data.dart';
import 'package:tadbeerai/domain/entities/financial_profile.dart';
import 'package:tadbeerai/domain/entities/goal.dart';
import 'package:tadbeerai/domain/entities/transaction.dart';
import 'package:tadbeerai/domain/repositories/finance_repository.dart';
import 'package:tadbeerai/domain/repositories/financial_profile_repository.dart';
import 'package:tadbeerai/domain/services/financial_health_calculator.dart';
import 'package:tadbeerai/features/finance/budget_screen.dart';
import 'package:tadbeerai/features/finance/expenses_screen.dart';
import 'package:tadbeerai/features/finance/financial_health_screen.dart';
import 'package:tadbeerai/features/finance/finance_overview_screen.dart';
import 'package:tadbeerai/features/finance/goals_screen.dart';
import 'package:tadbeerai/features/finance/my_finances_screen.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/finance_providers.dart';
import 'package:tadbeerai/providers/repository_providers.dart';

class _FakeFinanceRepo implements FinanceRepository {
  _FakeFinanceRepo(this.data);
  FinanceData data;

  @override
  Future<FinanceData> getFinanceData() async => data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileRepo implements FinancialProfileRepository {
  _FakeProfileRepo(this.profile);
  FinancialProfile? profile;

  @override
  Future<FinancialProfile?> loadProfile() async => profile;

  @override
  Future<void> saveProfile(FinancialProfile p) async {
    profile = p;
  }

  @override
  Future<void> clearProfile() async {
    profile = null;
  }
}

void main() {
  group('FinancialProfile & Health Entity Linkage', () {
    test('FinancialProfile serializes and deserializes financialHealthScore',
        () {
      const profile = FinancialProfile(
        persona: Persona.salaried,
        primaryGoal: PrimaryGoal.emergencyFund,
        monthlyIncome: 150000,
        monthlyEssentialExpenses: 60000,
        totalSavings: 200000,
        financialHealthScore: 82,
        profileCompleted: true,
      );

      final json = profile.toJson();
      expect(json['financialHealthScore'], 82);

      final decoded = FinancialProfile.fromJson(json);
      expect(decoded.financialHealthScore, 82);
      expect(decoded.persona, Persona.salaried);
      expect(decoded.primaryGoal, PrimaryGoal.emergencyFund);
      expect(decoded.monthlyIncome, 150000);
      expect(decoded.totalSavings, 200000);

      // Verify backend snake_case parsing
      final fromBackend = FinancialProfile.fromJson({
        'persona': 'salaried',
        'primary_goal': 'emergencyFund',
        'monthly_income': 150000,
        'monthly_essential_expenses': 60000,
        'total_savings': 200000,
        'financial_health_score': 82,
        'profile_completed': true,
      });
      expect(fromBackend.financialHealthScore, 82);
      expect(fromBackend.monthlyIncome, 150000);

      final updated = profile.copyWith(financialHealthScore: 88);
      expect(updated.financialHealthScore, 88);
      expect(updated == profile, isFalse);
    });

    test('FinancialHealthResult component helper getters return exact pillars',
        () {
      const input = FinancialHealthInput(
        monthlyIncome: 100000,
        monthlyExpenses: 50000,
        savingsBalance: 150000,
        discretionarySpending: 15000,
        budgets: [],
        spentByCategory: {},
        goals: [],
      );

      final result = FinancialHealthCalculator.calculate(input);
      expect(result.savingsComponent, isNotNull);
      expect(result.savingsComponent!.key, 'savings');
      expect(result.budgetComponent, isNotNull);
      expect(result.budgetComponent!.key, 'budget');
      expect(result.emergencyComponent, isNotNull);
      expect(result.emergencyComponent!.key, 'emergency');
      expect(result.goalsComponent, isNotNull);
      expect(result.goalsComponent!.key, 'goals');
      expect(result.spendingComponent, isNotNull);
      expect(result.spendingComponent!.key, 'spending');
    });
  });

  group('Feature Screen Linkages with Health & Profile', () {
    late DateTime now;
    late FinanceData testFinanceData;
    late FinancialProfile testProfile;

    setUp(() {
      now = DateTime.now();
      testFinanceData = FinanceData(
        transactions: [
          Transaction(
            id: 't1',
            title: 'Monthly Salary',
            amount: 120000,
            category: 'salary',
            date: now,
            type: TransactionType.income,
          ),
          Transaction(
            id: 't2',
            title: 'Apartment Rent',
            amount: 40000,
            category: 'housing',
            date: now,
            type: TransactionType.expense,
          ),
        ],
        budgets: const [
          Budget(
            id: 'b1',
            category: 'housing',
            monthlyLimit: 45000,
          ),
        ],
        goals: [
          Goal(
            id: 'g1',
            title: 'Emergency Fund',
            targetAmount: 300000,
            savedAmount: 150000,
            targetDate: now.add(const Duration(days: 120)),
          ),
        ],
        openingSavingsBalance: 150000,
      );

      testProfile = const FinancialProfile(
        persona: Persona.salaried,
        primaryGoal: PrimaryGoal.emergencyFund,
        monthlyIncome: 120000,
        monthlyEssentialExpenses: 40000,
        totalSavings: 150000,
        financialHealthScore: 75,
        profileCompleted: true,
      );
    });

    testWidgets(
        'MyFinancesScreen renders Health & Profile banner card with links',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/finance/finances',
        routes: [
          GoRoute(
            path: '/finance/finances',
            builder: (context, state) => const MyFinancesScreen(),
          ),
          GoRoute(
            path: '/finance/health',
            builder: (context, state) =>
                const Scaffold(body: Text('Health Screen Target')),
          ),
          GoRoute(
            path: '/profile/financial',
            builder: (context, state) =>
                const Scaffold(body: Text('Profile Target')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeRepositoryProvider
                .overrideWithValue(_FakeFinanceRepo(testFinanceData)),
            financialProfileRepositoryProvider
                .overrideWithValue(_FakeProfileRepo(testProfile)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify health rating & persona pill
      expect(find.text('Salaried Professional'), findsOneWidget);
      expect(find.text('View Health Pillars'), findsOneWidget);
      expect(find.text('Profile Baseline'), findsOneWidget);

      // Verify tapping 'View Health Pillars' navigates
      await tester.tap(find.text('View Health Pillars'));
      await tester.pumpAndSettle();
      expect(find.text('Health Screen Target'), findsOneWidget);
    });

    testWidgets(
        'BudgetScreen displays Budget Discipline Pillar (25% Weight) and profile baseline',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/finance/budget',
        routes: [
          GoRoute(
            path: '/finance/budget',
            builder: (context, state) => const BudgetScreen(),
          ),
          GoRoute(
            path: '/finance/health',
            builder: (context, state) =>
                const Scaffold(body: Text('Health Target')),
          ),
          GoRoute(
            path: '/profile/financial',
            builder: (context, state) =>
                const Scaffold(body: Text('Profile Target')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeRepositoryProvider
                .overrideWithValue(_FakeFinanceRepo(testFinanceData)),
            financialProfileRepositoryProvider
                .overrideWithValue(_FakeProfileRepo(testProfile)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Budget Discipline Pillar'), findsOneWidget);
      expect(find.text('25% Weight'), findsOneWidget);
      expect(find.textContaining('Profile Essential Expenses Baseline'),
          findsOneWidget);
      expect(find.text('View Health Impact'), findsOneWidget);

      await tester.tap(find.text('View Health Impact'));
      await tester.pumpAndSettle();
      expect(find.text('Health Target'), findsOneWidget);
    });

    testWidgets(
        'GoalsScreen displays Goal Progress Pillar (15% Weight) and badges Persona Goal',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/finance/goals',
        routes: [
          GoRoute(
            path: '/finance/goals',
            builder: (context, state) => const GoalsScreen(),
          ),
          GoRoute(
            path: '/finance/health',
            builder: (context, state) =>
                const Scaffold(body: Text('Health Target')),
          ),
          GoRoute(
            path: '/profile/financial',
            builder: (context, state) =>
                const Scaffold(body: Text('Profile Target')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeRepositoryProvider
                .overrideWithValue(_FakeFinanceRepo(testFinanceData)),
            financialProfileRepositoryProvider
                .overrideWithValue(_FakeProfileRepo(testProfile)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Goal Progress Pillar'), findsOneWidget);
      expect(find.text('15% Weight'), findsOneWidget);
      expect(
          find.text('Persona Primary Focus: Emergency Fund'), findsOneWidget);
      expect(find.text('⭐ Persona Goal'), findsOneWidget);
    });

    testWidgets(
        'ExpensesScreen displays Spending Pace banner with profile baseline',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/finance/expenses',
        routes: [
          GoRoute(
            path: '/finance/expenses',
            builder: (context, state) => const ExpensesScreen(),
          ),
          GoRoute(
            path: '/finance/health',
            builder: (context, state) =>
                const Scaffold(body: Text('Health Target')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeRepositoryProvider
                .overrideWithValue(_FakeFinanceRepo(testFinanceData)),
            financialProfileRepositoryProvider
                .overrideWithValue(_FakeProfileRepo(testProfile)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Spending Pace & Discipline'), findsOneWidget);
      expect(find.textContaining('spent of'), findsOneWidget);
      expect(find.text('Health'), findsOneWidget);

      await tester.tap(find.text('Health'));
      await tester.pumpAndSettle();
      expect(find.text('Health Target'), findsOneWidget);
    });

    testWidgets('FinancialHealthScreen expanded pillar routes to tool',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/finance/health',
        routes: [
          GoRoute(
            path: '/finance/health',
            builder: (context, state) => const FinancialHealthScreen(),
          ),
          GoRoute(
            path: '/finance/budget',
            builder: (context, state) =>
                const Scaffold(body: Text('Budget Planner Target')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeRepositoryProvider
                .overrideWithValue(_FakeFinanceRepo(testFinanceData)),
            financialProfileRepositoryProvider
                .overrideWithValue(_FakeProfileRepo(testProfile)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Tap 'Budget Discipline' pillar card to expand it
      await tester.tap(find.text('Budget Discipline'));
      await tester.pumpAndSettle();

      // Verify the direct action button appears
      expect(find.text('Open Budget Planner'), findsOneWidget);

      // Tap action button and verify navigation to Budget Planner
      await tester.tap(find.text('Open Budget Planner'));
      await tester.pumpAndSettle();
      expect(find.text('Budget Planner Target'), findsOneWidget);
    });

    testWidgets(
        'FinanceOverviewScreen renders professional fintech hub with health scorecard, cash flow, and 4 live tool cards',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/finance',
        routes: [
          GoRoute(
            path: '/finance',
            builder: (context, state) => const FinanceOverviewScreen(),
          ),
          GoRoute(
            path: '/finance/health',
            builder: (context, state) =>
                const Scaffold(body: Text('Health Target')),
          ),
          GoRoute(
            path: '/finance/finances',
            builder: (context, state) =>
                const Scaffold(body: Text('Finances Target')),
          ),
          GoRoute(
            path: '/finance/expenses',
            builder: (context, state) =>
                const Scaffold(body: Text('Expenses Target')),
          ),
          GoRoute(
            path: '/finance/budget',
            builder: (context, state) =>
                const Scaffold(body: Text('Budget Target')),
          ),
          GoRoute(
            path: '/finance/goals',
            builder: (context, state) =>
                const Scaffold(body: Text('Goals Target')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeRepositoryProvider
                .overrideWithValue(_FakeFinanceRepo(testFinanceData)),
            financialProfileRepositoryProvider
                .overrideWithValue(_FakeProfileRepo(testProfile)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // 1. Header & Persona
      expect(find.text('Finance Hub'), findsOneWidget);
      expect(find.text('Salaried Pro'), findsOneWidget);

      // 2. Financial Health Scorecard & Micro-Pillars
      expect(find.text('Savings'), findsOneWidget);
      expect(find.text('Discipline'), findsOneWidget);
      expect(find.text('Buffer'), findsOneWidget);
      expect(find.text('5-Pillar Health & Solvency Index'), findsOneWidget);

      // 3. Monthly Cash Flow Snapshot (Zero Duplication)
      expect(find.text('Monthly Cash Flow'), findsOneWidget);
      expect(find.text('Inflow'), findsOneWidget);
      expect(find.text('Outflow'), findsOneWidget);
      expect(find.text('Net Monthly Surplus'), findsOneWidget);

      // 4. Live Tool Cards
      expect(find.text('My Finances'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Budget Planner'), findsOneWidget);
      expect(find.text('Goals'), findsOneWidget);

      // 5. Recent Activity
      expect(find.text('Recent Activity'), findsOneWidget);
      expect(find.text('Monthly Salary'), findsOneWidget);

      // Test navigation to My Finances
      await tester.tap(find.text('My Finances'));
      await tester.pumpAndSettle();
      expect(find.text('Finances Target'), findsOneWidget);
    });
  });
}

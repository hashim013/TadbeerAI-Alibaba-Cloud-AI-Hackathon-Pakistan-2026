import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tadbeerai/domain/entities/budget.dart';
import 'package:tadbeerai/domain/entities/finance_data.dart';
import 'package:tadbeerai/domain/entities/goal.dart';
import 'package:tadbeerai/domain/entities/transaction.dart';
import 'package:tadbeerai/domain/repositories/finance_repository.dart';
import 'package:tadbeerai/features/finance/financial_health_screen.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/finance_providers.dart';

class _TestFinanceRepo implements FinanceRepository {
  const _TestFinanceRepo(this.data);
  final FinanceData data;

  @override
  Future<FinanceData> getFinanceData() async => data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'FinancialHealthScreen renders calibrated gauge, metric strip, 5 pillars, and copilot dock',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final testData = FinanceData(
      transactions: [
        Transaction(
          id: '1',
          title: 'Salary',
          amount: 100000,
          category: 'salary',
          date: now,
          type: TransactionType.income,
        ),
        Transaction(
          id: '2',
          title: 'Rent',
          amount: 30000,
          category: 'rent',
          date: now,
          type: TransactionType.expense,
        ),
        Transaction(
          id: '3',
          title: 'Groceries',
          amount: 20000,
          category: 'groceries',
          date: now,
          type: TransactionType.expense,
        ),
        Transaction(
          id: '4',
          title: 'Dining',
          amount: 10000,
          category: 'dining',
          date: now,
          type: TransactionType.expense,
        ),
      ],
      budgets: const [
        Budget(
          id: 'b1',
          category: 'groceries',
          monthlyLimit: 25000,
        ),
        Budget(
          id: 'b2',
          category: 'dining',
          monthlyLimit: 15000,
        ),
      ],
      goals: [
        Goal(
          id: 'g1',
          title: 'Emergency Fund',
          targetAmount: 200000,
          savedAmount: 120000,
          targetDate: now.add(const Duration(days: 180)),
        ),
      ],
      openingSavingsBalance: 120000,
    );

    final router = GoRouter(
      initialLocation: '/finance/health',
      routes: [
        GoRoute(
          path: '/finance/health',
          builder: (context, state) => const FinancialHealthScreen(),
        ),
        GoRoute(
          path: '/ask',
          builder: (context, state) =>
              const Scaffold(body: Text('Ask Tadbeer Screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeRepositoryProvider
              .overrideWithValue(_TestFinanceRepo(testData)),
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

    // 1. Verify AppBar Title
    expect(find.text('Financial Health'), findsOneWidget);

    // 2. Verify Calibrated HealthScoreGauge
    expect(find.byType(HealthScoreGauge), findsOneWidget);
    expect(find.textContaining('/100'), findsWidgets);

    // 3. Verify 3-Stat Metric Strip
    expect(find.text('Savings Rate'), findsOneWidget);
    expect(find.text('Emergency'), findsOneWidget);
    expect(find.text('Budgets'), findsOneWidget);

    // 4. Verify Resilience Pillars Header
    expect(find.text('RESILIENCE PILLARS'), findsOneWidget);
    expect(find.text('100% Deterministic'), findsOneWidget);

    // 5. Verify Core Pillars exist
    expect(find.text('Savings Behavior'), findsOneWidget);
    expect(find.text('Budget Discipline'), findsOneWidget);
    expect(find.text('Emergency Cushion'), findsOneWidget);
    expect(find.text('Goal Progress'), findsOneWidget);
    expect(find.text('Spending Discipline'), findsOneWidget);

    // 6. Verify Executive Copilot Dock
    expect(find.text('Improve My Score with AI'), findsOneWidget);

    // 7. Tap Copilot Dock and verify navigation to /ask
    await tester.tap(find.text('Improve My Score with AI'));
    await tester.pumpAndSettle();
    expect(find.text('Ask Tadbeer Screen'), findsOneWidget);
  });

  testWidgets(
      'Tapping a resilience pillar expands deep dive and actionable tip',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final testData = FinanceData(
      transactions: [
        Transaction(
          id: '1',
          title: 'Salary',
          amount: 80000,
          category: 'salary',
          date: now,
          type: TransactionType.income,
        ),
      ],
      budgets: const [],
      goals: const [],
      openingSavingsBalance: 50000,
    );

    final router = GoRouter(
      initialLocation: '/finance/health',
      routes: [
        GoRoute(
          path: '/finance/health',
          builder: (context, state) => const FinancialHealthScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeRepositoryProvider
              .overrideWithValue(_TestFinanceRepo(testData)),
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

    // Tap 'Savings Behavior' card
    await tester.tap(find.text('Savings Behavior'));
    await tester.pumpAndSettle();

    // Verify Weight badge is visible (Weight: 25%)
    expect(find.textContaining('Weight: 25%'), findsOneWidget);
  });
}

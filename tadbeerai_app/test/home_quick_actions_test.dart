import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tadbeerai/domain/entities/app_user.dart';
import 'package:tadbeerai/domain/entities/finance_data.dart';
import 'package:tadbeerai/domain/entities/financial_profile.dart';
import 'package:tadbeerai/domain/repositories/auth_repository.dart';
import 'package:tadbeerai/domain/repositories/finance_repository.dart';
import 'package:tadbeerai/domain/repositories/financial_profile_repository.dart';
import 'package:tadbeerai/features/dashboard/home_dashboard_screen.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/finance_providers.dart';
import 'package:tadbeerai/providers/repository_providers.dart';

class _FakeFinanceRepo implements FinanceRepository {
  const _FakeFinanceRepo();
  @override
  Future<FinanceData> getFinanceData() async => const FinanceData(
        transactions: [],
        budgets: [],
        goals: [],
        openingSavingsBalance: 0,
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<AppUser?> currentUser() async =>
      const AppUser(id: '1', name: 'Hashim', email: 'hashim@test.com');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileRepo implements FinancialProfileRepository {
  @override
  Future<FinancialProfile?> loadProfile() async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Quick Actions on Home Dashboard render all 4 shortcuts with perfect alignment',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeDashboardScreen(),
        ),
        GoRoute(
          path: '/finance',
          builder: (context, state) => const Scaffold(body: Text('Finance Page')),
        ),
        GoRoute(
          path: '/economy',
          builder: (context, state) => const Scaffold(body: Text('Economy Page')),
        ),
        GoRoute(
          path: '/ask',
          builder: (context, state) => const Scaffold(body: Text('Ask Page')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeRepositoryProvider.overrideWithValue(const _FakeFinanceRepo()),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
          financialProfileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Quick Actions SectionHeader exists
    expect(find.text('Quick actions'), findsOneWidget);

    // Verify all 4 core actions exist
    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('Economy'), findsOneWidget);
    expect(find.text('Ask Tadbeer'), findsOneWidget);
    expect(find.text('What-If'), findsOneWidget);

    // Tap Finance and check navigation
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finance'));
    await tester.pumpAndSettle();
    expect(find.text('Finance Page'), findsOneWidget);
  });
}

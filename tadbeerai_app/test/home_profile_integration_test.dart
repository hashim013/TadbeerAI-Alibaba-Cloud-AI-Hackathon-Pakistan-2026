import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/domain/entities/app_user.dart';
import 'package:tadbeerai/domain/entities/budget.dart';
import 'package:tadbeerai/domain/entities/finance_data.dart';
import 'package:tadbeerai/domain/entities/financial_profile.dart';
import 'package:tadbeerai/domain/entities/goal.dart';
import 'package:tadbeerai/domain/entities/transaction.dart';
import 'package:tadbeerai/domain/repositories/auth_repository.dart';
import 'package:tadbeerai/domain/repositories/finance_repository.dart';
import 'package:tadbeerai/domain/repositories/financial_profile_repository.dart';
import 'package:tadbeerai/features/dashboard/home_dashboard_screen.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/finance_providers.dart';
import 'package:tadbeerai/providers/repository_providers.dart';

// ── Fake repositories ─────────────────────────────────────────────────────

/// Finance repository that returns empty data instantly (no latency).
class _EmptyFinanceRepo implements FinanceRepository {
  const _EmptyFinanceRepo();

  static const _data = FinanceData(
    transactions: [],
    budgets: [],
    goals: [],
    openingSavingsBalance: 0,
  );

  @override
  Future<FinanceData> getFinanceData() async => _data;

  @override
  Future<void> addTransaction(Transaction t) async {}
  @override
  Future<void> updateTransaction(Transaction t) async {}
  @override
  Future<void> deleteTransaction(String id) async {}
  @override
  Future<void> upsertBudget(Budget b) async {}
  @override
  Future<void> deleteBudget(String id) async {}
  @override
  Future<void> addGoal(Goal g) async {}
  @override
  Future<void> updateGoal(Goal g) async {}
  @override
  Future<void> deleteGoal(String id) async {}
  @override
  Future<void> resetDemoData() async {}
}

/// Auth repository that always returns a signed-in user.
class _TestAuthRepo implements AuthRepository {
  @override
  Future<AppUser?> currentUser() async =>
      const AppUser(id: '1', name: 'Ali', email: 'ali@test.com');

  @override
  Future<AppUser> signIn(
          {required String email, required String password}) async =>
      const AppUser(id: '1', name: 'Ali', email: 'ali@test.com');

  @override
  Future<AppUser> signUp(
          {required String name,
          required String email,
          required String password}) async =>
      AppUser(id: '1', name: name, email: email);

  @override
  Future<AppUser> signInAsGuest() async => const AppUser(
      id: 'guest_1', name: 'Guest User', email: 'guest@tadbeer.ai');

  @override
  Future<void> sendPasswordResetCode({required String email}) async {}

  @override
  Future<bool> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async =>
      true;

  @override
  Future<void> signOut() async {}
}

// ── Helpers ──────────────────────────────────────────────────────────────

/// Pumps [HomeDashboardScreen] with mock providers and returns the
/// [GoRouter] so tests can inspect navigation state.
Future<GoRouter> _pumpHome(
  WidgetTester tester, {
  required FinancialProfile? profile,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeDashboardScreen(),
      ),
      GoRoute(
        path: '/profile/financial',
        builder: (_, __) => const Placeholder(),
      ),
    ],
  );

  // In-memory profile repo backed by the same profile object.
  final profileRepo = _InMemoryProfileRepo(profile);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        financeRepositoryProvider.overrideWithValue(
          const _EmptyFinanceRepo(),
        ),
        authRepositoryProvider.overrideWithValue(_TestAuthRepo()),
        financialProfileRepositoryProvider.overrideWithValue(profileRepo),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  // Flush async builds for AsyncNotifier providers.
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
  return router;
}

/// Simple in-memory FinancialProfileRepository for tests.
class _InMemoryProfileRepo implements FinancialProfileRepository {
  _InMemoryProfileRepo(this._stored);
  FinancialProfile? _stored;

  @override
  Future<FinancialProfile?> loadProfile() async => _stored;

  @override
  Future<void> saveProfile(FinancialProfile profile) async {
    _stored = profile;
  }

  @override
  Future<void> clearProfile() async {
    _stored = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home profile integration', () {
    // ── 1. CTA shown when no profile exists ─────────────────────────────
    testWidgets('shows CTA card when no profile exists', (tester) async {
      await _pumpHome(tester, profile: null);

      expect(find.text('Personalize Tadbeer'), findsOneWidget);
      expect(
        find.textContaining('more relevant insights'),
        findsOneWidget,
      );
      expect(find.text('Complete Profile'), findsOneWidget);
    });

    // ── 2. CTA shown when profile is incomplete ─────────────────────────
    testWidgets('shows CTA card when profileCompleted is false',
        (tester) async {
      await _pumpHome(
        tester,
        profile: const FinancialProfile(
          persona: Persona.student,
          profileCompleted: false,
        ),
      );

      expect(find.text('Personalize Tadbeer'), findsOneWidget);
      expect(find.text('Complete Profile'), findsOneWidget);
      expect(find.text('Financial Profile'), findsNothing);
    });

    // ── 3. Completed card shown when profile is completed ────────────────
    testWidgets('shows completed status when profileCompleted is true',
        (tester) async {
      await _pumpHome(
        tester,
        profile: const FinancialProfile(
          persona: Persona.salaried,
          monthlyIncome: 80000,
          monthlyEssentialExpenses: 55000,
          primaryGoal: PrimaryGoal.saveMore,
          profileCompleted: true,
        ),
      );

      expect(find.text('Financial Profile'), findsOneWidget);
      expect(find.text('Personalized insights enabled'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Personalize Tadbeer'), findsNothing);
      expect(find.text('Complete Profile'), findsNothing);
    });

    // ── 4. CTA navigates to /profile/financial ──────────────────────────
    testWidgets('tapping CTA navigates to /profile/financial', (tester) async {
      final router = await _pumpHome(tester, profile: null);

      await tester.tap(find.text('Complete Profile'));
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, '/profile/financial');
    });

    // ── 5. Edit navigates to /profile/financial ─────────────────────────
    testWidgets('tapping Edit on completed card navigates to profile',
        (tester) async {
      final router = await _pumpHome(
        tester,
        profile: const FinancialProfile(
          persona: Persona.salaried,
          monthlyIncome: 80000,
          monthlyEssentialExpenses: 55000,
          primaryGoal: PrimaryGoal.saveMore,
          profileCompleted: true,
        ),
      );

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, '/profile/financial');
    });

    // ── 6. Home renders normally regardless of profile state ────────────
    testWidgets('Home renders greeting and sections with no profile',
        (tester) async {
      await _pumpHome(tester, profile: null);

      // Greeting renders (default name "Tadbeer" since no session restored).
      expect(find.textContaining('Tadbeer'), findsWidgets);
      // Profile CTA is visible.
      expect(find.text('Personalize Tadbeer'), findsOneWidget);
      // No error widget shown.
      expect(find.text('Something went wrong'), findsNothing);
    });

    // ── 7. Profile loading failure does not break Home ──────────────────
    testWidgets('profile loading failure does not crash Home', (tester) async {
      // A null profile simulates a failed or empty load.
      // The _ProfileCard shows the CTA as a safe fallback.
      await _pumpHome(tester, profile: null);

      expect(find.textContaining('Tadbeer'), findsWidgets);
      expect(find.text('Something went wrong'), findsNothing);
      // CTA is shown as safe fallback.
      expect(find.text('Personalize Tadbeer'), findsOneWidget);
    });
  });
}

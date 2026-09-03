import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/core/theme/app_theme.dart';
import 'package:tadbeerai/features/onboarding/onboarding_screen.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/repository_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpOnboarding(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('LOGIN')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('OnboardingScreen navigates across 3 pages and reaches login',
      (tester) async {
    await pumpOnboarding(tester);

    // Page 0: Understand
    expect(find.text('Understand'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(
      find.text(
          "Understand Pakistan's economy, financial trends and what's happening around you."),
      findsOneWidget,
    );

    // Tap Next -> Page 1: Manage
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Manage'), findsOneWidget);
    expect(
      find.text(
          'Track income and expenses, create budgets, build savings and achieve your financial goals.'),
      findsOneWidget,
    );

    // Tap Next -> Page 2: Plan
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(
      find.text(
          'Simulate different scenarios, get AI insights and plan your financial future with confidence.'),
      findsOneWidget,
    );

    // Tap Get Started -> Routes to /login
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('OnboardingScreen Skip button immediately navigates to login',
      (tester) async {
    await pumpOnboarding(tester);

    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN'), findsOneWidget);
  });
}

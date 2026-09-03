import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/core/constants/app_constants.dart';
import 'package:tadbeerai/core/theme/app_theme.dart';
import 'package:tadbeerai/features/splash/splash_screen.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/repository_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SplashScreen renders all branding, typography, and indicator widgets',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefOnboardingComplete: true,
    });
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const Scaffold(body: Text('ONBOARDING')),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('LOGIN')),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('HOME')),
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

    // Initial pump to allow delayed fade-in animations to present
    await tester.pump(const Duration(milliseconds: 800));

    // Verify Brand title
    expect(find.text('TADBEER'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);

    // Verify Primary subtitle
    expect(
      find.textContaining('Financial Intelligence'),
      findsOneWidget,
    );

    // Verify Logo Image asset
    expect(find.byType(Image), findsOneWidget);

    // Verify CustomPaint for particle mesh
    expect(find.byType(CustomPaint), findsWidgets);

    // Complete the splash delay timer
    await tester.pump(AppConstants.splashDuration + const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Verify navigation reached /onboarding for testing
    expect(find.text('ONBOARDING'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/core/router/app_router.dart';
import 'package:tadbeerai/core/theme/app_theme.dart';
import 'package:tadbeerai/features/auth/login_screen.dart';
import 'package:tadbeerai/features/auth/signup_screen.dart';
import 'package:tadbeerai/features/shell/main_shell.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/repository_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app router contains custom smooth animated transitions',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to /login
    router.go('/login');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    // Navigate to /signup and verify smooth transition builds
    router.go('/signup');
    await tester.pump();
    // Mid-transition frame
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.byType(SlideTransition), findsWidgets);
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);

    // Navigate to /home (inside MainShell)
    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byType(MainShell), findsOneWidget);

    // Switch tab to /finance
    router.go('/finance');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FadeTransition), findsWidgets);
    await tester.pumpAndSettle();

    // Push detail sub-route /finance/health
    router.push('/finance/health');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SlideTransition), findsWidgets);
    await tester.pumpAndSettle();
  });
}

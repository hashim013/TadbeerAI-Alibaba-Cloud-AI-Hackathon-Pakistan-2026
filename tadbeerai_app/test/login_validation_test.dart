import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/core/theme/app_theme.dart';
import 'package:tadbeerai/core/widgets/app_button.dart';
import 'package:tadbeerai/features/auth/login_screen.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/repository_providers.dart';

Future<void> _pumpLogin(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const Scaffold(body: SizedBox()),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: SizedBox()),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty form shows email and password validation errors',
      (tester) async {
    await _pumpLogin(tester);

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(
      find.text('Please enter a valid email address.'),
      findsOneWidget,
    );
    expect(
      find.text('Password must be at least 6 characters.'),
      findsOneWidget,
    );
  });

  testWidgets('valid email with short password shows only password error',
      (tester) async {
    await _pumpLogin(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'ahsan.khan@tadbeer.ai',
    );

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(
      find.text('Please enter a valid email address.'),
      findsNothing,
    );
    expect(
      find.text('Password must be at least 6 characters.'),
      findsOneWidget,
    );
  });

  testWidgets('valid credentials sign in and navigate away from login',
      (tester) async {
    await _pumpLogin(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'ahsan.khan@tadbeer.ai',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'secret123',
    );

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsNothing);
  });
}

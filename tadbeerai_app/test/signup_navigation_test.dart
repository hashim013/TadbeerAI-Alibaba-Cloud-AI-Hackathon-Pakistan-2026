import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/core/theme/app_theme.dart';
import 'package:tadbeerai/features/auth/login_screen.dart';
import 'package:tadbeerai/features/auth/signup_screen.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/repository_providers.dart';

Future<void> _pumpAuthFlow(
  WidgetTester tester, {
  String initialLocation = '/signup',
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/profile/financial',
        builder: (context, state) =>
            const Scaffold(body: Text('Profile Screen')),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Home Screen')),
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

  testWidgets(
      'phone system back button on SignupScreen directs user to LoginScreen',
      (tester) async {
    await _pumpAuthFlow(tester, initialLocation: '/signup');

    // Verify user is on SignupScreen
    expect(find.byType(SignupScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    // Simulate phone hardware / system back button press
    await TestWidgetsFlutterBinding.instance.handlePopRoute();
    await tester.pumpAndSettle();

    // Verify user is redirected to LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SignupScreen), findsNothing);
  });

  testWidgets(
      'circular on-screen back button on SignupScreen directs user to LoginScreen',
      (tester) async {
    await _pumpAuthFlow(tester, initialLocation: '/signup');

    expect(find.byType(SignupScreen), findsOneWidget);

    // Find circular back button by its icon
    final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
    expect(backButton, findsOneWidget);

    await tester.tap(backButton);
    await tester.pumpAndSettle();

    // Verify redirected to LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SignupScreen), findsNothing);
  });

  testWidgets(
      'footer "Sign In" text button on SignupScreen directs user to LoginScreen',
      (tester) async {
    await _pumpAuthFlow(tester, initialLocation: '/signup');

    expect(find.byType(SignupScreen), findsOneWidget);

    // Ensure footer "Sign In" link is visible and tap it
    final signInLink = find.text('Sign In');
    await tester.ensureVisible(signInLink);
    await tester.pumpAndSettle();
    expect(signInLink, findsOneWidget);

    await tester.tap(signInLink);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SignupScreen), findsNothing);
  });

  testWidgets(
      'navigating from LoginScreen to SignupScreen and pressing phone back returns to LoginScreen',
      (tester) async {
    await _pumpAuthFlow(tester, initialLocation: '/login');

    expect(find.byType(LoginScreen), findsOneWidget);

    // Tap "Create Account"
    final createAccountLink = find.text('Create Account');
    await tester.ensureVisible(createAccountLink);
    await tester.pumpAndSettle();
    expect(createAccountLink, findsOneWidget);

    await tester.tap(createAccountLink);
    await tester.pumpAndSettle();

    // User is now on SignupScreen
    expect(find.byType(SignupScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    // Press phone back button
    await TestWidgetsFlutterBinding.instance.handlePopRoute();
    await tester.pumpAndSettle();

    // Directed back to LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SignupScreen), findsNothing);
  });
}

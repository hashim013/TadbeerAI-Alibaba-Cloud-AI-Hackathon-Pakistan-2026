import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/core/theme/app_theme.dart';
import 'package:tadbeerai/features/auth/google_auth_screen.dart';
import 'package:tadbeerai/features/auth/login_screen.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/repository_providers.dart';

Future<void> _pumpGoogleAuthScreen(
  WidgetTester tester, {
  String initialLocation = '/auth/google',
  Map<String, Object> initialPrefs = const {},
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/google',
        builder: (context, state) => const GoogleAuthScreen(),
      ),
      GoRoute(
        path: '/profile/financial',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('User Persona Form Screen')),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Home Dashboard Screen')),
        ),
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

  testWidgets('renders Google branding, accounts, and security indicators',
      (tester) async {
    await _pumpGoogleAuthScreen(tester);

    // Branding elements
    expect(find.byType(GoogleLogo), findsWidgets);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Choose an account to continue to Tadbeer AI'),
        findsOneWidget);
    expect(find.text('accounts.google.com'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Account list
    expect(find.text('Ahsan Khan'), findsOneWidget);
    expect(find.text('ahsan.khan@gmail.com'), findsOneWidget);
    expect(find.text('Active on device'), findsOneWidget);
    expect(find.text('Syed Bilal'), findsOneWidget);
    expect(find.text('bilal.syed@gmail.com'), findsOneWidget);
    expect(find.text('Use another account'), findsOneWidget);

    // Privacy notice
    expect(find.text('Google Privacy & Disclosure'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
  });

  testWidgets(
      'selecting Ahsan Khan for first time directs to user persona form screen',
      (tester) async {
    await _pumpGoogleAuthScreen(tester);

    // Tap Ahsan Khan account card
    await tester.tap(find.text('Ahsan Khan'));
    await tester.pump(); // start loading
    expect(find.text('Connecting to Google...'), findsOneWidget);

    await tester.pumpAndSettle(); // settle mock delay & router transition

    expect(find.text('User Persona Form Screen'), findsOneWidget);
  });

  testWidgets(
      'selecting Syed Bilal with completed profile redirects to home dashboard',
      (tester) async {
    await _pumpGoogleAuthScreen(
      tester,
      initialPrefs: {
        'financial_profile_v1':
            '{"profileCompleted":true,"persona":"salaried","monthlyIncome":150000,"monthlyEssentialExpenses":80000}',
      },
    );

    // Tap Syed Bilal account card
    await tester.tap(find.text('Syed Bilal'));
    await tester.pump();
    expect(find.text('Connecting to Google...'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Home Dashboard Screen'), findsOneWidget);
  });

  testWidgets(
      'use another account toggles input and authenticates custom email',
      (tester) async {
    await _pumpGoogleAuthScreen(tester);

    // Tap "Use another account"
    await tester.tap(find.text('Use another account'));
    await tester.pumpAndSettle();

    // Input field appears
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Test invalid email validation
    await tester.enterText(find.byType(TextFormField), 'bad-email');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);

    // Enter valid email and continue
    await tester.enterText(
        find.byType(TextFormField), 'tariq.mehmood@gmail.com');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('User Persona Form Screen'), findsOneWidget);
  });

  testWidgets('cancel button pops back to previous screen', (tester) async {
    await _pumpGoogleAuthScreen(tester, initialLocation: '/auth/google');

    expect(find.text('Sign in with Google'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Returned to /login
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('tapping Privacy Policy opens information sheet', (tester) async {
    await _pumpGoogleAuthScreen(tester);

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(find.text('Got it'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Got it'), findsNothing);
  });
}

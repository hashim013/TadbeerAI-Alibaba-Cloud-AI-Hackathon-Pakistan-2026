import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/core/theme/app_theme.dart';
import 'package:tadbeerai/core/widgets/app_button.dart';
import 'package:tadbeerai/features/auth/forgot_password_screen.dart';
import 'package:tadbeerai/features/auth/login_screen.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/repository_providers.dart';

Future<void> _pumpForgotPassword(
  WidgetTester tester, {
  String? initialEmail,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: '/forgot-password',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) =>
            ForgotPasswordScreen(initialEmail: initialEmail),
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

  testWidgets('validates empty and invalid email on Stage 1', (tester) async {
    await _pumpForgotPassword(tester);

    expect(find.text('Reset Password'), findsOneWidget);

    // Tap Send Verification Code without email
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);

    // Enter invalid email format
    await tester.enterText(find.byType(TextFormField).first, 'notanemail');
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);
  });

  testWidgets(
      'submitting valid email moves to Stage 2 with 6 PIN boxes and password fields',
      (tester) async {
    await _pumpForgotPassword(tester);

    await tester.enterText(
        find.byType(TextFormField).first, 'bilal@tadbeer.ai');
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    // Verify Stage 2 is displayed
    expect(find.text('Verify Code'), findsOneWidget);
    expect(find.textContaining('Code sent to bilal@tadbeer.ai'), findsOneWidget);
    expect(find.text('Demo code: 842196'), findsOneWidget);

    // Tapping Change returns to Stage 1
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
  });

  testWidgets(
      'tapping demo code pill autofills PIN and validates password constraints',
      (tester) async {
    await _pumpForgotPassword(tester, initialEmail: 'bilal@tadbeer.ai');

    // Send code
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(find.text('Verify Code'), findsOneWidget);

    // Tap demo code pill
    final demoPill = find.text('Demo code: 842196');
    expect(demoPill, findsOneWidget);
    await tester.tap(demoPill);
    await tester.pumpAndSettle();

    // Verify digits are entered (find '8', '4', '2', '1', '9', '6')
    expect(find.text('8'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    // Tap Reset Password without passwords
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(find.text('Password must be at least 6 characters.'), findsOneWidget);

    // Enter short password
    await tester.enterText(find.byType(TextFormField).at(0), '123');
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(find.text('Password must be at least 6 characters.'), findsOneWidget);

    // Enter mismatched passwords
    await tester.enterText(find.byType(TextFormField).at(0), 'newpassword123');
    await tester.enterText(find.byType(TextFormField).at(1), 'mismatch123');
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets(
      'full successful reset flow navigates to Stage 3 and returns to LoginScreen',
      (tester) async {
    await _pumpForgotPassword(tester, initialEmail: 'bilal@tadbeer.ai');

    // Stage 1 -> Send code
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    // Stage 2 -> Autofill demo code
    await tester.tap(find.text('Demo code: 842196'));
    await tester.pumpAndSettle();

    // Enter matching new password
    await tester.enterText(find.byType(TextFormField).at(0), 'securePass123');
    await tester.enterText(find.byType(TextFormField).at(1), 'securePass123');

    // Submit reset
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    // Verify Stage 3 success view
    expect(find.text('Password Reset Successfully!'), findsOneWidget);
    expect(
      find.textContaining('Your password has been securely updated.'),
      findsOneWidget,
    );

    // Tap Back to Sign In
    final backToSignInBtn = find.text('Back to Sign In');
    expect(backToSignInBtn, findsOneWidget);
    await tester.tap(backToSignInBtn);
    await tester.pumpAndSettle();

    // Verify user is now on LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ForgotPasswordScreen), findsNothing);
  });

  testWidgets('phone back button on Stage 2 returns to Stage 1', (tester) async {
    await _pumpForgotPassword(tester, initialEmail: 'bilal@tadbeer.ai');

    // Advance to Stage 2
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(find.text('Verify Code'), findsOneWidget);

    // Trigger system back button
    await TestWidgetsFlutterBinding.instance.handlePopRoute();
    await tester.pumpAndSettle();

    // Should return to Stage 1, not exit screen
    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);

    // Trigger system back on Stage 1 -> returns to LoginScreen
    await TestWidgetsFlutterBinding.instance.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ForgotPasswordScreen), findsNothing);
  });
}

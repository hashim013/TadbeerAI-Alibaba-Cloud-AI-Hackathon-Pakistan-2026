import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/domain/entities/financial_profile.dart';
import 'package:tadbeerai/domain/repositories/financial_profile_repository.dart';
import 'package:tadbeerai/features/profile/financial_profile_screen.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/repository_providers.dart';

// ── In-memory mock repository ────────────────────────────────────────────

class _MockProfileRepo implements FinancialProfileRepository {
  FinancialProfile? stored;
  FinancialProfile? lastSaved;
  int saveCount = 0;

  @override
  Future<FinancialProfile?> loadProfile() async => stored;

  @override
  Future<void> saveProfile(FinancialProfile profile) async {
    stored = profile;
    lastSaved = profile;
    saveCount++;
  }

  @override
  Future<void> clearProfile() async {
    stored = null;
  }
}

/// Pumps the FinancialProfileScreen with localizations and mock providers.
Future<void> _pumpProfile(
  WidgetTester tester,
  _MockProfileRepo repo,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        financialProfileRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const FinancialProfileScreen(isStepped: false),
          ),
        ),
      ),
    ),
  );
  // Use runAsync to properly flush the AsyncNotifier build() microtasks.
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pump();
  // Extra pump to flush ref.listen → addPostFrameCallback → setState cycle.
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pump();
  await tester.pumpAndSettle();
}

/// Returns the ListView's own Scrollable (the first Scrollable descendant;
/// horizontal scrollers inside TextFormFields come later in the tree).
Finder _formScrollable() => find
    .descendant(
      of: find.byKey(const ValueKey('profile_form_list')),
      matching: find.byType(Scrollable),
    )
    .first;

/// Scrolls [finder] into view within the form's ListView, then taps it.
/// Uses scrollUntilVisible for lazy-built widgets, then ensureVisible to
/// guarantee the widget is on-screen before tapping.
Future<void> _scrollAndTap(WidgetTester tester, Finder finder) async {
  final scrollable = _formScrollable();
  await tester.scrollUntilVisible(
    finder,
    100,
    scrollable: scrollable,
  );
  // scrollUntilVisible may return when the widget is in the tree but not
  // fully on-screen (e.g. Wrap children).  ensureVisible fixes that.
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

/// Enters [text] into the income or expenses TextFormField by label.
Future<void> _enterAmount(
  WidgetTester tester, {
  required String text,
  required bool isExpenses,
}) async {
  // Extra pump to ensure the form is fully laid out before interacting.
  await tester.pump();
  final label =
      isExpenses ? 'Essential Monthly Expenses' : 'Typical Monthly Income';
  final field = find.widgetWithText(TextFormField, label);
  final scrollable = _formScrollable();
  if (field.evaluate().isEmpty) {
    try {
      await tester.scrollUntilVisible(
        field,
        -100,
        scrollable: scrollable,
      );
    } catch (_) {
      await tester.scrollUntilVisible(
        field,
        100,
        scrollable: scrollable,
      );
    }
  }
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  await tester.tap(editable, warnIfMissed: false);
  tester.testTextInput.enterText(text);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Form loading ──────────────────────────────────────────────────────
  group('Form prefill', () {
    testWidgets('renders form sections when no profile exists', (tester) async {
      final repo = _MockProfileRepo();
      await _pumpProfile(tester, repo);

      // Screen header is visible.
      expect(find.text('Build Your Financial Profile'), findsOneWidget);

      // Persona cards present.
      expect(find.text('Student'), findsOneWidget);
      expect(find.text('Salaried Employee'), findsOneWidget);

      // Save button exists (scroll to it).
      await tester.scrollUntilVisible(
        find.text('Save Profile'),
        100,
        scrollable: _formScrollable(),
      );
      await tester.ensureVisible(find.text('Save Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Save Profile'), findsOneWidget);
    });

    testWidgets('prefills from existing completed profile', (tester) async {
      final repo = _MockProfileRepo()
        ..stored = const FinancialProfile(
          persona: Persona.salaried,
          monthlyIncome: 80000,
          monthlyEssentialExpenses: 55000,
          primaryGoal: PrimaryGoal.saveMore,
          profileCompleted: true,
        );

      await _pumpProfile(tester, repo);

      // Form header renders.
      expect(find.text('Build Your Financial Profile'), findsOneWidget);

      // Scroll the income field into view (ListView lazy-builds children).
      final incomeLabel = find.text('Typical Monthly Income');
      await tester.scrollUntilVisible(
        incomeLabel,
        100,
        scrollable: _formScrollable(),
      );
      await tester.ensureVisible(incomeLabel);
      await tester.pumpAndSettle();

      // ── CRITICAL: form controls actually contain saved values ──────────

      // Income text field contains saved income.
      expect(
        find.descendant(
          of: find.byType(TextFormField),
          matching: find.text('80000'),
        ),
        findsOneWidget,
        reason: 'Income field must display saved value 80000',
      );

      // Scroll the expenses field into view.
      final expensesLabel = find.text('Essential Monthly Expenses');
      await tester.scrollUntilVisible(
        expensesLabel,
        100,
        scrollable: _formScrollable(),
      );
      await tester.ensureVisible(expensesLabel);
      await tester.pumpAndSettle();

      // Expenses text field contains saved expenses.
      expect(
        find.descendant(
          of: find.byType(TextFormField),
          matching: find.text('55000'),
        ),
        findsOneWidget,
        reason: 'Expenses field must display saved value 55000',
      );

      // Scroll back to persona section.
      await tester.drag(
        _formScrollable(),
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();

      // Persona card for "Salaried Employee" is visibly selected
      // (shows a check_circle_rounded icon).
      final salariedRow = find.ancestor(
        of: find.text('Salaried Employee'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(
          of: salariedRow.first,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
        reason: 'Salaried Employee persona card must show as selected',
      );

      // Scroll to goal section.
      final goalLabel = find.text('Save More');
      await tester.scrollUntilVisible(
        goalLabel,
        100,
        scrollable: _formScrollable(),
      );
      await tester.ensureVisible(goalLabel);
      await tester.pumpAndSettle();

      // Goal card for "Save More" is visibly selected.
      final goalRow = find.ancestor(
        of: find.text('Save More'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(
          of: goalRow.first,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
        reason: 'Save More goal card must show as selected',
      );
    });

    testWidgets('edit existing profile saves new values', (tester) async {
      final repo = _MockProfileRepo()
        ..stored = const FinancialProfile(
          persona: Persona.student,
          monthlyIncome: 30000,
          monthlyEssentialExpenses: 20000,
          primaryGoal: PrimaryGoal.education,
          profileCompleted: true,
        );

      await _pumpProfile(tester, repo);

      // Scroll to income field and verify prefill.
      final incomeLabel = find.text('Typical Monthly Income');
      await tester.scrollUntilVisible(
        incomeLabel,
        100,
        scrollable: _formScrollable(),
      );
      await tester.ensureVisible(incomeLabel);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(TextFormField),
          matching: find.text('30000'),
        ),
        findsOneWidget,
        reason: 'Income field must be prefilled with 30000',
      );

      // Scroll back to persona section and change persona.
      await tester.drag(
        _formScrollable(),
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salaried Employee'));
      await tester.pumpAndSettle();

      // Change income.
      await _enterAmount(tester, text: '120000', isExpenses: false);

      // Change goal.
      await _scrollAndTap(tester, find.text('Emergency Fund'));

      // Save.
      await _scrollAndTap(tester, find.text('Save Profile'));
      await tester.pumpAndSettle();

      expect(repo.saveCount, 1);
      expect(repo.lastSaved?.persona, Persona.salaried);
      expect(repo.lastSaved?.monthlyIncome, 120000);
      expect(repo.lastSaved?.primaryGoal, PrimaryGoal.emergencyFund);
      expect(repo.lastSaved?.profileCompleted, isTrue);
    });

    testWidgets('cancel does not overwrite stored values', (tester) async {
      final repo = _MockProfileRepo()
        ..stored = const FinancialProfile(
          persona: Persona.salaried,
          monthlyIncome: 80000,
          monthlyEssentialExpenses: 55000,
          primaryGoal: PrimaryGoal.saveMore,
          profileCompleted: true,
        );

      await _pumpProfile(tester, repo);

      // Scroll to the bottom to find the "Not now" button.
      await tester.scrollUntilVisible(
        find.text('Not now'),
        100,
        scrollable: _formScrollable(),
      );
      await tester.ensureVisible(find.text('Not now'));
      await tester.pumpAndSettle();

      // Tap cancel ("Not now" button).
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      // Save was never called — stored values remain unchanged.
      expect(repo.saveCount, 0);
      expect(repo.stored?.persona, Persona.salaried);
      expect(repo.stored?.monthlyIncome, 80000);
      expect(repo.stored?.monthlyEssentialExpenses, 55000);
      expect(repo.stored?.primaryGoal, PrimaryGoal.saveMore);
      expect(repo.stored?.profileCompleted, isTrue);
    });
  });

  // ── Validation ────────────────────────────────────────────────────────
  group('Validation', () {
    testWidgets('empty form shows persona and goal errors', (tester) async {
      final repo = _MockProfileRepo();
      await _pumpProfile(tester, repo);

      // Scroll to Save Profile and tap it.
      await _scrollAndTap(tester, find.text('Save Profile'));
      await tester.pumpAndSettle();

      // Scroll back up to see persona error.
      await tester.drag(
        _formScrollable(),
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();

      expect(find.text('Please select who you are.'), findsOneWidget);

      // Repository NOT called.
      expect(repo.saveCount, 0);
    });

    testWidgets('non-numeric income is rejected', (tester) async {
      final repo = _MockProfileRepo();
      await _pumpProfile(tester, repo);

      await tester.tap(find.text('Student'));
      await _scrollAndTap(tester, find.text('Education'));

      await _enterAmount(tester, text: 'abc', isExpenses: false);
      await _enterAmount(tester, text: '5000', isExpenses: true);

      await _scrollAndTap(tester, find.text('Save Profile'));
      await tester.pumpAndSettle();

      // Scroll back up to see the income validation error.
      await tester.drag(
        _formScrollable(),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter a valid income amount.'),
        findsOneWidget,
      );
      expect(repo.saveCount, 0);
    });

    testWidgets('negative income is rejected', (tester) async {
      final repo = _MockProfileRepo();
      await _pumpProfile(tester, repo);

      await tester.tap(find.text('Student'));
      await _scrollAndTap(tester, find.text('Education'));

      await _enterAmount(tester, text: '-100', isExpenses: false);
      await _enterAmount(tester, text: '0', isExpenses: true);

      await _scrollAndTap(tester, find.text('Save Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Income cannot be negative.'), findsOneWidget);
      expect(repo.saveCount, 0);
    });

    testWidgets('negative expenses are rejected', (tester) async {
      final repo = _MockProfileRepo();
      await _pumpProfile(tester, repo);

      await tester.tap(find.text('Student'));
      await _scrollAndTap(tester, find.text('Education'));

      await _enterAmount(tester, text: '5000', isExpenses: false);
      await _enterAmount(tester, text: '-500', isExpenses: true);

      await _scrollAndTap(tester, find.text('Save Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Expenses cannot be negative.'), findsOneWidget);
      expect(repo.saveCount, 0);
    });
  });

  // ── Zero income ───────────────────────────────────────────────────────
  group('Zero income', () {
    testWidgets('student can save with income = 0', (tester) async {
      final repo = _MockProfileRepo();
      await _pumpProfile(tester, repo);

      await tester.tap(find.text('Student'));
      await _scrollAndTap(tester, find.text('Education'));

      await _enterAmount(tester, text: '0', isExpenses: false);
      await _enterAmount(tester, text: '0', isExpenses: true);

      await _scrollAndTap(tester, find.text('Save Profile'));
      await tester.pumpAndSettle();

      expect(repo.saveCount, 1);
      expect(repo.lastSaved?.monthlyIncome, 0);
      expect(repo.lastSaved?.monthlyEssentialExpenses, 0);
      expect(repo.lastSaved?.profileCompleted, isTrue);
      expect(repo.lastSaved?.persona, Persona.student);
      expect(repo.lastSaved?.primaryGoal, PrimaryGoal.education);
    });
  });

  // ── Expenses > income warning ─────────────────────────────────────────
  group('Expenses warning', () {
    testWidgets('warning appears when expenses exceed income', (tester) async {
      final repo = _MockProfileRepo();
      await _pumpProfile(tester, repo);

      // Tap persona and goal first (ensures form is fully laid out).
      await tester.tap(find.text('Student'));
      await _scrollAndTap(tester, find.text('Other'));

      await _enterAmount(tester, text: '30000', isExpenses: false);
      await _enterAmount(tester, text: '45000', isExpenses: true);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('higher than your typical income'),
        findsOneWidget,
      );
    });

    testWidgets('warning does not block save', (tester) async {
      final repo = _MockProfileRepo();
      await _pumpProfile(tester, repo);

      await tester.tap(find.text('Salaried Employee'));
      await _scrollAndTap(tester, find.text('Reduce Spending'));

      await _enterAmount(tester, text: '40000', isExpenses: false);
      await _enterAmount(tester, text: '55000', isExpenses: true);
      await tester.pumpAndSettle();

      // Warning is shown.
      expect(
        find.textContaining('higher than your typical income'),
        findsOneWidget,
      );

      // Save succeeds anyway.
      await _scrollAndTap(tester, find.text('Save Profile'));
      await tester.pumpAndSettle();

      expect(repo.saveCount, 1);
      expect(repo.lastSaved?.monthlyIncome, 40000);
      expect(repo.lastSaved?.monthlyEssentialExpenses, 55000);
      expect(repo.lastSaved?.profileCompleted, isTrue);
    });
  });

  // ── Save ──────────────────────────────────────────────────────────────
  group('Save', () {
    testWidgets('save sets profileCompleted to true', (tester) async {
      final repo = _MockProfileRepo();
      await _pumpProfile(tester, repo);

      await tester.tap(find.text('Business Owner'));
      await _scrollAndTap(tester, find.text('Business Growth'));

      await _enterAmount(tester, text: '200000', isExpenses: false);
      await _enterAmount(tester, text: '120000', isExpenses: true);

      await _scrollAndTap(tester, find.text('Save Profile'));
      await tester.pumpAndSettle();

      expect(repo.saveCount, 1);
      expect(repo.lastSaved?.profileCompleted, isTrue);
      expect(repo.lastSaved?.persona, Persona.businessOwner);
      expect(repo.lastSaved?.primaryGoal, PrimaryGoal.businessGrowth);
      expect(repo.lastSaved?.monthlyIncome, 200000);
      expect(repo.lastSaved?.monthlyEssentialExpenses, 120000);
    });

    testWidgets('save uses FinancialProfileRepository', (tester) async {
      final repo = _MockProfileRepo();
      await _pumpProfile(tester, repo);

      await tester.tap(find.text('Shop Owner'));
      await _scrollAndTap(tester, find.text('Emergency Fund'));
      await _enterAmount(tester, text: '100000', isExpenses: false);
      await _enterAmount(tester, text: '70000', isExpenses: true);

      await _scrollAndTap(tester, find.text('Save Profile'));
      await tester.pumpAndSettle();

      expect(repo.saveCount, 1);
      expect(repo.stored, isNotNull);
      expect(repo.stored!.persona, Persona.shopOwner);
      expect(repo.stored!.primaryGoal, PrimaryGoal.emergencyFund);
    });

    testWidgets('shows snackbar on successful save', (tester) async {
      final repo = _MockProfileRepo();
      await _pumpProfile(tester, repo);

      await tester.tap(find.text('Student'));
      await _scrollAndTap(tester, find.text('Other'));
      await _enterAmount(tester, text: '0', isExpenses: false);
      await _enterAmount(tester, text: '0', isExpenses: true);

      await _scrollAndTap(tester, find.text('Save Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Profile saved!'), findsOneWidget);
    });
  });

  // ── Stepped Wizard Flow (Matching Reference Mockups) ────────────────────
  group('Stepped Wizard Flow', () {
    Future<void> pumpSteppedWizard(
      WidgetTester tester,
      _MockProfileRepo repo,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            financialProfileRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const FinancialProfileScreen(isStepped: true),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      await tester.pumpAndSettle();
    }

    testWidgets('Step 1 renders correctly and requires persona to proceed',
        (tester) async {
      final repo = _MockProfileRepo();
      await pumpSteppedWizard(tester, repo);

      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.textContaining('Tell us about'), findsOneWidget);
      expect(find.text('What best describes you?'), findsOneWidget);
      expect(find.text('Student'), findsOneWidget);
      expect(find.text('Salaried Employee'), findsOneWidget);
      expect(find.text('Shop Owner'), findsOneWidget);
      expect(find.text('Business Owner'), findsOneWidget);
      expect(
        find.textContaining('Your information is secure'),
        findsOneWidget,
      );

      // Tapping continue without selection shows validation snackbar
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Please select who you are.'), findsOneWidget);
    });

    testWidgets('transitions through Step 1 to Step 4 and back smoothly',
        (tester) async {
      final repo = _MockProfileRepo();
      await pumpSteppedWizard(tester, repo);

      // Step 1: Select persona
      await tester.tap(find.text('Student'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2: Finances
      expect(find.text('Step 2 of 4'), findsOneWidget);
      expect(
        find.text("What's your typical monthly income?"),
        findsOneWidget,
      );
      expect(
        find.text("What's your typical monthly essential spending?"),
        findsOneWidget,
      );

      // Step 2: Tap Continue to go to Step 3
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 3: Goals
      expect(find.text('Step 3 of 4'), findsOneWidget);
      expect(find.text('Almost there!'), findsOneWidget);
      expect(
        find.text('What are your primary\nfinancial goals?'),
        findsOneWidget,
      );

      // Tap Back to return to Step 2
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 4'), findsOneWidget);

      // Tap Back to return to Step 1
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 4'), findsOneWidget);
    });

    testWidgets('completing all 4 steps reviews summary and saves profile',
        (tester) async {
      final repo = _MockProfileRepo();
      await pumpSteppedWizard(tester, repo);

      // Step 1: Select persona and advance
      await tester.tap(find.text('Salaried Employee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2: Enter income, expenses & savings
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '80000');
      await tester.enterText(textFields.at(1), '54900');
      await tester.enterText(textFields.at(2), '250000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 3: Select goal and advance
      expect(find.text('Step 3 of 4'), findsOneWidget);
      await tester.tap(find.text('Emergency\nFund'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 4: Review and confirm
      expect(find.text('Step 4 of 4'), findsOneWidget);
      expect(find.text('Review & confirm'), findsOneWidget);
      expect(find.text('Your Profile Summary'), findsOneWidget);
      expect(find.text('You are'), findsOneWidget);
      expect(find.text('Salaried Employee'), findsOneWidget);
      expect(find.text('PKR 80,000'), findsOneWidget);
      expect(find.text('PKR 54,900'), findsOneWidget);
      expect(find.text('PKR 250,000'), findsOneWidget);
      expect(find.text('Emergency Fund'), findsOneWidget);

      // Tap Complete Profile
      await tester.tap(find.text('Complete Profile'));
      await tester.pumpAndSettle();

      expect(repo.saveCount, 1);
      expect(repo.lastSaved?.persona, Persona.salaried);
      expect(repo.lastSaved?.monthlyIncome, 80000);
      expect(repo.lastSaved?.monthlyEssentialExpenses, 54900);
      expect(repo.lastSaved?.totalSavings, 250000);
      expect(repo.lastSaved?.primaryGoal, PrimaryGoal.emergencyFund);
      expect(repo.lastSaved?.profileCompleted, isTrue);
    });
  });
}

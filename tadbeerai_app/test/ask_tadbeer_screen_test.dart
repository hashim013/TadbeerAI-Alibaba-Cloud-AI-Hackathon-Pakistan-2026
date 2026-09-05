import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/core/theme/app_theme.dart';
import 'package:tadbeerai/domain/entities/assistant_api_models.dart';
import 'package:tadbeerai/domain/entities/assistant_message.dart';
import 'package:tadbeerai/domain/repositories/assistant_repository.dart';
import 'package:tadbeerai/features/assistant/ask_tadbeer_screen.dart';
import 'package:tadbeerai/l10n/app_localizations.dart';
import 'package:tadbeerai/providers/assistant_providers.dart';

/// AskTadbeerScreen widget tests over the integrated backend reply bubble:
/// scenario rendering, key numbers, sources, statuses, the guided What-If
/// sheet and localized submissions (spec cases 8, 9, 13-15, 17-19).

/// Mirrors the demo finance context used across the app's test suite.
const _context = AssistantContext(
  monthlyIncome: 80000,
  monthlyExpenses: 55000,
  monthlySavings: 25000,
  discretionarySpending: 10100,
  savingsRate: 0.3125,
  healthScore: 76,
  emergencyMonths: 3.0,
  overBudgetCategories: [],
  budgetLimitTotal: 55000,
  budgetedSpent: 55000,
  goalCount: 1,
  goalAverageProgress: 0.6,
  topGoalTitle: 'Emergency Fund',
  topGoalProgress: 0.6,
  topGoalRequiredMonthly: 12000,
  inflationRate: 11.2,
  usdPkrRate: 278.5,
  usdPkrChange: 1.2,
  kiborRate: 20.3,
);

/// Fake repository that replies with a scripted backend payload.
class _ScriptedRepository implements AssistantRepository {
  _ScriptedRepository(this.reply, {this.delay = Duration.zero});

  AssistantReply? reply;
  final Duration delay;

  final calls = <({String question, String language})>[];

  @override
  Future<AssistantReply> respond(
    String question,
    AssistantContext context, {
    String language = 'en',
  }) async {
    calls.add((question: question, language: language));
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final prepared = reply;
    if (prepared == null) {
      throw const AssistantApiException(AssistantErrorKind.network);
    }
    return prepared;
  }
}

AssistantReply _apiReply(Map<String, Object?> json) => AssistantReply(
      intent: AssistantIntent.general,
      params: const {},
      followUps: const [],
      confidence: 1,
      api: AssistantApiReply.fromJson(json),
    );

Map<String, Object?> _saveMoreBody() => {
      'answer': 'Under this scenario, your monthly savings rise.',
      'intent': 'scenario_planning',
      'language': 'en',
      'provider': 'groq',
      'agentsUsed': ['supervisor', 'risk_impact'],
      'metrics': {
        'monthly_savings': 25000.0,
        'scenario': {
          'scenario_type': 'save_more',
          'status': 'calculated',
          'source': 'user-defined scenario (deterministic calculation)',
          'assumptions': {'additional_monthly_savings_pkr': 5000.0},
          'inputs': {'monthly_income': 80000.0, 'monthly_expenses': 55000.0},
          'outputs': {
            'additional_monthly_savings': 5000.0,
            'additional_savings_6_months': 30000.0,
            'additional_savings_12_months': 60000.0,
            'current_monthly_savings': 25000.0,
            'new_monthly_savings': 30000.0,
            'current_savings_rate_pct': 31.2,
            'new_savings_rate_pct': 37.5,
          },
          'limitations': [
            'Simple savings accumulation only — no investment returns or '
                'interest assumed.',
          ],
        },
      },
      'recommendations': [
        'Consider directing the additional amount toward your selected goal.',
      ],
      'sources': [
        'deterministic calculation results',
        'user-defined scenario (deterministic calculation)',
      ],
      'dataStatus': 'scenario',
    };

Map<String, Object?> _expenseShockBody() => {
      'answer': 'Your surplus would shrink under this assumption.',
      'intent': 'scenario_planning',
      'language': 'en',
      'provider': 'groq',
      'metrics': {
        'scenario': {
          'scenario_type': 'expense_shock',
          'status': 'calculated',
          'source': 'user-defined scenario (deterministic calculation)',
          'assumptions': {'expense_change_pct': 10.0},
          'inputs': {'monthly_income': 80000.0, 'monthly_expenses': 55000.0},
          'outputs': {
            'expense_shock_pct': 10.0,
            'current_monthly_expenses': 55000.0,
            'additional_monthly_expense': 5500.0,
            'new_monthly_expenses': 60500.0,
            'current_monthly_surplus': 25000.0,
            'projected_monthly_surplus': 19500.0,
            'current_savings_rate_pct': 31.2,
            'projected_savings_rate_pct': 24.4,
          },
          'limitations': [
            'The 10.0% expense change is a user-defined scenario assumption, '
                'not a forecast of actual inflation.',
          ],
        },
      },
      'recommendations': ['Trim one discretionary category to absorb it.'],
      'sources': ['deterministic calculation results'],
      'dataStatus': 'scenario',
    };

Map<String, Object?> _liveEconomyBody() => {
      'answer': 'Inflation is cooling but remains a pressure on budgets.',
      'intent': 'economic_intelligence',
      'language': 'en',
      'provider': 'groq',
      'agentsUsed': ['economic_intelligence'],
      'metrics': {
        'inflation_rate_pct': 3.5,
        'policy_rate_pct': 11.0,
        'usd_pkr': 278.4,
      },
      'recommendations': ['Keep an emergency buffer for price swings.'],
      'sources': ['World Bank API (FP.CPI.TOTL.ZG)'],
      'dataStatus': 'live',
    };

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _ScriptedRepository repository,
  Locale locale = const Locale('en'),
}) {
  // Phone-shaped surface: the conversation list is reverse-anchored, and
  // items outside viewport + cache extent are never built — a tall surface
  // keeps the whole reply bubble (and the user bubble above it) laid out.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        assistantContextProvider.overrideWithValue(_context),
        assistantRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AskTadbeerScreen(),
      ),
    ),
  );
}

Future<void> _submitQuestion(WidgetTester tester, String question) async {
  await tester.enterText(find.byType(TextField), question);
  // One frame so the send button re-enables for the entered text.
  await tester.pump();
  // Tapped by icon, not tooltip — the tooltip is localized.
  await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
  await tester.pump();
}

void main() {
  testWidgets('save-more scenario renders backend numbers + labels (8, 14)',
      (tester) async {
    final repository = _ScriptedRepository(_apiReply(_saveMoreBody()));
    await _pumpScreen(tester, repository: repository);

    await _submitQuestion(tester, 'What if I save PKR 5,000 more every month?');
    await tester.pumpAndSettle();

    // The user's own message and the backend answer are both visible.
    expect(find.text('What if I save PKR 5,000 more every month?'),
        findsOneWidget);
    expect(find.text('Under this scenario, your monthly savings rise.'),
        findsOneWidget);

    // Highly visible scenario label + the not-a-forecast caveat.
    expect(find.text('What-If Scenario'), findsOneWidget);
    expect(find.text('Based on your assumption — not a forecast.'),
        findsOneWidget);
    expect(find.text('ASSUMPTION'), findsOneWidget);

    // The assumption sentence, from the backend payload.
    expect(find.text('Save Rs 5,000 more each month'), findsOneWidget);

    // Numbers straight from the backend — never recalculated in Dart.
    expect(find.text('Rs 25,000'), findsOneWidget); // current savings
    expect(find.text('Rs 5,000'), findsOneWidget); // additional / month
    expect(find.text('Rs 30,000'), findsNWidgets(2)); // new + after 6 mo
    expect(find.text('Rs 60,000'), findsOneWidget); // after 12 months

    // Next step comes from the backend recommendations.
    expect(
      find.text(
          'Consider directing the additional amount toward your selected goal.'),
      findsOneWidget,
    );

    // Sources render from the backend list only.
    expect(find.text('deterministic calculation results'), findsOneWidget);
    expect(find.text('user-defined scenario (deterministic calculation)'),
        findsOneWidget);
  });

  testWidgets('expense-shock scenario renders current/changes/impact (15)',
      (tester) async {
    final repository = _ScriptedRepository(_apiReply(_expenseShockBody()));
    await _pumpScreen(tester, repository: repository);

    await _submitQuestion(tester, 'What if my expenses increase by 10%?');
    await tester.pumpAndSettle();

    expect(find.text('Expenses increase by 10%'), findsOneWidget);
    expect(find.text('CURRENT SITUATION'), findsOneWidget);
    expect(find.text('WHAT CHANGES'), findsOneWidget);
    expect(find.text('ESTIMATED IMPACT'), findsOneWidget);

    expect(find.text('Rs 55,000'), findsOneWidget); // current expenses
    expect(find.text('Rs 5,500'), findsOneWidget); // additional expense
    expect(find.text('Rs 60,500'), findsOneWidget); // new expenses
    expect(find.text('Rs 19,500'), findsOneWidget); // projected surplus
    expect(find.text('24.4%'), findsOneWidget); // projected rate
  });

  testWidgets('live economy answer shows key numbers and live status (9, 4)',
      (tester) async {
    final repository = _ScriptedRepository(_apiReply(_liveEconomyBody()));
    await _pumpScreen(tester, repository: repository);

    await _submitQuestion(tester, 'How is inflation affecting Pakistan?');
    await tester.pumpAndSettle();

    // Data status is visible and honest.
    expect(find.text('Live economic data'), findsOneWidget);

    // Key numbers from the backend metrics.
    expect(find.text('KEY NUMBERS'), findsOneWidget);
    expect(find.text('3.5%'), findsOneWidget);
    expect(find.text('11%'), findsOneWidget);
    expect(find.text('278.4'), findsOneWidget);

    // Sources render from the backend.
    expect(find.text('World Bank API (FP.CPI.TOTL.ZG)'), findsOneWidget);

    // No scenario card on live answers.
    expect(find.text('What-If Scenario'), findsNothing);
  });

  testWidgets('unavailable data status renders its own label', (tester) async {
    final repository = _ScriptedRepository(_apiReply({
      'answer': 'Economic data is temporarily unavailable.',
      'intent': 'economic_intelligence',
      'provider': 'groq',
      'sources': [],
      'dataStatus': 'unavailable',
    }));
    await _pumpScreen(tester, repository: repository);

    await _submitQuestion(tester, 'How is inflation affecting Pakistan?');
    await tester.pumpAndSettle();

    expect(find.text('Live data currently unavailable'), findsOneWidget);
  });

  testWidgets('API failures show a friendly, retryable error (10)',
      (tester) async {
    final repository = _ScriptedRepository(null);
    await _pumpScreen(tester, repository: repository);

    await _submitQuestion(tester, 'Any question?');
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Unable to reach Tadbeer right now. Please check your connection and try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    // No stack traces or exception details anywhere.
    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .toList();
    expect(
      rendered.any((text) =>
          text.contains('Exception') ||
          text.contains('DioException') ||
          text.contains('Socket')),
      isFalse,
    );
  });

  testWidgets('guided What-If input builds and sends the question (13)',
      (tester) async {
    final repository = _ScriptedRepository(_apiReply(_saveMoreBody()));
    await _pumpScreen(tester, repository: repository);

    // Open the guided sheet from the input bar.
    await tester.tap(find.byTooltip('What-If'));
    await tester.pumpAndSettle();

    expect(find.text('Build a What-If question'), findsOneWidget);

    // Fill the guided amount field (first field in the sheet — the save-more
    // family also shows an optional months field after it).
    final sheetField = find
        .descendant(
            of: find.byType(BottomSheet), matching: find.byType(TextField))
        .first;
    await tester.enterText(sheetField, '5000');
    await tester.tap(find.text('Run What-If'));
    await tester.pumpAndSettle();

    // The sheet closed and its natural-language question was sent.
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      repository.calls.single.question,
      'What if I save PKR 5000 more every month?',
    );
    // It flowed through the chat as a normal user message.
    expect(
        find.text('What if I save PKR 5000 more every month?'), findsOneWidget);
  });

  testWidgets('guided What-If validates before sending (13)', (tester) async {
    final repository = _ScriptedRepository(_apiReply(_saveMoreBody()));
    await _pumpScreen(tester, repository: repository);

    await tester.tap(find.byTooltip('What-If'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Run What-If'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets('Roman Urdu submission reaches the repository (17)',
      (tester) async {
    final repository = _ScriptedRepository(_apiReply(_liveEconomyBody()));
    await _pumpScreen(
      tester,
      repository: repository,
      locale: const Locale.fromSubtags(languageCode: 'ur', scriptCode: 'Latn'),
    );

    await _submitQuestion(tester, 'Mehngai kya hai?');
    await tester.pumpAndSettle();

    expect(repository.calls.single.question, 'Mehngai kya hai?');
    expect(repository.calls.single.language, 'ur_latn');
  });

  testWidgets('Urdu script submission reaches the repository (18)',
      (tester) async {
    final repository = _ScriptedRepository(_apiReply(_liveEconomyBody()));
    await _pumpScreen(
      tester,
      repository: repository,
      locale: const Locale('ur'),
    );

    await _submitQuestion(tester, 'مہنگائی کیا ہے؟');
    await tester.pumpAndSettle();

    expect(repository.calls.single.question, 'مہنگائی کیا ہے؟');
    expect(repository.calls.single.language, 'ur');
  });

  testWidgets('loading state shows the typing indicator (19)', (tester) async {
    final repository = _ScriptedRepository(
      _apiReply(_liveEconomyBody()),
      delay: const Duration(milliseconds: 200),
    );
    await _pumpScreen(tester, repository: repository);

    await _submitQuestion(tester, 'How is inflation affecting Pakistan?');

    // While pending: the typing indicator is visible and input is guarded.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Tadbeer is typing…'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Tadbeer is typing…'), findsNothing);
    expect(find.text('Inflation is cooling but remains a pressure on budgets.'),
        findsOneWidget);
  });
}

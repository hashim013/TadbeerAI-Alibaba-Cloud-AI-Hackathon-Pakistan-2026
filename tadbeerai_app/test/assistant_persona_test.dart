import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/data/repositories/mock_assistant_repository.dart';
import 'package:tadbeerai/domain/entities/assistant_message.dart';
import 'package:tadbeerai/domain/entities/financial_profile.dart';
import 'package:tadbeerai/domain/repositories/assistant_repository.dart';

/// Tests that verify the Financial Profile → AssistantContext → mock assistant
/// pipeline:
///
/// * profile fields flow into [AssistantContext]
/// * existing finance / economic fields remain functional
/// * each persona produces a distinct, relevant perspective
/// * no profile preserves the original (non-personalized) behavior
/// * the existing [AssistantReply] contract is untouched
void main() {
  late MockAssistantRepository repository;

  setUp(() {
    repository = MockAssistantRepository(latency: Duration.zero);
  });

  // ── Base context without profile (mirrors Phase-2 demo profile) ──────────
  const baseContext = AssistantContext(
    monthlyIncome: 80000,
    monthlyExpenses: 65000,
    monthlySavings: 15000,
    discretionarySpending: 10100,
    savingsRate: 0.1875,
    healthScore: 76,
    emergencyMonths: 3.0,
    overBudgetCategories: ['transport', 'shopping'],
    budgetLimitTotal: 65500,
    budgetedSpent: 65000,
    goalCount: 4,
    goalAverageProgress: 0.3375,
    topGoalTitle: 'Emergency Fund',
    topGoalProgress: 0.60,
    topGoalRequiredMonthly: 12000,
    inflationRate: 11.2,
    usdPkrRate: 278.5,
    usdPkrChange: 1.2,
    kiborRate: 20.3,
  );

  // Helper to build a context with a specific persona but same finance/economy.
  AssistantContext withPersona(
    Persona persona, {
    double? income,
    double? expenses,
    PrimaryGoal? goal,
  }) {
    return AssistantContext(
      monthlyIncome: baseContext.monthlyIncome,
      monthlyExpenses: baseContext.monthlyExpenses,
      monthlySavings: baseContext.monthlySavings,
      discretionarySpending: baseContext.discretionarySpending,
      savingsRate: baseContext.savingsRate,
      healthScore: baseContext.healthScore,
      emergencyMonths: baseContext.emergencyMonths,
      overBudgetCategories: baseContext.overBudgetCategories,
      budgetLimitTotal: baseContext.budgetLimitTotal,
      budgetedSpent: baseContext.budgetedSpent,
      goalCount: baseContext.goalCount,
      goalAverageProgress: baseContext.goalAverageProgress,
      topGoalTitle: baseContext.topGoalTitle,
      topGoalProgress: baseContext.topGoalProgress,
      topGoalRequiredMonthly: baseContext.topGoalRequiredMonthly,
      inflationRate: baseContext.inflationRate,
      usdPkrRate: baseContext.usdPkrRate,
      usdPkrChange: baseContext.usdPkrChange,
      kiborRate: baseContext.kiborRate,
      persona: persona,
      profileIncome: income,
      profileExpenses: expenses,
      primaryGoal: goal,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 1-2  AssistantContext profile + existing fields
  // ═══════════════════════════════════════════════════════════════════════

  group('AssistantContext carries FinancialProfile information', () {
    test('optional profile fields are populated when provided', () {
      final ctx = withPersona(
        Persona.salaried,
        income: 120000,
        expenses: 50000,
        goal: PrimaryGoal.emergencyFund,
      );

      expect(ctx.persona, Persona.salaried);
      expect(ctx.profileIncome, 120000);
      expect(ctx.profileExpenses, 50000);
      expect(ctx.primaryGoal, PrimaryGoal.emergencyFund);
    });

    test('optional profile fields default to null', () {
      expect(baseContext.persona, isNull);
      expect(baseContext.profileIncome, isNull);
      expect(baseContext.profileExpenses, isNull);
      expect(baseContext.primaryGoal, isNull);
    });

    test('existing finance fields are preserved alongside profile', () {
      final ctx = withPersona(Persona.student, income: 30000);

      // Finance fields unchanged
      expect(ctx.monthlyIncome, 80000);
      expect(ctx.monthlyExpenses, 65000);
      expect(ctx.monthlySavings, 15000);
      expect(ctx.discretionarySpending, 10100);
      expect(ctx.savingsRate, 0.1875);
      expect(ctx.healthScore, 76);
      expect(ctx.emergencyMonths, 3.0);
      expect(ctx.overBudgetCategories, ['transport', 'shopping']);
      expect(ctx.budgetLimitTotal, 65500);
      expect(ctx.budgetedSpent, 65000);
    });

    test('existing economic fields are preserved alongside profile', () {
      final ctx = withPersona(Persona.businessOwner);

      expect(ctx.inflationRate, 11.2);
      expect(ctx.usdPkrRate, 278.5);
      expect(ctx.usdPkrChange, 1.2);
      expect(ctx.kiborRate, 20.3);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3-6  Each persona reaches the assistant
  // ═══════════════════════════════════════════════════════════════════════

  group('persona reaches the assistant', () {
    test('Student profile reaches the assistant', () async {
      final ctx = withPersona(Persona.student);
      final reply =
          await repository.respond('How am I doing financially?', ctx);
      expect(reply.params.containsKey('personaPerspective'), isTrue);
    });

    test('Salaried Employee profile reaches the assistant', () async {
      final ctx = withPersona(Persona.salaried);
      final reply =
          await repository.respond('How am I doing financially?', ctx);
      expect(reply.params.containsKey('personaPerspective'), isTrue);
    });

    test('Business Owner profile reaches the assistant', () async {
      final ctx = withPersona(Persona.businessOwner);
      final reply =
          await repository.respond('How am I doing financially?', ctx);
      expect(reply.params.containsKey('personaPerspective'), isTrue);
    });

    test('Shop Owner profile reaches the assistant', () async {
      final ctx = withPersona(Persona.shopOwner);
      final reply =
          await repository.respond('How am I doing financially?', ctx);
      expect(reply.params.containsKey('personaPerspective'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 7-10  Persona responses are appropriately different
  // ═══════════════════════════════════════════════════════════════════════

  group('persona-specific perspective content', () {
    test('Student perspective mentions student-relevant advice', () async {
      final ctx = withPersona(Persona.student);
      final reply =
          await repository.respond('What can I do to save more?', ctx);
      final perspective = reply.params['personaPerspective']!;

      expect(perspective, contains('student'));
      expect(perspective, contains('financial buffer'));
    });

    test('Salaried Employee perspective mentions income & expenses', () async {
      final ctx = withPersona(Persona.salaried);
      final reply =
          await repository.respond('What can I do to save more?', ctx);
      final perspective = reply.params['personaPerspective']!;

      expect(perspective, contains('income'));
      expect(perspective, contains('essential expenses'));
      expect(perspective, contains('emergency fund'));
    });

    test('Business Owner perspective mentions variable income', () async {
      final ctx = withPersona(Persona.businessOwner);
      final reply =
          await repository.respond('What can I do to save more?', ctx);
      final perspective = reply.params['personaPerspective']!;

      expect(perspective, contains('business income'));
      expect(perspective, contains('cash buffer'));
      expect(perspective, contains('slower months'));
    });

    test('Shop Owner perspective mentions shop-relevant concerns', () async {
      final ctx = withPersona(Persona.shopOwner);
      final reply =
          await repository.respond('What can I do to save more?', ctx);
      final perspective = reply.params['personaPerspective']!;

      expect(perspective, contains('shop'));
      expect(perspective, contains('daily expenses'));
      expect(perspective, contains('working capital'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 11  Same question → persona-specific contextual output
  // ═══════════════════════════════════════════════════════════════════════

  group('same question produces persona-differentiated output', () {
    test('inflation question yields four distinct perspectives', () async {
      const question = 'How is inflation affecting me?';

      final studentReply =
          await repository.respond(question, withPersona(Persona.student));
      final salariedReply =
          await repository.respond(question, withPersona(Persona.salaried));
      final businessReply = await repository.respond(
          question, withPersona(Persona.businessOwner));
      final shopReply =
          await repository.respond(question, withPersona(Persona.shopOwner));

      final perspectives = {
        studentReply.params['personaPerspective'],
        salariedReply.params['personaPerspective'],
        businessReply.params['personaPerspective'],
        shopReply.params['personaPerspective'],
      };

      // All four are different
      expect(perspectives.length, 4,
          reason: 'each persona must produce a unique perspective');
    });

    test('all personas still get the same base intent for the same question',
        () async {
      const question = 'How is inflation affecting me?';

      final studentReply =
          await repository.respond(question, withPersona(Persona.student));
      final salariedReply =
          await repository.respond(question, withPersona(Persona.salaried));

      // Same intent
      expect(studentReply.intent, AssistantIntent.inflation);
      expect(salariedReply.intent, AssistantIntent.inflation);

      // Same base finance params
      expect(
          studentReply.params['inflation'], salariedReply.params['inflation']);
      expect(studentReply.params['essentials'],
          salariedReply.params['essentials']);

      // Different persona perspective
      expect(studentReply.params['personaPerspective'],
          isNot(salariedReply.params['personaPerspective']));
    });

    test('persona perspective is attached to any intent, not just one',
        () async {
      final ctx = withPersona(Persona.student);

      final inflationReply =
          await repository.respond('How is inflation affecting me?', ctx);
      final savingsReply =
          await repository.respond('What can I do to save more?', ctx);
      final healthReply =
          await repository.respond('How am I doing financially?', ctx);
      final generalReply =
          await repository.respond("Explain today's economy simply.", ctx);

      // Every reply carries the same student perspective
      for (final reply in [
        inflationReply,
        savingsReply,
        healthReply,
        generalReply
      ]) {
        expect(reply.params['personaPerspective'], contains('student'));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 12  No profile → existing behavior preserved
  // ═══════════════════════════════════════════════════════════════════════

  group('no completed profile preserves existing behavior', () {
    test('reply has no personaPerspective param when no persona', () async {
      final reply =
          await repository.respond('How am I doing financially?', baseContext);

      expect(reply.params.containsKey('personaPerspective'), isFalse);
    });

    test('base finance params are identical with and without profile',
        () async {
      final noProfile =
          await repository.respond('How am I doing financially?', baseContext);
      final withProfile = await repository.respond(
        'How am I doing financially?',
        withPersona(Persona.student),
      );

      // All non-persona params must be identical
      for (final key in noProfile.params.keys) {
        if (key == 'personaPerspective') continue;
        expect(withProfile.params[key], noProfile.params[key],
            reason: 'base param "$key" must not change with persona');
      }
    });

    test('no persona: existing intents and follow-ups are unchanged', () async {
      final reply = await repository.respond(
          'How is inflation affecting me?', baseContext);

      expect(reply.intent, AssistantIntent.inflation);
      expect(reply.followUps, isNotEmpty);
      expect(reply.confidence, greaterThan(0.8));
      expect(reply.params.containsKey('personaPerspective'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 13  Existing financial insights still work
  // ═══════════════════════════════════════════════════════════════════════

  test('existing financial insights work with a persona present', () async {
    final ctx = withPersona(
      Persona.salaried,
      income: 120000,
      expenses: 50000,
      goal: PrimaryGoal.saveMore,
    );

    // Inflation
    final inflation =
        await repository.respond('How is inflation affecting me?', ctx);
    expect(inflation.params['inflation'], '11.2');

    // Savings
    final savings =
        await repository.respond('What can I do to save more?', ctx);
    expect(savings.params['savings'], 'Rs 15,000');

    // Budget
    final budget = await repository.respond('How is my budget doing?', ctx);
    expect(budget.params['spent'], 'Rs 65,000');

    // Health
    final health = await repository.respond('How am I doing financially?', ctx);
    expect(health.params['score'], '76');

    // Goals
    final goals = await repository.respond(
        'How can I reach my savings goal faster?', ctx);
    expect(goals.params['topGoal'], 'Emergency Fund');
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 14  Financial Health calculation remains unchanged
  // ═══════════════════════════════════════════════════════════════════════

  test('Financial Health score passes through unchanged regardless of persona',
      () async {
    // Same health score reaches the reply with every persona
    for (final persona in Persona.values) {
      final ctx = withPersona(persona);
      final reply =
          await repository.respond('How am I doing financially?', ctx);
      expect(reply.params['score'], '76',
          reason: 'persona ${persona.name} must not alter health score');
    }
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 15  AssistantReply contract remains compatible
  // ═══════════════════════════════════════════════════════════════════════

  group('AssistantReply contract compatibility', () {
    test('reply with persona still has intent, params, followUps, confidence',
        () async {
      final ctx = withPersona(Persona.salaried);
      final reply =
          await repository.respond('How am I doing financially?', ctx);

      expect(reply.intent, isNotNull);
      expect(reply.params, isA<Map<String, String>>());
      expect(reply.followUps, isA<List<AssistantIntent>>());
      expect(reply.confidence, isA<double>());
    });

    test('reply without persona has same structural shape', () async {
      final reply =
          await repository.respond('How am I doing financially?', baseContext);

      expect(reply.intent, isNotNull);
      expect(reply.params, isA<Map<String, String>>());
      expect(reply.followUps, isA<List<AssistantIntent>>());
      expect(reply.confidence, isA<double>());
    });

    test('personaPerspective is delivered through params map, not a new field',
        () async {
      final ctx = withPersona(Persona.student);
      final reply =
          await repository.respond('How am I doing financially?', ctx);

      // It's a regular param, not a new structural field
      expect(reply.params['personaPerspective'], isA<String>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 16  FinancialProfileRepository usage (architectural safety)
  // ═══════════════════════════════════════════════════════════════════════

  test(
      'assistant context accepts profile data through its fields, '
      'not through direct SharedPreferences', () {
    // Architectural: AssistantContext carries profile data through its
    // typed optional fields (persona, profileIncome, profileExpenses,
    // primaryGoal), which are populated by assistantContextProvider
    // watching FinancialProfileRepository.
    final ctx = withPersona(
      Persona.salaried,
      income: 100000,
      expenses: 40000,
      goal: PrimaryGoal.emergencyFund,
    );

    // Data is accessed through typed fields, not string keys or prefs
    expect(ctx.persona, isA<Persona>());
    expect(ctx.profileIncome, isA<double>());
    expect(ctx.profileExpenses, isA<double>());
    expect(ctx.primaryGoal, isA<PrimaryGoal>());
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 17  Determinism preserved with persona
  // ═══════════════════════════════════════════════════════════════════════

  test('persona-aware replies are deterministic', () async {
    final ctx = withPersona(Persona.businessOwner);

    final first = await repository.respond('What can I do to save more?', ctx);
    final second = await repository.respond('What can I do to save more?', ctx);

    expect(second.params, first.params);
    expect(second.followUps, first.followUps);
    expect(second.confidence, first.confidence);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/data/repositories/mock_assistant_repository.dart';
import 'package:tadbeerai/domain/entities/assistant_message.dart';
import 'package:tadbeerai/domain/repositories/assistant_repository.dart';
import 'package:tadbeerai/domain/services/assistant_intents.dart';

/// Tests for the deterministic mock assistant: the suggested starter
/// questions route to the right intent, and every reply interpolates exactly
/// the numbers the Finance and Economy tabs show — the assistant never
/// invents a second financial profile.
void main() {
  // Mirrors assistantContextProvider over the Phase-2 demo profile:
  // Rs 80,000 income / Rs 65,000 expenses / Rs 15,000 savings, health 76,
  // transport + shopping over budget, Emergency Fund 60% funded, and the
  // Phase-3 economic snapshot (inflation 11.2%, USD/PKR 278.50, KIBOR 20.3).
  const context = AssistantContext(
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

  late MockAssistantRepository repository;

  setUp(() {
    repository = MockAssistantRepository(latency: Duration.zero);
  });

  group('intent detection routes the suggested questions', () {
    final cases = <String, AssistantIntent>{
      'How is inflation affecting me?': AssistantIntent.inflation,
      'What can I do to save more?': AssistantIntent.savings,
      'What is KIBOR?': AssistantIntent.kibor,
      'What happens if my income drops by 10%?': AssistantIntent.incomeDrop,
      'Why does the dollar rate matter to me?': AssistantIntent.currency,
      'How am I doing financially?': AssistantIntent.health,
      'How can I reach my savings goal faster?': AssistantIntent.goals,
      "Explain today's economy simply.": AssistantIntent.general,
    };

    for (final entry in cases.entries) {
      test('"${entry.key}" → ${entry.value.name}', () {
        expect(AssistantIntents.detect(entry.key), entry.value);
      });
    }

    test('supporting prompts and romanized Urdu route correctly too', () {
      expect(AssistantIntents.detect('How is my budget doing?'),
          AssistantIntent.budget);
      expect(AssistantIntents.detect('How is the market doing?'),
          AssistantIntent.market);
      expect(
        AssistantIntents.detect('Mehngai barh rahi hai?'),
        AssistantIntent.inflation, // romanized "inflation"
      );
      expect(AssistantIntents.detect('Bachat kaise barhaoon?'),
          AssistantIntent.savings); // romanized "savings"
      expect(AssistantIntents.detect('Dollar ka rate kya hai?'),
          AssistantIntent.currency);
    });

    test('"goal" wins over "savings" and "drop" wins over "income"', () {
      // Priority is part of the contract: "savings goal" is a goals question.
      expect(AssistantIntents.detect('How can I reach my savings goal faster?'),
          AssistantIntent.goals);
      // …and "income drops" is a scenario question before it is a health one.
      expect(AssistantIntents.detect('What happens if my income drops by 10%?'),
          AssistantIntent.incomeDrop);
    });
  });

  group('replies', () {
    test('inflation answer quotes the impact-engine numbers', () async {
      final reply =
          await repository.respond('How is inflation affecting me?', context);

      expect(reply.intent, AssistantIntent.inflation);
      expect(reply.params['inflation'], '11.2');
      expect(reply.params['essentials'], 'Rs 54,900');
      expect(reply.params['pressure'], 'Rs 1,098');
      expect(reply.params['capacity'], 'Rs 13,902');
      expect(reply.confidence, greaterThan(0.8));
    });

    test('savings answer references budget overruns deterministically',
        () async {
      final reply =
          await repository.respond('What can I do to save more?', context);

      expect(reply.intent, AssistantIntent.savings);
      expect(reply.params['savings'], 'Rs 15,000');
      expect(reply.params['rate'], '18.8');
      expect(reply.params['overCount'], '2');
      expect(reply.params['overCategories'], 'transport, shopping');
      expect(reply.params['reduction'], 'Rs 2,000');
      expect(reply.params['newSavings'], 'Rs 17,000');
      expect(reply.followUps, containsAll([AssistantIntent.budget]));
    });

    test('budget answer quotes spending against the total limit', () async {
      final reply =
          await repository.respond('How is my budget doing?', context);

      expect(reply.intent, AssistantIntent.budget);
      expect(reply.params['spent'], 'Rs 65,000');
      expect(reply.params['limit'], 'Rs 65,500');
      expect(reply.params['overCount'], '2');
    });

    test('health answer quotes the Financial Health Score inputs', () async {
      final reply =
          await repository.respond('How am I doing financially?', context);

      expect(reply.intent, AssistantIntent.health);
      expect(reply.params['score'], '76');
      expect(reply.params['rate'], '18.8');
      expect(reply.params['months'], '3.0');
    });

    test('goals answer names the top goal and its required monthly saving',
        () async {
      final reply = await repository.respond(
          'How can I reach my savings goal faster?', context);

      expect(reply.intent, AssistantIntent.goals);
      expect(reply.params['count'], '4');
      expect(reply.params['percent'], '34');
      expect(reply.params['topGoal'], 'Emergency Fund');
      expect(reply.params['topPercent'], '60');
      expect(reply.params['requiredMonthly'], 'Rs 12,000');
    });

    test('KIBOR answer is educational and quotes the demo rate', () async {
      final reply = await repository.respond('What is KIBOR?', context);

      expect(reply.intent, AssistantIntent.kibor);
      expect(reply.params['kibor'], '20.3');
      expect(reply.params['loanExample'], 'Rs 500,000');
      expect(reply.params['perPoint'], 'Rs 5,000');
    });

    test('currency answer quotes the demo exchange rate and change', () async {
      final reply = await repository.respond(
          'Why does the dollar rate matter to me?', context);

      expect(reply.intent, AssistantIntent.currency);
      expect(reply.params['rate'], '278.50');
      expect(reply.params['change'], '+1.20');
    });

    test('income-drop scenario runs the deterministic -10% arithmetic',
        () async {
      final reply = await repository.respond(
          'What happens if my income drops by 10%?', context);

      expect(reply.intent, AssistantIntent.incomeDrop);
      expect(reply.params['newIncome'], 'Rs 72,000');
      expect(reply.params['newSavings'], 'Rs 7,000');
      expect(reply.params['newRate'], '9.7');
      expect(reply.params['cut'], 'Rs 3,030'); // 30% of Rs 10,100 wants
      expect(reply.params['restored'], 'Rs 10,030');
    });

    test('general answer summarizes the demo economy snapshot', () async {
      final reply =
          await repository.respond("Explain today's economy simply.", context);

      expect(reply.intent, AssistantIntent.general);
      expect(reply.params['inflation'], '11.2');
      expect(reply.params['rate'], '278.50');
      expect(reply.params['change'], '+1.20');
      expect(reply.params['kibor'], '20.3');
    });

    test('market answer is an honest not-in-demo-yet reply', () async {
      final reply =
          await repository.respond('How is the market doing?', context);

      expect(reply.intent, AssistantIntent.market);
      expect(reply.params, isEmpty);
      expect(reply.confidence, lessThan(0.8)); // honestly lower confidence
    });
  });

  group('context-driven answers (no second profile)', () {
    test('a different context produces different numbers', () async {
      const richer = AssistantContext(
        monthlyIncome: 120000,
        monthlyExpenses: 90000,
        monthlySavings: 30000,
        discretionarySpending: 15000,
        savingsRate: 0.25,
        healthScore: 82,
        emergencyMonths: 6.0,
        overBudgetCategories: [],
        budgetLimitTotal: 92000,
        budgetedSpent: 90000,
        goalCount: 1,
        goalAverageProgress: 0.5,
        topGoalTitle: 'Wedding',
        topGoalProgress: 0.5,
        topGoalRequiredMonthly: 25000,
        inflationRate: 9.0,
        usdPkrRate: 270.0,
        usdPkrChange: -0.5,
        kiborRate: 18.0,
      );

      final savings =
          await repository.respond('What can I do to save more?', richer);
      expect(savings.params['savings'], 'Rs 30,000');
      expect(savings.params['rate'], '25.0');
      expect(savings.params['overCount'], '0');

      final currency =
          await repository.respond('Why does the dollar rate matter?', richer);
      expect(currency.params['rate'], '270.00');
      expect(currency.params['change'], '-0.50');
    });

    test('a goal-free context still answers with count zero', () async {
      const goalless = AssistantContext(
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
        goalCount: 0,
        goalAverageProgress: 0,
        topGoalTitle: '',
        topGoalProgress: 0,
        topGoalRequiredMonthly: 0,
        inflationRate: 11.2,
        usdPkrRate: 278.5,
        usdPkrChange: 1.2,
        kiborRate: 20.3,
      );

      final reply = await repository.respond(
          'How can I reach my savings goal faster?', goalless);

      expect(reply.intent, AssistantIntent.goals);
      expect(reply.params['count'], '0');
    });
  });

  test('answers are identical across repeated asks (deterministic)', () async {
    final first = await repository.respond('What is KIBOR?', context);
    final second = await repository.respond('What is KIBOR?', context);

    expect(second.params, first.params);
    expect(second.followUps, first.followUps);
    expect(second.confidence, first.confidence);
  });
}

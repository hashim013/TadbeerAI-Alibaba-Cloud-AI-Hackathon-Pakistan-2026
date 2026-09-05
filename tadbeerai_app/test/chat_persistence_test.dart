import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/core/constants/app_constants.dart';
import 'package:tadbeerai/domain/entities/assistant_api_models.dart';
import 'package:tadbeerai/domain/entities/assistant_message.dart';
import 'package:tadbeerai/domain/repositories/assistant_repository.dart';
import 'package:tadbeerai/providers/assistant_providers.dart';
import 'package:tadbeerai/providers/repository_providers.dart';

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

class _FakeAssistantRepo implements AssistantRepository {
  @override
  Future<AssistantReply> respond(
    String question,
    AssistantContext context, {
    String language = 'en',
  }) async {
    return const AssistantReply(
      intent: AssistantIntent.general,
      params: {'key': 'value'},
      followUps: [AssistantIntent.savings],
      confidence: 0.95,
      api: AssistantApiReply(
        answer: 'Here is financial advice based on your numbers.',
        intent: 'savings',
        language: 'en',
        provider: 'groq',
        agentsUsed: ['personal_finance'],
        metrics: {'runway_months': 3.6},
        recommendations: ['Keep building savings'],
        sources: ['SBP'],
        dataStatus: DataStatusKind.live,
        scenario: null,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chat messages are saved to and restored from SharedPreferences',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeAssistantRepo();

    // Container 1: send a message
    final container1 = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        assistantContextProvider.overrideWithValue(_context),
        assistantRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container1.dispose);

    await container1
        .read(assistantChatProvider.notifier)
        .send('What is my current runway?');

    final state1 = container1.read(assistantChatProvider);
    expect(state1.messages, hasLength(2));
    expect(state1.messages.first.role, ChatRole.user);
    expect(state1.messages.first.text, 'What is my current runway?');
    expect(state1.messages.last.role, ChatRole.assistant);
    expect(state1.messages.last.reply?.api?.answer,
        'Here is financial advice based on your numbers.');

    // Verify written to SharedPreferences
    final storedJson = prefs.getString(AppConstants.prefChatHistory);
    expect(storedJson, isNotNull);
    expect(storedJson, contains('What is my current runway?'));
    expect(storedJson, contains('Here is financial advice based on your numbers.'));

    // Container 2 (simulating app restart with same SharedPreferences)
    final container2 = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        assistantContextProvider.overrideWithValue(_context),
        assistantRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container2.dispose);

    final state2 = container2.read(assistantChatProvider);
    expect(state2.messages, hasLength(2));
    expect(state2.messages.first.role, ChatRole.user);
    expect(state2.messages.first.text, 'What is my current runway?');
    expect(state2.messages.last.role, ChatRole.assistant);
    expect(state2.messages.last.reply?.api?.answer,
        'Here is financial advice based on your numbers.');
  });

  test('clear() empties state and removes prefChatHistory from preferences',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeAssistantRepo();

    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        assistantContextProvider.overrideWithValue(_context),
        assistantRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(assistantChatProvider.notifier)
        .send('Hello Tadbeer');

    expect(prefs.getString(AppConstants.prefChatHistory), isNotNull);

    container.read(assistantChatProvider.notifier).clear();

    expect(container.read(assistantChatProvider).messages, isEmpty);
    expect(prefs.getString(AppConstants.prefChatHistory), isNull);
  });
}

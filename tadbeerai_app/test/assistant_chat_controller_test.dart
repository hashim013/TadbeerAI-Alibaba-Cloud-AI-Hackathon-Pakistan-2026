import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/domain/entities/assistant_api_models.dart';
import 'package:tadbeerai/domain/entities/assistant_message.dart';
import 'package:tadbeerai/domain/repositories/assistant_repository.dart';
import 'package:tadbeerai/providers/assistant_providers.dart';

/// AssistantChatController tests: loading state, language forwarding,
/// retry and error-kind mapping (spec cases 10, 11, 17, 18, 19).

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

class _FakeRepository implements AssistantRepository {
  _FakeRepository({this.delay = Duration.zero, this.error});

  final Duration delay;

  /// Mutable so a test can flip the repository between failing and working.
  Object? error;

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
    if (error != null) throw error!;
    return const AssistantReply(
      intent: AssistantIntent.general,
      params: {},
      followUps: [],
      confidence: 1,
    );
  }
}

ProviderContainer _container(_FakeRepository repository) => ProviderContainer(
      overrides: [
        assistantContextProvider.overrideWithValue(_context),
        assistantRepositoryProvider.overrideWithValue(repository),
      ],
    );

void main() {
  test('shows the loading state while the reply is pending (case 19)',
      () async {
    final repository = _FakeRepository(delay: const Duration(milliseconds: 30));
    final container = _container(repository);
    addTearDown(container.dispose);

    final future = container
        .read(assistantChatProvider.notifier)
        .send('How am I doing financially?');

    final state = container.read(assistantChatProvider);
    expect(state.isResponding, isTrue);
    // The user's bubble appears immediately; the typing indicator follows.
    expect(state.messages, hasLength(1));
    expect(state.messages.single.role, ChatRole.user);

    await future;

    final done = container.read(assistantChatProvider);
    expect(done.isResponding, isFalse);
    expect(done.lastError, isFalse);
    expect(done.messages, hasLength(2));
    expect(done.messages.last.role, ChatRole.assistant);
  });

  test('guards duplicate submissions while responding', () async {
    final repository = _FakeRepository(delay: const Duration(milliseconds: 30));
    final container = _container(repository);
    addTearDown(container.dispose);

    final first =
        container.read(assistantChatProvider.notifier).send('First question');
    // Second send is ignored while the first is in flight.
    await container.read(assistantChatProvider.notifier).send('Second');
    await first;

    expect(repository.calls, hasLength(1));
    expect(repository.calls.single.question, 'First question');
  });

  test('forwards the language code with the question (cases 17, 18)', () async {
    final repository = _FakeRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    await container
        .read(assistantChatProvider.notifier)
        .send('Mehngai kya hai?', language: 'ur_latn');
    await container
        .read(assistantChatProvider.notifier)
        .send('مہنگائی کیا ہے؟', language: 'ur');

    expect(
      repository.calls.map((call) => call.language),
      ['ur_latn', 'ur'],
    );
  });

  test('network failures surface their error kind (case 10)', () async {
    final repository = _FakeRepository(
        error: const AssistantApiException(AssistantErrorKind.network));
    final container = _container(repository);
    addTearDown(container.dispose);

    await container
        .read(assistantChatProvider.notifier)
        .send('How am I doing financially?');

    final state = container.read(assistantChatProvider);
    expect(state.isResponding, isFalse);
    expect(state.lastError, isTrue);
    expect(state.errorKind, AssistantErrorKind.network);
  });

  test('timeout failures surface their error kind (case 11)', () async {
    final repository = _FakeRepository(
        error: const AssistantApiException(AssistantErrorKind.timeout));
    final container = _container(repository);
    addTearDown(container.dispose);

    await container.read(assistantChatProvider.notifier).send('Any question');

    expect(container.read(assistantChatProvider).errorKind,
        AssistantErrorKind.timeout);
  });

  test('retry re-asks the last question with its original language', () async {
    final repository = _FakeRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    await container
        .read(assistantChatProvider.notifier)
        .send('پہلا سوال', language: 'ur');

    // Make the next ask fail, then retry.
    repository.error = const AssistantApiException(AssistantErrorKind.server);
    await container
        .read(assistantChatProvider.notifier)
        .send('دوسرا سوال', language: 'ur');
    expect(container.read(assistantChatProvider).lastError, isTrue);

    repository.error = null;
    await container.read(assistantChatProvider.notifier).retry();

    // retry re-asked 'دوسرا سوال' — not the earlier question — in Urdu.
    expect(repository.calls.last.question, 'دوسرا سوال');
    expect(repository.calls.last.language, 'ur');
    expect(container.read(assistantChatProvider).lastError, isFalse);
  });

  test('a successful ask clears the error state', () async {
    final repository = _FakeRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    repository.error = const AssistantApiException(AssistantErrorKind.server);
    await container.read(assistantChatProvider.notifier).send('Failing');
    expect(container.read(assistantChatProvider).lastError, isTrue);

    repository.error = null;
    await container.read(assistantChatProvider.notifier).send('Working');
    final state = container.read(assistantChatProvider);
    expect(state.lastError, isFalse);
    expect(state.errorKind, isNull);
  });
}

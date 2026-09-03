import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/mock_assistant_repository.dart';
import '../domain/entities/assistant_message.dart';
import '../domain/entities/finance_category.dart';
import '../domain/entities/goal.dart';
import '../domain/repositories/assistant_repository.dart';
import '../domain/services/finance_calculations.dart';
import 'economic_providers.dart';
import 'finance_providers.dart';
import 'profile_providers.dart';

final assistantRepositoryProvider = Provider<AssistantRepository>(
  (ref) => MockAssistantRepository(),
);

/// The financial + economic position the assistant answers from.
///
/// Returns null while either source is still loading or has failed — the chat
/// UI then keeps input disabled so the assistant never answers from invented
/// numbers.
final assistantContextProvider = Provider<AssistantContext?>((ref) {
  final finance = ref.watch(financeControllerProvider).value;
  final economy = ref.watch(economicPulseProvider).value;
  final health = ref.watch(financialHealthProvider);
  final profile = ref.watch(financialProfileControllerProvider).valueOrNull;
  // Only use profile data when the profile has been explicitly completed.
  final completedProfile = profile?.profileCompleted == true ? profile : null;
  if (finance == null || economy == null) return null;

  final now = DateTime.now();
  final income = FinanceCalculations.monthlyIncome(finance.transactions, now);
  final expenses =
      FinanceCalculations.monthlyExpenses(finance.transactions, now);
  final savings = income - expenses;
  final savingsBalance = FinanceCalculations.currentSavings(
      finance.openingSavingsBalance, finance.transactions);
  final discretionary = FinanceCalculations.discretionarySpending(
      finance.transactions, now, FinanceCategories.discretionaryExpenseIds);
  final spentByCategory =
      FinanceCalculations.spentByCategory(finance.transactions, now);

  final overBudget = <String>[];
  var limitTotal = 0.0;
  var budgetedSpent = 0.0;
  for (final budget in finance.budgets) {
    limitTotal += budget.monthlyLimit;
    final spent = spentByCategory[budget.category] ?? 0;
    budgetedSpent += spent;
    if (spent > budget.monthlyLimit) overBudget.add(budget.category);
  }

  var progressSum = 0.0;
  Goal? topGoal;
  var topProgress = -1.0;
  for (final goal in finance.goals) {
    final status = FinanceCalculations.goalStatus(goal, now);
    progressSum += status.progress;
    if (status.progress > topProgress) {
      topProgress = status.progress;
      topGoal = goal;
    }
  }
  final goalCount = finance.goals.length;
  final topStatus =
      topGoal == null ? null : FinanceCalculations.goalStatus(topGoal, now);

  return AssistantContext(
    monthlyIncome: income,
    monthlyExpenses: expenses,
    monthlySavings: savings,
    discretionarySpending: discretionary,
    savingsRate: income > 0 ? savings / income : 0,
    healthScore: health?.score ?? 0,
    emergencyMonths: expenses > 0 ? savingsBalance / expenses : 0,
    overBudgetCategories: overBudget,
    budgetLimitTotal: limitTotal,
    budgetedSpent: budgetedSpent,
    goalCount: goalCount,
    goalAverageProgress: goalCount > 0 ? progressSum / goalCount : 0,
    topGoalTitle: topGoal?.title ?? '',
    topGoalProgress: topStatus?.progress ?? 0,
    topGoalRequiredMonthly: topStatus?.requiredMonthly ?? 0,
    inflationRate: economy.indicatorById('inflation')?.currentValue ?? 0,
    usdPkrRate: economy.indicatorById('usdPkr')?.currentValue ?? 0,
    usdPkrChange: economy.indicatorById('usdPkr')?.change ?? 0,
    kiborRate: economy.indicatorById('kibor')?.currentValue ?? 0,
    // ── Optional profile fields (only when profile is completed) ──
    persona: completedProfile?.persona,
    profileIncome: completedProfile?.monthlyIncome,
    profileExpenses: completedProfile?.monthlyEssentialExpenses,
    primaryGoal: completedProfile?.primaryGoal,
  );
});

/// Immutable state of the Ask Tadbeer conversation.
class AssistantChatState {
  const AssistantChatState({
    this.messages = const [],
    this.isResponding = false,
    this.lastError = false,
  });

  final List<ChatMessage> messages;

  /// True while a reply is being prepared.
  final bool isResponding;

  /// True when the most recent ask failed; cleared by the next success.
  final bool lastError;

  AssistantChatState copyWith({
    List<ChatMessage>? messages,
    bool? isResponding,
    bool? lastError,
  }) =>
      AssistantChatState(
        messages: messages ?? this.messages,
        isResponding: isResponding ?? this.isResponding,
        lastError: lastError ?? this.lastError,
      );
}

/// Owns the in-memory chat session (session-scoped — not persisted in
/// Phase 3).
class AssistantChatController extends Notifier<AssistantChatState> {
  AssistantRepository get _repo => ref.read(assistantRepositoryProvider);

  @override
  AssistantChatState build() => const AssistantChatState();

  /// Sends the user's question and appends the structured answer.
  Future<void> send(String question) async {
    final text = question.trim();
    if (text.isEmpty || state.isResponding) return;

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.user,
          text: text,
          timestamp: DateTime.now(),
        ),
      ],
      isResponding: true,
      lastError: false,
    );
    await _ask(text);
  }

  /// Re-asks the previous question after a failure, without duplicating the
  /// user's bubble.
  Future<void> retry() async {
    if (state.isResponding) return;
    String? question;
    for (final message in state.messages.reversed) {
      if (message.role == ChatRole.user) {
        question = message.text;
        break;
      }
    }
    if (question == null) return;

    state = state.copyWith(isResponding: true, lastError: false);
    await _ask(question);
  }

  /// Clears the conversation.
  void clear() {
    state = const AssistantChatState();
  }

  Future<void> _ask(String question) async {
    final context = ref.read(assistantContextProvider);
    if (context == null) {
      state = state.copyWith(isResponding: false, lastError: true);
      return;
    }

    try {
      final reply = await _repo.respond(question, context);
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            id: '${DateTime.now().microsecondsSinceEpoch}',
            role: ChatRole.assistant,
            text: '',
            timestamp: DateTime.now(),
            reply: reply,
          ),
        ],
        isResponding: false,
        lastError: false,
      );
    } catch (_) {
      state = state.copyWith(isResponding: false, lastError: true);
    }
  }
}

final assistantChatProvider =
    NotifierProvider<AssistantChatController, AssistantChatState>(
        AssistantChatController.new);

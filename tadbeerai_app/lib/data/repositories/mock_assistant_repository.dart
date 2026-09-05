import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_format.dart';
import '../../domain/entities/assistant_message.dart';
import '../../domain/entities/financial_profile.dart';
import '../../domain/repositories/assistant_repository.dart';
import '../../domain/services/assistant_intents.dart';
import '../../domain/services/economic_impact_service.dart';
import '../mock/mock_economic_data.dart';

/// Deterministic, rule-based assistant used during the mock phase.
///
/// Answers are built from [AssistantContext] — the same Phase-2 finance
/// numbers every other screen shows — so the assistant never invents a
/// second financial profile. Params are pre-formatted display strings that
/// the UI interpolates into localized templates; a real backend replaces
/// this in a later phase without touching the chat UI.
class MockAssistantRepository implements AssistantRepository {
  MockAssistantRepository({
    Duration latency = AppConstants.mockAssistantLatency,
  }) : _latency = latency;

  final Duration _latency;

  /// Share of discretionary spending an income-drop answer trims in its
  /// recovery suggestion.
  static const double _incomeDropTrimShare = 0.30;

  @override
  Future<AssistantReply> respond(
    String question,
    AssistantContext context, {
    String language = 'en',
  }) {
    return Future<AssistantReply>.delayed(_latency, () {
      final intent = AssistantIntents.detect(question);
      final reply = switch (intent) {
        AssistantIntent.inflation => _inflationReply(context),
        AssistantIntent.savings => _savingsReply(context),
        AssistantIntent.budget => _budgetReply(context),
        AssistantIntent.health => _healthReply(context),
        AssistantIntent.goals => _goalsReply(context),
        AssistantIntent.kibor => _kiborReply(context),
        AssistantIntent.currency => _currencyReply(context),
        AssistantIntent.market => _marketReply(),
        AssistantIntent.incomeDrop => _incomeDropReply(context),
        AssistantIntent.general => _generalReply(context),
      };
      // Attach persona perspective when a profile exists.
      final perspective = _personaPerspective(context);
      if (perspective != null) {
        return AssistantReply(
          intent: reply.intent,
          params: {...reply.params, 'personaPerspective': perspective},
          followUps: reply.followUps,
          confidence: reply.confidence,
        );
      }
      return reply;
    });
  }

  // ── Replies ─────────────────────────────────────────────────────────────

  AssistantReply _inflationReply(AssistantContext context) {
    final impact = EconomicImpactService.inflationImpact(
      _impactInput(context),
      inflationDelta: EconomicImpactService.demoInflationDelta,
    );
    return AssistantReply(
      intent: AssistantIntent.inflation,
      params: {
        'inflation': context.inflationRate.toStringAsFixed(1),
        'essentials': CurrencyFormat.pkr(
            context.monthlyExpenses - context.discretionarySpending),
        'pressure': CurrencyFormat.pkr(impact.estimatedMonthlyPressure),
        'capacity': CurrencyFormat.pkr(impact.estimatedSavingsCapacity),
      },
      followUps: const [
        AssistantIntent.kibor,
        AssistantIntent.currency,
        AssistantIntent.savings,
      ],
      confidence: 0.9,
    );
  }

  AssistantReply _savingsReply(AssistantContext context) {
    const suggestion = MockEconomicData.saveMoreSuggestion;
    return AssistantReply(
      intent: AssistantIntent.savings,
      params: {
        'savings': CurrencyFormat.pkr(context.monthlySavings),
        'rate': _percent(context.savingsRate),
        'overCount': '${context.overBudgetCategories.length}',
        'overCategories': context.overBudgetCategories.join(', '),
        'reduction': CurrencyFormat.pkr(suggestion),
        'newSavings': CurrencyFormat.pkr(context.monthlySavings + suggestion),
      },
      followUps: const [AssistantIntent.budget, AssistantIntent.goals],
      confidence: 0.85,
    );
  }

  AssistantReply _budgetReply(AssistantContext context) {
    return AssistantReply(
      intent: AssistantIntent.budget,
      params: {
        'spent': CurrencyFormat.pkr(context.budgetedSpent),
        'limit': CurrencyFormat.pkr(context.budgetLimitTotal),
        'overCount': '${context.overBudgetCategories.length}',
        'overCategories': context.overBudgetCategories.join(', '),
      },
      followUps: const [AssistantIntent.savings, AssistantIntent.health],
      confidence: 0.9,
    );
  }

  AssistantReply _healthReply(AssistantContext context) {
    return AssistantReply(
      intent: AssistantIntent.health,
      params: {
        'score': '${context.healthScore}',
        'rate': _percent(context.savingsRate),
        'months': context.emergencyMonths.toStringAsFixed(1),
      },
      followUps: const [AssistantIntent.savings, AssistantIntent.goals],
      confidence: 0.95,
    );
  }

  AssistantReply _goalsReply(AssistantContext context) {
    return AssistantReply(
      intent: AssistantIntent.goals,
      params: {
        'count': '${context.goalCount}',
        'percent': '${(context.goalAverageProgress * 100).round()}',
        'topGoal': context.topGoalTitle,
        'topPercent': '${(context.topGoalProgress * 100).round()}',
        'requiredMonthly': CurrencyFormat.pkr(context.topGoalRequiredMonthly),
      },
      followUps: const [AssistantIntent.savings, AssistantIntent.health],
      confidence: 0.9,
    );
  }

  AssistantReply _kiborReply(AssistantContext context) {
    return AssistantReply(
      intent: AssistantIntent.kibor,
      params: {
        'kibor': context.kiborRate.toStringAsFixed(1),
        'loanExample': CurrencyFormat.pkr(
            EconomicImpactService.typicalLoanBalance.toDouble()),
        'perPoint':
            CurrencyFormat.pkr(EconomicImpactService.typicalLoanBalance * 0.01),
      },
      followUps: const [AssistantIntent.inflation, AssistantIntent.currency],
      confidence: 0.95,
    );
  }

  AssistantReply _currencyReply(AssistantContext context) {
    final change = context.usdPkrChange;
    final sign = change >= 0 ? '+' : '';
    return AssistantReply(
      intent: AssistantIntent.currency,
      params: {
        'rate': context.usdPkrRate.toStringAsFixed(2),
        'change': '$sign${change.toStringAsFixed(2)}',
      },
      followUps: const [AssistantIntent.inflation, AssistantIntent.market],
      confidence: 0.9,
    );
  }

  AssistantReply _marketReply() => const AssistantReply(
        intent: AssistantIntent.market,
        params: {},
        followUps: [AssistantIntent.inflation, AssistantIntent.currency],
        confidence: 0.7,
      );

  AssistantReply _incomeDropReply(AssistantContext context) {
    final newIncome = context.monthlyIncome * 0.9;
    final newSavings = newIncome - context.monthlyExpenses;
    final newRate = newIncome > 0 ? newSavings / newIncome : 0.0;
    final trim = (context.discretionarySpending * _incomeDropTrimShare).round();
    return AssistantReply(
      intent: AssistantIntent.incomeDrop,
      params: {
        'newIncome': CurrencyFormat.pkr(newIncome),
        'newSavings': CurrencyFormat.pkr(newSavings),
        'newRate': _percent(newRate),
        'cut': CurrencyFormat.pkr(trim.toDouble()),
        'restored': CurrencyFormat.pkr(newSavings + trim),
      },
      followUps: const [AssistantIntent.savings, AssistantIntent.budget],
      confidence: 0.9,
    );
  }

  AssistantReply _generalReply(AssistantContext context) {
    final change = context.usdPkrChange;
    final sign = change >= 0 ? '+' : '';
    return AssistantReply(
      intent: AssistantIntent.general,
      params: {
        'inflation': context.inflationRate.toStringAsFixed(1),
        'rate': context.usdPkrRate.toStringAsFixed(2),
        'change': '$sign${change.toStringAsFixed(2)}',
        'kibor': context.kiborRate.toStringAsFixed(1),
      },
      followUps: const [AssistantIntent.inflation, AssistantIntent.savings],
      confidence: 0.6,
    );
  }

  // ── Persona-aware perspective ────────────────────────────────────────

  /// Returns a concise persona-relevant perspective string, or null when
  /// no completed profile exists.
  String? _personaPerspective(AssistantContext context) {
    final persona = context.persona;
    if (persona == null) return null;

    return switch (persona) {
      Persona.student =>
        "Since you're a student, building a small financial buffer may be "
            "more useful than setting an aggressive savings target.",
      Persona.salaried =>
        "With your current income and essential expenses, protecting your "
            "monthly savings and building an emergency fund can strengthen "
            "your financial health.",
      Persona.businessOwner =>
        "Because business income can vary, maintaining a cash buffer can "
            "help you manage slower months and unexpected expenses.",
      Persona.shopOwner =>
        "For a shop-based income, tracking daily expenses and keeping some "
            "working capital available can help manage changing sales and costs.",
    };
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  EconomicImpactInput _impactInput(AssistantContext context) =>
      EconomicImpactInput(
        monthlyIncome: context.monthlyIncome,
        monthlyExpenses: context.monthlyExpenses,
        discretionarySpending: context.discretionarySpending,
      );

  static String _percent(double fraction) =>
      (fraction * 100).toStringAsFixed(1);
}

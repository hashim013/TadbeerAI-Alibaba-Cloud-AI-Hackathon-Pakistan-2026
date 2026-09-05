import '../entities/assistant_message.dart';
import '../entities/financial_profile.dart';

/// The user's financial + economic position the assistant answers from —
/// derived from the existing Phase-2 finance data and the economic snapshot.
///
/// When a completed [FinancialProfile] exists, the optional persona/income/
/// expenses/goal fields are populated so the assistant can personalize its
/// answers.  When no profile exists these fields remain null and the
/// assistant falls back to its non-personalized behavior.
class AssistantContext {
  const AssistantContext({
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.monthlySavings,
    required this.discretionarySpending,
    required this.savingsRate,
    required this.healthScore,
    required this.emergencyMonths,
    required this.overBudgetCategories,
    required this.budgetLimitTotal,
    required this.budgetedSpent,
    required this.goalCount,
    required this.goalAverageProgress,
    required this.topGoalTitle,
    required this.topGoalProgress,
    required this.topGoalRequiredMonthly,
    required this.inflationRate,
    required this.usdPkrRate,
    required this.usdPkrChange,
    required this.kiborRate,
    // ── Optional profile fields (from FinancialProfileRepository) ───
    this.persona,
    this.profileIncome,
    this.profileExpenses,
    this.profileSavings,
    this.primaryGoal,
  });

  final double monthlyIncome;
  final double monthlyExpenses;
  final double monthlySavings;

  /// Current-month spending on discretionary ("wants") categories.
  final double discretionarySpending;

  /// Fraction of income saved this month, 0..1.
  final double savingsRate;

  /// Current Financial Health Score, 0..100.
  final int healthScore;

  /// Months of expenses covered by total savings.
  final double emergencyMonths;

  /// Category ids currently over their budget limits.
  final List<String> overBudgetCategories;

  final double budgetLimitTotal;

  /// This month's spending across all budgeted categories.
  final double budgetedSpent;

  final int goalCount;

  /// Average progress across goals, 0..1.
  final double goalAverageProgress;

  /// Title of the highest-progress goal (user data, not localized).
  final String topGoalTitle;

  /// Progress of the top goal, 0..1.
  final double topGoalProgress;

  /// Amount needed monthly to finish the top goal on time.
  final double topGoalRequiredMonthly;

  /// Current inflation rate in percent (e.g. 11.2).
  final double inflationRate;

  /// Current USD/PKR exchange rate.
  final double usdPkrRate;

  /// This month's USD/PKR movement (rupees per dollar).
  final double usdPkrChange;

  /// Current 3-month KIBOR rate in percent (e.g. 20.3).
  final double kiborRate;

  // ── Optional profile fields ───────────────────────────────────────────

  /// User's selected persona (null when no profile has been completed).
  final Persona? persona;

  /// User-declared typical monthly income (from the profile form).
  final double? profileIncome;

  /// User-declared essential monthly expenses (from the profile form).
  final double? profileExpenses;

  /// User-declared total savings (from the profile form).
  final double? profileSavings;

  /// User's primary financial goal (null when no profile exists).
  final PrimaryGoal? primaryGoal;
}

/// Assistant data contract.
///
/// The offline mock answers from rule-based intents over [AssistantContext];
/// the API implementation calls the multi-agent backend. Both return the
/// same [AssistantReply] shape so the chat UI stays repository-agnostic.
abstract interface class AssistantRepository {
  /// Answers [question] using the user's current [context].
  ///
  /// [language] is the backend language code ("en", "ur", "ur_latn") derived
  /// from the app locale — the mock ignores it (its templates are localized
  /// by the UI), while the API forwards it so the backend answers in kind.
  Future<AssistantReply> respond(
    String question,
    AssistantContext context, {
    String language = 'en',
  });
}

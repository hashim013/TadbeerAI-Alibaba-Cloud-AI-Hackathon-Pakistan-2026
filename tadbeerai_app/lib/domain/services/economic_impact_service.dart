/// The user's monthly financial position an impact scenario runs against.
///
/// Deliberately the same numbers the Finance tab shows — the impact engine
/// must never invent a second financial profile.
class EconomicImpactInput {
  const EconomicImpactInput({
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.discretionarySpending,
  });

  final double monthlyIncome;
  final double monthlyExpenses;

  /// Current-month spending on discretionary ("wants") categories.
  final double discretionarySpending;

  /// Income minus expenses for the month.
  double get monthlySavings => monthlyIncome - monthlyExpenses;

  /// Spending on essentials (needs) — the base inflation scenarios act on.
  double get essentialExpenses => monthlyExpenses - discretionarySpending;
}

/// Deterministic result of one what-if scenario.
///
/// [estimatedSavingsCapacity] may go negative — that is the honest output of
/// the arithmetic and the UI shows it as a warning, not an error.
class EconomicImpactResult {
  const EconomicImpactResult({
    required this.monthlyIncome,
    required this.estimatedMonthlyPressure,
    required this.estimatedSavingsCapacity,
  });

  /// The monthly income the scenario ran against.
  final double monthlyIncome;

  /// Additional monthly cost the scenario is estimated to add.
  final double estimatedMonthlyPressure;

  /// monthlySavings − estimatedMonthlyPressure.
  final double estimatedSavingsCapacity;

  /// Pressure as a fraction of monthly income (0 when income is unknown).
  double get pressureShareOfIncome =>
      monthlyIncome > 0 ? estimatedMonthlyPressure / monthlyIncome : 0;
}

/// Transparent, scenario-based estimation of economic changes on one
/// household budget.
///
/// The formulas are intentionally simple and documented — this is education
/// and planning support, NOT a forecast:
///
/// * Inflation ±X points: essentials × delta = extra monthly cost.
/// * USD/PKR ±X%: imported-exposed spending × delta = extra monthly cost.
/// * Policy rate ±X points: typical loan balance × delta / 12 = extra
///   monthly interest.
///
/// No LLM is involved anywhere; identical inputs always produce identical
/// outputs, which makes every displayed number unit-testable.
abstract final class EconomicImpactService {
  /// Share of monthly spending treated as exposed to imported-goods prices
  /// (fuel, electronics, some groceries) in exchange-rate scenarios.
  static const importedGoodsShare = 0.25;

  /// Typical demo household borrowing used by interest-rate scenarios.
  static const typicalLoanBalance = 500000;

  // ── Demo scenarios (used by the Economy UI and the mock assistant) ─────

  /// Standard inflation scenario: +2 percentage points.
  static const demoInflationDelta = 0.02;

  /// Standard exchange-rate scenario: rupee weakens 2%.
  static const demoExchangeRateDelta = 0.02;

  /// Standard policy-rate scenario: +1 percentage point (100 basis points).
  static const demoPolicyRateDelta = 0.01;

  // ── Scenarios ───────────────────────────────────────────────────────────

  /// Essentials grow by [inflationDelta] (0.02 = +2 percentage points).
  static EconomicImpactResult inflationImpact(
    EconomicImpactInput input, {
    double inflationDelta = demoInflationDelta,
  }) {
    final pressure = input.essentialExpenses * inflationDelta;
    return EconomicImpactResult(
      monthlyIncome: input.monthlyIncome,
      estimatedMonthlyPressure: pressure,
      estimatedSavingsCapacity: input.monthlySavings - pressure,
    );
  }

  /// Imported-exposed spending grows by [rateChange] (0.02 = +2%).
  static EconomicImpactResult exchangeRateImpact(
    EconomicImpactInput input, {
    double rateChange = demoExchangeRateDelta,
  }) {
    final importedExposure = input.monthlyExpenses * importedGoodsShare;
    final pressure = importedExposure * rateChange;
    return EconomicImpactResult(
      monthlyIncome: input.monthlyIncome,
      estimatedMonthlyPressure: pressure,
      estimatedSavingsCapacity: input.monthlySavings - pressure,
    );
  }

  /// A [rateDelta] (0.01 = +1 point) rate rise on a typical loan balance
  /// costs balance × delta per year, i.e. / 12 per month.
  static EconomicImpactResult policyRateImpact(
    EconomicImpactInput input, {
    double rateDelta = demoPolicyRateDelta,
  }) {
    final pressure = typicalLoanBalance * rateDelta / 12;
    return EconomicImpactResult(
      monthlyIncome: input.monthlyIncome,
      estimatedMonthlyPressure: pressure,
      estimatedSavingsCapacity: input.monthlySavings - pressure,
    );
  }
}

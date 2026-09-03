import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/mock_economic_repository.dart';
import '../domain/entities/economic_overview.dart';
import '../domain/entities/finance_category.dart';
import '../domain/repositories/economic_repository.dart';
import '../domain/services/economic_impact_service.dart';
import '../domain/services/finance_calculations.dart';
import 'finance_providers.dart';

final economicRepositoryProvider = Provider<EconomicRepository>(
  (ref) => MockEconomicRepository(),
);

/// The economic snapshot rendered by the Economy tab.
final economicPulseProvider = FutureProvider<EconomicOverview>(
  (ref) => ref.watch(economicRepositoryProvider).getOverview(),
);

/// The user's current-month financial position the impact scenarios run
/// against — the same Phase-2 numbers every finance screen shows.
///
/// Null while the finance data is loading or has failed, so the economy UI
/// hides personalization instead of computing it from invented values.
final economicImpactInputProvider = Provider<EconomicImpactInput?>((ref) {
  final finance = ref.watch(financeControllerProvider).value;
  if (finance == null) return null;

  final now = DateTime.now();
  return EconomicImpactInput(
    monthlyIncome: FinanceCalculations.monthlyIncome(finance.transactions, now),
    monthlyExpenses:
        FinanceCalculations.monthlyExpenses(finance.transactions, now),
    discretionarySpending: FinanceCalculations.discretionarySpending(
        finance.transactions, now, FinanceCategories.discretionaryExpenseIds),
  );
});

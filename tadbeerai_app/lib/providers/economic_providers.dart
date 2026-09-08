import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/api_config.dart';
import '../data/repositories/api_economic_repository.dart';
import '../data/repositories/mock_economic_repository.dart';
import '../domain/entities/commodity_price.dart';
import '../domain/entities/economic_overview.dart';
import '../domain/entities/finance_category.dart';
import '../domain/repositories/economic_repository.dart';
import '../domain/services/economic_impact_service.dart';
import '../domain/services/finance_calculations.dart';
import 'assistant_providers.dart';
import 'finance_providers.dart';
import 'profile_providers.dart';

final economicRepositoryProvider = Provider<EconomicRepository>((ref) {
  if (ApiConfig.useMockEconomy) {
    return MockEconomicRepository();
  }
  return ApiEconomicRepository(dio: ref.watch(apiDioProvider));
});

/// The economic snapshot rendered by the Economy tab.
final economicPulseProvider = FutureProvider<EconomicOverview>(
  (ref) => ref.watch(economicRepositoryProvider).getOverview(),
);

/// The selected category filter for essential commodity prices in the Economy tab.
final selectedCommodityCategoryProvider = StateProvider<String>((ref) => 'All');

/// Essential commodity prices monitored under the PBS SPI.
final essentialPricesProvider = FutureProvider<CommodityOverview>((ref) {
  final category = ref.watch(selectedCommodityCategoryProvider);
  return ref
      .watch(economicRepositoryProvider)
      .getEssentialPrices(category: category);
});

/// Single commodity detail provider by id.
final commodityDetailProvider = FutureProvider.family<CommodityPrice?, String>(
  (ref, id) => ref.watch(economicRepositoryProvider).getCommodity(id),
);

/// The user's current-month financial position the impact scenarios run
/// against — the same numbers every finance screen shows.
///
/// Falls back to the user's Persona / Financial Profile if transactions
/// have not been recorded yet.
final economicImpactInputProvider = Provider<EconomicImpactInput?>((ref) {
  final finance = ref.watch(financeControllerProvider).valueOrNull;
  final profile = ref.watch(financialProfileControllerProvider).valueOrNull;

  if (finance == null && profile == null) return null;

  final now = DateTime.now();
  final txIncome = finance != null
      ? FinanceCalculations.monthlyIncome(finance.transactions, now)
      : 0.0;
  final txExpenses = finance != null
      ? FinanceCalculations.monthlyExpenses(finance.transactions, now)
      : 0.0;
  final txDiscretionary = finance != null
      ? FinanceCalculations.discretionarySpending(
          finance.transactions, now, FinanceCategories.discretionaryExpenseIds)
      : 0.0;

  final effectiveIncome =
      txIncome > 0 ? txIncome : (profile?.monthlyIncome ?? 0.0);
  final effectiveExpenses =
      txExpenses > 0 ? txExpenses : (profile?.monthlyEssentialExpenses ?? 0.0);
  final effectiveDiscretionary = txDiscretionary > 0
      ? txDiscretionary
      : (effectiveIncome > effectiveExpenses
          ? (effectiveIncome - effectiveExpenses) * 0.2
          : 0.0);

  if (effectiveIncome <= 0 && effectiveExpenses <= 0) return null;

  return EconomicImpactInput(
    monthlyIncome: effectiveIncome,
    monthlyExpenses: effectiveExpenses,
    discretionarySpending: effectiveDiscretionary,
  );
});


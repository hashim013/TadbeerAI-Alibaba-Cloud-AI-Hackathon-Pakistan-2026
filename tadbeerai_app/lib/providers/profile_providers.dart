import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/financial_profile.dart';
import '../domain/entities/transaction.dart';
import '../domain/repositories/financial_profile_repository.dart';
import 'repository_providers.dart';

/// Loads the stored financial profile (null when none exists yet).
final financialProfileProvider = FutureProvider<FinancialProfile?>((ref) {
  final repo = ref.watch(financialProfileRepositoryProvider);
  return repo.loadProfile();
});

/// Manages save / clear mutations and ledger synchronizations on the financial profile.
class FinancialProfileController extends AsyncNotifier<FinancialProfile?> {
  FinancialProfileRepository get _repo =>
      ref.watch(financialProfileRepositoryProvider);

  @override
  Future<FinancialProfile?> build() => _repo.loadProfile();

  /// Persists [profile] and updates the local state.
  Future<void> saveProfile(FinancialProfile profile) async {
    state = const AsyncLoading();
    try {
      await _repo.saveProfile(profile);
      state = AsyncData(profile);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  /// Removes the stored profile.
  Future<void> clearProfile() async {
    state = const AsyncLoading();
    try {
      await _repo.clearProfile();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  /// Intelligently synchronizes the user's financial profile with a transaction.
  ///
  /// Each field update has a dedicated financial purpose:
  /// * **Income Addition**:
  ///   - Increases [FinancialProfile.monthlyIncome] (the baseline monthly earnings).
  ///   - Increases liquid [FinancialProfile.totalSavings] (the liquid cash buffer).
  /// * **Expense Addition**:
  ///   - Increases [FinancialProfile.monthlyEssentialExpenses] (the baseline monthly spending commitments).
  ///   - Draws down from liquid [FinancialProfile.totalSavings] (clamped to >= 0.0).
  /// * **Reversal / Deletion** ([isReversal] = true):
  ///   - Income deletion: decreases monthly income and adjusts savings buffer down.
  ///   - Expense deletion: decreases monthly expenses and restores the cash amount back to savings.
  /// * **Null Profile Resilience**:
  ///   - If logged prior to completing the persona wizard, a baseline profile is initialized
  ///     so transaction data immediately personalizes the user's financial overview.
  Future<void> syncWithTransaction(
    Transaction transaction, {
    bool isReversal = false,
  }) async {
    final current = state.valueOrNull ?? await _repo.loadProfile();
    final factor = isReversal ? -1.0 : 1.0;
    final delta = transaction.amount * factor;

    final double baseIncome = current?.monthlyIncome ?? 0.0;
    final double baseExpenses = current?.monthlyEssentialExpenses ?? 0.0;
    final double baseSavings = current?.totalSavings ?? 0.0;

    double newIncome = baseIncome;
    double newExpenses = baseExpenses;
    double newSavings = baseSavings;

    if (transaction.type == TransactionType.income) {
      newIncome = (baseIncome + delta).clamp(0.0, double.infinity);
      newSavings = (baseSavings + delta).clamp(0.0, double.infinity);
    } else {
      newExpenses = (baseExpenses + delta).clamp(0.0, double.infinity);
      newSavings = (baseSavings - delta).clamp(0.0, double.infinity);
    }

    final updated =
        (current ?? const FinancialProfile(profileCompleted: false)).copyWith(
      monthlyIncome: newIncome,
      monthlyEssentialExpenses: newExpenses,
      totalSavings: newSavings,
    );

    await saveProfile(updated);
  }

  /// Intelligently synchronizes an updated transaction against the user profile.
  ///
  /// Undoes the financial impact of [oldTransaction] and applies the updated [newTransaction].
  Future<void> syncTransactionUpdate({
    required Transaction oldTransaction,
    required Transaction newTransaction,
  }) async {
    final current = state.valueOrNull ?? await _repo.loadProfile();

    double baseIncome = current?.monthlyIncome ?? 0.0;
    double baseExpenses = current?.monthlyEssentialExpenses ?? 0.0;
    double baseSavings = current?.totalSavings ?? 0.0;

    // 1. Undo old transaction impact
    if (oldTransaction.type == TransactionType.income) {
      baseIncome =
          (baseIncome - oldTransaction.amount).clamp(0.0, double.infinity);
      baseSavings =
          (baseSavings - oldTransaction.amount).clamp(0.0, double.infinity);
    } else {
      baseExpenses =
          (baseExpenses - oldTransaction.amount).clamp(0.0, double.infinity);
      baseSavings =
          (baseSavings + oldTransaction.amount).clamp(0.0, double.infinity);
    }

    // 2. Apply new transaction impact
    if (newTransaction.type == TransactionType.income) {
      baseIncome =
          (baseIncome + newTransaction.amount).clamp(0.0, double.infinity);
      baseSavings =
          (baseSavings + newTransaction.amount).clamp(0.0, double.infinity);
    } else {
      baseExpenses =
          (baseExpenses + newTransaction.amount).clamp(0.0, double.infinity);
      baseSavings =
          (baseSavings - newTransaction.amount).clamp(0.0, double.infinity);
    }

    final updated =
        (current ?? const FinancialProfile(profileCompleted: false)).copyWith(
      monthlyIncome: baseIncome,
      monthlyEssentialExpenses: baseExpenses,
      totalSavings: baseSavings,
    );

    await saveProfile(updated);
  }
}

final financialProfileControllerProvider =
    AsyncNotifierProvider<FinancialProfileController, FinancialProfile?>(
        FinancialProfileController.new);

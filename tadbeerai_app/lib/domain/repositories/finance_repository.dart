import '../entities/budget.dart';
import '../entities/finance_data.dart';
import '../entities/goal.dart';
import '../entities/transaction.dart';

/// Finance data contract.
///
/// Phase 2 ships a local mock implementation backed by demo data persisted
/// on-device; a remote implementation replaces it in a later phase without
/// touching UI code.
abstract interface class FinanceRepository {
  Future<FinanceData> getFinanceData();

  // ── Transactions ────────────────────────────────────────────────────────
  Future<void> addTransaction(Transaction transaction);

  Future<void> updateTransaction(Transaction transaction);

  Future<void> deleteTransaction(String id);

  // ── Budgets ─────────────────────────────────────────────────────────────
  Future<void> upsertBudget(Budget budget);

  Future<void> deleteBudget(String id);

  // ── Goals ───────────────────────────────────────────────────────────────
  Future<void> addGoal(Goal goal);

  Future<void> updateGoal(Goal goal);

  Future<void> deleteGoal(String id);

  /// Restores the bundled demo dataset (useful while mock mode is active).
  Future<void> resetDemoData();
}

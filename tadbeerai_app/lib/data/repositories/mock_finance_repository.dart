import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/finance_data.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/finance_repository.dart';

/// Local, offline finance repository used in demo mode (`FINANCE_MODE=demo`).
///
/// Starts from an EMPTY ledger (no bundled demo data) and persists every CRUD
/// mutation on-device so it survives restarts. The live `ApiFinanceRepository`
/// replaces this by default without touching UI code.
class MockFinanceRepository implements FinanceRepository {
  MockFinanceRepository(this._prefs);

  final SharedPreferences _prefs;

  FinanceData? _cache;

  @override
  Future<FinanceData> getFinanceData() async {
    await Future<void>.delayed(AppConstants.mockFinanceLatency);

    final cached = _cache;
    if (cached != null) return cached;

    final raw = _prefs.getString(AppConstants.prefFinanceData);
    if (raw != null && raw.isNotEmpty) {
      try {
        return _cache =
            FinanceData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt payload — fall through and reseed.
      }
    }
    return _seedAndPersist();
  }

  @override
  Future<void> addTransaction(Transaction transaction) async {
    final data = await _current();
    final updated =
        data.copyWith(transactions: [...data.transactions, transaction]);
    await _persist(updated);
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    final data = await _current();
    final updated = data.copyWith(
        transactions: data.transactions
            .map((t) => t.id == transaction.id ? transaction : t)
            .toList());
    await _persist(updated);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final data = await _current();
    final updated = data.copyWith(
        transactions: data.transactions.where((t) => t.id != id).toList());
    await _persist(updated);
  }

  @override
  Future<void> upsertBudget(Budget budget) async {
    final data = await _current();
    // One budget per category: an upsert replaces the existing entry.
    final remaining = data.budgets
        .where((b) => b.id != budget.id && b.category != budget.category)
        .toList();
    final updated = data.copyWith(budgets: [...remaining, budget]);
    await _persist(updated);
  }

  @override
  Future<void> deleteBudget(String id) async {
    final data = await _current();
    final updated =
        data.copyWith(budgets: data.budgets.where((b) => b.id != id).toList());
    await _persist(updated);
  }

  @override
  Future<void> addGoal(Goal goal) async {
    final data = await _current();
    final updated = data.copyWith(goals: [...data.goals, goal]);
    await _persist(updated);
  }

  @override
  Future<void> updateGoal(Goal goal) async {
    final data = await _current();
    final updated = data.copyWith(
        goals: data.goals.map((g) => g.id == goal.id ? goal : g).toList());
    await _persist(updated);
  }

  @override
  Future<void> deleteGoal(String id) async {
    final data = await _current();
    final updated =
        data.copyWith(goals: data.goals.where((g) => g.id != id).toList());
    await _persist(updated);
  }

  @override
  Future<void> resetDemoData() async {
    await _prefs.remove(AppConstants.prefFinanceData);
    await _seedAndPersist();
  }

  // ── Internals ──────────────────────────────────────────────────────────

  Future<FinanceData> _current() async => _cache ?? await getFinanceData();

  /// Seeds an EMPTY ledger — the bundled demo dataset is no longer written to
  /// storage. `MockFinanceData` is retained purely as a unit-test fixture (see
  /// financial_health_test.dart); both mock and live finance start empty.
  Future<FinanceData> _seedAndPersist() async {
    const seeded = FinanceData(
      transactions: [],
      budgets: [],
      goals: [],
      openingSavingsBalance: 0,
    );
    await _persist(seeded);
    return seeded;
  }

  Future<void> _persist(FinanceData data) async {
    _cache = data;
    await _prefs.setString(
        AppConstants.prefFinanceData, jsonEncode(data.toJson()));
  }
}

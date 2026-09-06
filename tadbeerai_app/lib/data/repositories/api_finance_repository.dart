import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/finance_data.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/finance_repository.dart';

/// Offline-first [FinanceRepository] backed by the FastAPI `/v1/finance`
/// per-user ledger (Firestore on the server).
///
/// Design (see the Real Finance Backend Migration plan):
/// * Reads return the on-device cache instantly — an empty ledger on a true
///   first run — so the UI never blocks on the network.
/// * On a first load with NO cache, the cloud snapshot is awaited (bounded by a
///   short timeout) so a fresh install / re-login pulls the real ledger; any
///   failure falls back to empty.
/// * When a cache exists, a background GET refreshes it for the next read.
/// * Every mutation is applied to the cache immediately (optimistic, instant
///   UI), persisted locally, then synced with a debounced whole-snapshot PUT.
/// * All network failures are swallowed: the local cache is the source of
///   truth, so the app stays fully usable offline.
/// * Pure-local guests (no Firebase uid) stay cache-only and never hit the
///   network; Firebase anonymous users have a real uid and sync normally.
class ApiFinanceRepository implements FinanceRepository {
  ApiFinanceRepository({
    required Dio dio,
    required SharedPreferences prefs,
    required String? Function() uidProvider,
    Duration syncDebounce = const Duration(milliseconds: 800),
  })  : _dio = dio,
        _prefs = prefs,
        _uidProvider = uidProvider,
        _syncDebounce = syncDebounce;

  final Dio _dio;
  final SharedPreferences _prefs;
  final String? Function() _uidProvider;
  final Duration _syncDebounce;

  /// Per-user cache bucket prefix; the local-only guest bucket is kept
  /// separate so switching accounts never leaks one user's ledger into
  /// another's cache.
  static const String _cachePrefix = 'finance_ledger_';
  static const String _guestBucket = 'guest';

  /// Finance payloads are small — don't inherit the assistant's 90s timeout.
  static const Duration _netTimeout = Duration(seconds: 12);

  static const FinanceData _empty = FinanceData(
    transactions: [],
    budgets: [],
    goals: [],
    openingSavingsBalance: 0,
  );

  FinanceData? _cache;
  String? _cacheBucket;
  Timer? _debounce;
  bool _refreshInFlight = false;

  // ── Identity ─────────────────────────────────────────────────────────────

  /// The uid used for cloud sync, or `null` for a pure-local guest (no Firebase
  /// uid) — those stay cache-only. Mirrors the `startsWith('guest')` convention
  /// used by [AppUser.isGuest] and the theme sync.
  String? get _syncUid {
    final trimmed = (_uidProvider() ?? '').trim();
    if (trimmed.isEmpty || trimmed.startsWith('guest')) return null;
    return trimmed;
  }

  String get _bucket => _syncUid ?? _guestBucket;

  bool get _cacheOnly => _syncUid == null;

  String get _cacheKey => '$_cachePrefix$_bucket';

  // ── Reads ────────────────────────────────────────────────────────────────

  @override
  Future<FinanceData> getFinanceData() async {
    final bucket = _bucket;
    if (_cacheBucket != bucket) {
      _cache = null; // account switched — drop the previous user's cache
      _cacheBucket = bucket;
    }

    final mem = _cache;
    if (mem != null) {
      unawaited(_refreshFromCloud());
      return mem;
    }

    final fromPrefs = _readPrefs();
    if (fromPrefs != null) {
      _cache = fromPrefs;
      unawaited(_refreshFromCloud());
      return fromPrefs;
    }

    // No cache at all. Cache-only guests start empty; signed-in users await the
    // cloud snapshot (bounded) so a fresh device pulls the real ledger.
    final data = _cacheOnly ? _empty : (await _fetchFromCloud() ?? _empty);
    _cache = data;
    await _writePrefs(data);
    return data;
  }

  // ── Transactions ─────────────────────────────────────────────────────────

  @override
  Future<void> addTransaction(Transaction transaction) async {
    final data = await _current();
    await _commit(
        data.copyWith(transactions: [...data.transactions, transaction]));
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    final data = await _current();
    await _commit(data.copyWith(
        transactions: data.transactions
            .map((t) => t.id == transaction.id ? transaction : t)
            .toList()));
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final data = await _current();
    await _commit(data.copyWith(
        transactions: data.transactions.where((t) => t.id != id).toList()));
  }

  // ── Budgets ──────────────────────────────────────────────────────────────

  @override
  Future<void> upsertBudget(Budget budget) async {
    final data = await _current();
    // One budget per category: an upsert replaces the existing entry.
    final remaining = data.budgets
        .where((b) => b.id != budget.id && b.category != budget.category)
        .toList();
    await _commit(data.copyWith(budgets: [...remaining, budget]));
  }

  @override
  Future<void> deleteBudget(String id) async {
    final data = await _current();
    await _commit(
        data.copyWith(budgets: data.budgets.where((b) => b.id != id).toList()));
  }

  // ── Goals ────────────────────────────────────────────────────────────────

  @override
  Future<void> addGoal(Goal goal) async {
    final data = await _current();
    await _commit(data.copyWith(goals: [...data.goals, goal]));
  }

  @override
  Future<void> updateGoal(Goal goal) async {
    final data = await _current();
    await _commit(data.copyWith(
        goals: data.goals.map((g) => g.id == goal.id ? goal : g).toList()));
  }

  @override
  Future<void> deleteGoal(String id) async {
    final data = await _current();
    await _commit(
        data.copyWith(goals: data.goals.where((g) => g.id != id).toList()));
  }

  // ── Clear (repurposed from resetDemoData — no demo re-seed) ────────────────

  @override
  Future<void> resetDemoData() async {
    _cacheBucket = _bucket;
    _cache = _empty;
    await _writePrefs(_empty);
    if (_cacheOnly) return;
    _debounce?.cancel();
    await _pushToCloud(); // immediate clear-sync (no debounce)
  }

  /// Cancels any pending debounced sync (called when the provider is disposed).
  void dispose() => _debounce?.cancel();

  // ── Internals ────────────────────────────────────────────────────────────

  Future<FinanceData> _current() async =>
      (_cacheBucket == _bucket && _cache != null) ? _cache! : getFinanceData();

  /// Optimistically apply + persist locally, then schedule a debounced sync.
  Future<void> _commit(FinanceData updated) async {
    _cacheBucket = _bucket;
    _cache = updated;
    await _writePrefs(updated);
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_cacheOnly) return; // guests are local-only
    _debounce?.cancel();
    _debounce = Timer(_syncDebounce, () => unawaited(_pushToCloud()));
  }

  Future<void> _pushToCloud() async {
    final data = _cache;
    if (data == null || _cacheOnly) return;
    try {
      await _dio.put(
        ApiConfig.financePath,
        data: data.toJson(),
        options: Options(
          sendTimeout: _netTimeout,
          receiveTimeout: _netTimeout,
        ),
      );
    } catch (_) {
      // Offline / 401 / server error — keep the local cache; the next mutation
      // retries the whole-snapshot sync.
    }
  }

  Future<void> _refreshFromCloud() async {
    if (_cacheOnly || _refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final fresh = await _fetchFromCloud();
      if (fresh != null) {
        _cache = fresh;
        await _writePrefs(fresh);
      }
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<FinanceData?> _fetchFromCloud() async {
    if (_cacheOnly) return null;
    try {
      final response = await _dio.get(
        ApiConfig.financePath,
        options: Options(
          sendTimeout: _netTimeout,
          receiveTimeout: _netTimeout,
        ),
      );
      final data = response.data;
      if (data is Map) {
        return FinanceData.fromJson(data.map((k, v) => MapEntry('$k', v)));
      }
    } catch (_) {
      // 401 (signed out), offline, timeout or malformed — ignore; stay on cache.
    }
    return null;
  }

  FinanceData? _readPrefs() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return FinanceData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // corrupt cache — treated as absent, refetched/rebuilt
    }
  }

  Future<void> _writePrefs(FinanceData data) async {
    try {
      await _prefs.setString(_cacheKey, jsonEncode(data.toJson()));
    } catch (_) {
      // A failed cache write is non-fatal — the in-memory value still serves
      // the UI and the next mutation retries the persist.
    }
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/data/repositories/api_finance_repository.dart';
import 'package:tadbeerai/domain/entities/transaction.dart';

/// Offline-first [ApiFinanceRepository] tests over a scripted HTTP adapter —
/// no real network. Covers: cache-hit instant read, first-load cloud pull,
/// guest cache-only behaviour, optimistic writes, debounced snapshot PUT,
/// graceful DioException fallback, per-user cache isolation and clear/reset.

/// Records GET and PUT requests separately and can be scripted to fail either.
class _FakeFinanceAdapter implements HttpClientAdapter {
  _FakeFinanceAdapter({this.getBody, this.getError, this.putError});

  /// Body served for `GET /v1/finance` (defaults to an empty ledger).
  final Object? getBody;

  /// When set, every GET throws this instead of returning a body.
  final Object? getError;

  /// When set, every PUT throws this instead of succeeding.
  final Object? putError;

  final List<RequestOptions> gets = [];
  final List<RequestOptions> puts = [];

  static const Map<String, Object?> emptyLedger = {
    'transactions': <Object?>[],
    'budgets': <Object?>[],
    'goals': <Object?>[],
    'openingSavingsBalance': 0,
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PUT') {
      puts.add(options);
      if (putError != null) throw putError!;
      return _json(options.data ?? emptyLedger);
    }
    gets.add(options);
    if (getError != null) throw getError!;
    return _json(getBody ?? emptyLedger);
  }

  ResponseBody _json(Object body) => ResponseBody.fromString(
        body is String ? body : jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );

  @override
  void close({bool force = false}) {}
}

Dio _dio(HttpClientAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://localhost:9'))
      ..httpClientAdapter = adapter;

DioException _connError() => DioException(
      requestOptions: RequestOptions(path: '/v1/finance'),
      type: DioExceptionType.connectionError,
    );

Map<String, Object?> _ledger(List<Map<String, Object?>> txs) => {
      'transactions': txs,
      'budgets': <Object?>[],
      'goals': <Object?>[],
      'openingSavingsBalance': 0,
    };

Map<String, Object?> _tx(String id, double amount) => {
      'id': id,
      'title': 'T-$id',
      'amount': amount,
      'type': 'expense',
      'category': 'food',
      'date': '2026-03-15T00:00:00.000',
      'note': null,
    };

Transaction _coffee(String id) => Transaction(
      id: id,
      title: 'Coffee',
      amount: 550,
      type: TransactionType.expense,
      category: 'dining',
      date: DateTime(2026, 3, 15),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ApiFinanceRepository repo(
    _FakeFinanceAdapter adapter, {
    String? uid = 'userA',
    Duration debounce = const Duration(milliseconds: 1),
  }) =>
      ApiFinanceRepository(
        dio: _dio(adapter),
        prefs: prefs,
        uidProvider: () => uid,
        syncDebounce: debounce,
      );

  group('reads', () {
    test('cache hit returns instantly without waiting on the network body',
        () async {
      await prefs.setString(
        'finance_ledger_userA',
        jsonEncode(_ledger([_tx('cached', 100)])),
      );
      // The server holds a DIFFERENT ledger; the synchronous cache must win
      // on this read.
      final adapter =
          _FakeFinanceAdapter(getBody: _ledger([_tx('server', 999)]));
      final repository = repo(adapter);

      final data = await repository.getFinanceData();

      expect(data.transactions.single.id, 'cached');
      repository.dispose();
    });

    test('no cache + signed in awaits the cloud snapshot and caches it',
        () async {
      final adapter =
          _FakeFinanceAdapter(getBody: _ledger([_tx('server', 999)]));
      final repository = repo(adapter);

      final data = await repository.getFinanceData();

      expect(data.transactions.single.id, 'server');
      expect(adapter.gets, hasLength(1));
      expect(adapter.gets.single.path, '/v1/finance');
      expect(prefs.getString('finance_ledger_userA'), contains('server'));
      repository.dispose();
    });

    test('no cache + guest returns empty and never hits the network', () async {
      final adapter = _FakeFinanceAdapter();
      final repository = repo(adapter, uid: 'guest_user');

      final data = await repository.getFinanceData();

      expect(data.transactions, isEmpty);
      expect(adapter.gets, isEmpty);
      expect(adapter.puts, isEmpty);
      expect(prefs.getString('finance_ledger_guest'), isNotNull);
      repository.dispose();
    });

    test('GET failure on first load falls back to an empty ledger', () async {
      final adapter = _FakeFinanceAdapter(getError: _connError());
      final repository = repo(adapter);

      final data = await repository.getFinanceData();

      expect(data.transactions, isEmpty);
      expect(data.openingSavingsBalance, 0);
      repository.dispose();
    });
  });

  group('optimistic writes', () {
    test('a mutation updates cache and prefs immediately (before any sync)',
        () async {
      final adapter = _FakeFinanceAdapter();
      final repository = repo(adapter, debounce: const Duration(seconds: 30));

      await repository.addTransaction(_coffee('tx-1'));

      // The write is durable locally without waiting for the debounce.
      expect(prefs.getString('finance_ledger_userA'), contains('tx-1'));
      expect(adapter.puts, isEmpty);

      // A fresh instance over the same storage reads it back.
      final reloaded =
          repo(_FakeFinanceAdapter(), debounce: const Duration(seconds: 30));
      final data = await reloaded.getFinanceData();
      expect(data.transactions.single.id, 'tx-1');

      repository.dispose();
      reloaded.dispose();
    });

    test('a mutation schedules a debounced whole-snapshot PUT', () async {
      final adapter = _FakeFinanceAdapter();
      final repository = repo(adapter);

      await repository.addTransaction(_coffee('tx-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(adapter.puts, hasLength(1));
      expect(adapter.puts.single.path, '/v1/finance');
      final body = adapter.puts.single.data as Map<String, Object?>;
      expect((body['transactions'] as List).single['id'], 'tx-1');
      repository.dispose();
    });

    test('a guest mutation stays local and never syncs', () async {
      final adapter = _FakeFinanceAdapter();
      final repository = repo(adapter, uid: 'guest_user');

      await repository.addTransaction(_coffee('tx-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(prefs.getString('finance_ledger_guest'), contains('tx-1'));
      expect(adapter.puts, isEmpty);
      repository.dispose();
    });

    test('PUT failure is swallowed and the optimistic cache is retained',
        () async {
      final adapter = _FakeFinanceAdapter(putError: _connError());
      final repository = repo(adapter);

      await repository.addTransaction(_coffee('tx-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(adapter.puts, hasLength(1)); // the sync was attempted
      expect(prefs.getString('finance_ledger_userA'), contains('tx-1'));
      repository.dispose();
    });
  });

  group('per-user isolation', () {
    test('different uids read different cache buckets', () async {
      await prefs.setString(
          'finance_ledger_userA', jsonEncode(_ledger([_tx('a-tx', 100)])));
      await prefs.setString(
          'finance_ledger_userB', jsonEncode(_ledger([_tx('b-tx', 200)])));

      final repoA = repo(_FakeFinanceAdapter(), uid: 'userA');
      final repoB = repo(_FakeFinanceAdapter(), uid: 'userB');

      expect((await repoA.getFinanceData()).transactions.single.id, 'a-tx');
      expect((await repoB.getFinanceData()).transactions.single.id, 'b-tx');

      repoA.dispose();
      repoB.dispose();
    });

    test('switching uid within one instance drops the previous cache',
        () async {
      var uid = 'userA';
      await prefs.setString(
          'finance_ledger_userA', jsonEncode(_ledger([_tx('a-tx', 100)])));
      await prefs.setString(
          'finance_ledger_userB', jsonEncode(_ledger([_tx('b-tx', 200)])));

      final repository = ApiFinanceRepository(
        dio: _dio(_FakeFinanceAdapter()),
        prefs: prefs,
        uidProvider: () => uid,
        syncDebounce: const Duration(seconds: 30),
      );

      expect(
          (await repository.getFinanceData()).transactions.single.id, 'a-tx');
      uid = 'userB';
      expect(
          (await repository.getFinanceData()).transactions.single.id, 'b-tx');

      repository.dispose();
    });
  });

  group('reset clears the ledger', () {
    test('signed-in reset empties the cache and syncs immediately', () async {
      await prefs.setString(
          'finance_ledger_userA', jsonEncode(_ledger([_tx('a-tx', 100)])));
      final adapter = _FakeFinanceAdapter();
      // A long debounce proves resetDemoData bypasses it and pushes at once.
      final repository = repo(adapter, debounce: const Duration(seconds: 30));

      await repository.resetDemoData();

      final stored = jsonDecode(prefs.getString('finance_ledger_userA')!);
      expect(stored['transactions'], isEmpty);
      expect(adapter.puts, hasLength(1));
      repository.dispose();
    });

    test('guest reset empties the cache without a network call', () async {
      await prefs.setString(
          'finance_ledger_guest', jsonEncode(_ledger([_tx('g-tx', 100)])));
      final adapter = _FakeFinanceAdapter();
      final repository = repo(adapter, uid: 'guest_user');

      await repository.resetDemoData();

      final stored = jsonDecode(prefs.getString('finance_ledger_guest')!);
      expect(stored['transactions'], isEmpty);
      expect(adapter.puts, isEmpty);
      repository.dispose();
    });
  });
}

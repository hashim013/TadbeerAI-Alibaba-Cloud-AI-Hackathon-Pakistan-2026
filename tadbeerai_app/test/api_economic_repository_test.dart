import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/data/repositories/api_economic_repository.dart';
import 'package:tadbeerai/domain/entities/assistant_api_models.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter({this.error});

  final Object? error;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (error != null) throw error!;
    return ResponseBody.fromString(
      jsonEncode(_snapshotBody),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _snapshotBody = {
  'status': 'partial',
  'as_of': '2026-03-01T12:00:00Z',
  'sources_queried': ['sbp', 'pbs', 'mock_fallback'],
  'fallback_reasons': {'fuel': 'Fuel prices data unavailable from source.'},
  'indicators': {
    'usd_pkr': {
      'name': 'USD to PKR',
      'value': 278.5,
      'unit': 'PKR',
      'change': 0.8,
      'period': 'daily',
      'notes': 'Interbank closing rate',
      'status': 'live',
    },
    'inflation_rate_pct': {
      'name': 'Headline CPI Inflation',
      'value': 11.2,
      'unit': '%',
      'change': -0.3,
      'period': 'monthly',
      'status': 'live',
    },
    'kibor_3m_pct': {
      'name': 'KIBOR (3-Month)',
      'value': 13.5,
      'unit': '%',
      'change': 0.0,
      'period': 'daily',
      'status': 'live',
    },
    'fx_reserves_usd_bn': {
      'name': 'FX Reserves',
      'value': 14.8,
      'unit': 'USD Bn',
      'change': 0.4,
      'period': 'weekly',
      'status': 'live',
    },
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses live snapshot with indicators, status, and fallback reasons',
      () async {
    final adapter = _ScriptedAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final repo = ApiEconomicRepository(dio: dio);

    final overview = await repo.getOverview();

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.first.path, '/v1/economy/snapshot');
    expect(overview.status, DataStatusKind.partial);
    expect(overview.fallbackReasons['fuel'],
        'Fuel prices data unavailable from source.');
    expect(overview.indicators, isNotEmpty);

    final usdPkr = overview.indicatorById('usdPkr');
    expect(usdPkr, isNotNull);
    expect(usdPkr!.currentValue, 278.5);
    expect(usdPkr.dataStatus, DataStatusKind.live);

    final inflation = overview.indicatorById('inflation');
    expect(inflation, isNotNull);
    expect(inflation!.currentValue, 11.2);

    final remittances = overview.indicatorById('remittances');
    expect(remittances, isNotNull);
    expect(remittances!.dataStatus, DataStatusKind.demo);
  });

  test('falls back gracefully to seed data when network fails', () async {
    final adapter = _ScriptedAdapter(
      error: DioException(
        requestOptions: RequestOptions(path: '/v1/economy/snapshot'),
        type: DioExceptionType.connectionError,
      ),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final repo = ApiEconomicRepository(dio: dio);

    final overview = await repo.getOverview();

    // Fallback seed data returned rather than crashing
    expect(overview.indicators, isNotEmpty);
    expect(overview.status, DataStatusKind.demo);
    expect(overview.fallbackReasons, isNotEmpty);
    expect(overview.fallbackReasons.values.first,
        contains('Backend /v1/economy/snapshot unavailable'));
  });

  test('getIndicator returns specific indicator or null when not found',
      () async {
    final adapter = _ScriptedAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final repo = ApiEconomicRepository(dio: dio);

    final item = await repo.getIndicator('usdPkr');
    expect(item, isNotNull);
    expect(item!.id, 'usdPkr');

    final missing = await repo.getIndicator('non_existent');
    expect(missing, isNull);
  });
}

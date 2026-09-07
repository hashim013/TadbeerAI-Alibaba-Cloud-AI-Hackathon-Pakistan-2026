import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/data/repositories/api_economic_repository.dart';
import 'package:tadbeerai/domain/entities/assistant_api_models.dart';
import 'package:tadbeerai/domain/entities/economic_indicator.dart';

/// A scripted Dio adapter that returns the canned snapshot body (or throws the
/// supplied error) so the repository's live parsing path is exercised without a
/// real backend.
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

/// Mirrors the REAL `/v1/economy/snapshot` contract (see core/api_v1.py):
/// per-indicator `previous_value`/`change_value`/`change_percent`/`frequency`/
/// `source_url`/`last_updated` and an oldest-first `history` array. Two LIVE
/// World Bank series (inflation + GDP) carry real annual history; the policy
/// rate stays an honestly-labelled DEMO with no history.
const _snapshotBody = {
  'status': 'partial',
  'fetched_at': '2026-03-01T12:00:00Z',
  'fallback_reasons': {
    'policy_rate_pct': 'SBP gateway not configured; showing demo value.',
  },
  'indicators': {
    'inflation_rate_pct': {
      'name': 'inflation_rate_pct',
      'label': 'Inflation (CPI, annual %)',
      'value': 3.55,
      'unit': '%',
      'status': 'live',
      'source': 'World Bank',
      'period': '2025',
      'notes': 'annual growth rate',
      'previous_value': 23.41,
      'change_value': -19.86,
      'change_percent': -84.84,
      'frequency': 'annual',
      'source_url':
          'https://api.worldbank.org/v2/country/PAK/indicator/FP.CPI.TOTL.ZG',
      'last_updated': '2026-06-13',
      'history': [
        {'period': '2023', 'value': 19.88},
        {'period': '2024', 'value': 23.41},
        {'period': '2025', 'value': 3.55},
      ],
    },
    'gdp_growth_pct': {
      'name': 'gdp_growth_pct',
      'label': 'GDP growth (annual %)',
      'value': 3.7,
      'unit': '%',
      'status': 'live',
      'source': 'World Bank',
      'period': '2025',
      'notes': 'annual real growth rate',
      'previous_value': 3.08,
      'change_value': 0.62,
      'change_percent': 20.13,
      'frequency': 'annual',
      'source_url':
          'https://api.worldbank.org/v2/country/PAK/indicator/NY.GDP.MKTP.KD.ZG',
      'last_updated': '2026-07-13',
      'history': [
        {'period': '2023', 'value': 2.5},
        {'period': '2024', 'value': 3.08},
        {'period': '2025', 'value': 3.7},
      ],
    },
    'policy_rate_pct': {
      'name': 'policy_rate_pct',
      'label': 'Policy rate',
      'value': 15.0,
      'unit': '%',
      'status': 'demo',
      'source': 'Demo dataset',
      'period': 'demo snapshot',
      'notes': '',
      'previous_value': null,
      'change_value': null,
      'change_percent': null,
      'frequency': '',
      'source_url': '',
      'last_updated': '',
      'history': [],
    },
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ApiEconomicRepository repoWith(_ScriptedAdapter adapter) =>
      ApiEconomicRepository(dio: Dio()..httpClientAdapter = adapter);

  test('requests the snapshot endpoint and parses the real contract', () async {
    final adapter = _ScriptedAdapter();
    final overview = await repoWith(adapter).getOverview();

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.first.path, '/v1/economy/snapshot');
    expect(overview.status, DataStatusKind.partial);
    expect(
      overview.fallbackReasons['policy_rate_pct'],
      contains('SBP gateway not configured'),
    );
  });

  test('live indicator history comes from the backend, not the demo seed',
      () async {
    final overview = await repoWith(_ScriptedAdapter()).getOverview();

    final inflation = overview.indicatorById('inflation')!;
    expect(inflation.dataStatus, DataStatusKind.live);
    expect(inflation.currentValue, 3.55);
    expect(inflation.previousValue, 23.41);
    expect(inflation.source, 'World Bank');
    expect(inflation.period, '2025');
    expect(inflation.frequency, 'annual');
    expect(
      inflation.sourceUrl,
      'https://api.worldbank.org/v2/country/PAK/indicator/FP.CPI.TOTL.ZG',
    );

    // The chart data is the REAL 3-point annual series — never the 6-point
    // synthetic demo history that used to be merged onto live values.
    expect(inflation.history, hasLength(3));
    expect(
      inflation.history.map((p) => p.value).toList(),
      [19.88, 23.41, 3.55],
    );
    expect(inflation.history.first.month, DateTime(2023));
    expect(inflation.currentValue, inflation.history.last.value);
    expect(inflation.trend, TrendDirection.falling);
    expect(inflation.updatedAt, DateTime(2026, 6, 13));
  });

  test('GDP growth is present and parsed from the live contract', () async {
    final overview = await repoWith(_ScriptedAdapter()).getOverview();

    final gdp = overview.indicatorById('gdp');
    expect(gdp, isNotNull);
    expect(gdp!.dataStatus, DataStatusKind.live);
    expect(gdp.category, 'growth');
    expect(gdp.currentValue, 3.7);
    expect(gdp.previousValue, 3.08);
    expect(gdp.history, hasLength(3));
    expect(gdp.trend, TrendDirection.rising);
  });

  test('a demo indicator stays demo and is never labelled live', () async {
    final overview = await repoWith(_ScriptedAdapter()).getOverview();

    final policyRate = overview.indicatorById('policyRate')!;
    expect(policyRate.dataStatus, DataStatusKind.demo);
    expect(policyRate.dataStatus, isNot(DataStatusKind.live));
    // No real history and no real previous value → no fabricated trend.
    expect(policyRate.history, isEmpty);
    expect(policyRate.previousValue, policyRate.currentValue);
    expect(policyRate.trend, TrendDirection.stable);
  });

  test('"What\'s changing?" is derived from real movements, newest first',
      () async {
    final overview = await repoWith(_ScriptedAdapter()).getOverview();

    // Only the two live movers produce events; the stable demo rate does not.
    expect(overview.events, hasLength(2));
    expect(
      overview.events.map((e) => e.indicatorId).toList(),
      ['gdp', 'inflation'],
    );
    expect(overview.events.first.id, 'change_gdp');
    expect(overview.events.any((e) => e.indicatorId == 'policyRate'), isFalse);
  });

  test('falls back to the demo seed (labelled demo) when the network fails',
      () async {
    final adapter = _ScriptedAdapter(
      error: DioException(
        requestOptions: RequestOptions(path: '/v1/economy/snapshot'),
        type: DioExceptionType.connectionError,
      ),
    );

    final overview = await repoWith(adapter).getOverview();

    expect(overview.indicators, isNotEmpty);
    expect(overview.status, DataStatusKind.demo);
    expect(
      overview.indicators.every((i) => i.dataStatus == DataStatusKind.demo),
      isTrue,
      reason: 'offline fallback must never present demo data as live',
    );
    expect(overview.fallbackReasons, isNotEmpty);
    expect(
      overview.fallbackReasons.values.first,
      contains('Backend /v1/economy/snapshot unavailable'),
    );
  });

  test('getIndicator returns a parsed indicator or null when unknown',
      () async {
    final repo = repoWith(_ScriptedAdapter());

    final gdp = await repo.getIndicator('gdp');
    expect(gdp, isNotNull);
    expect(gdp!.id, 'gdp');

    expect(await repo.getIndicator('non_existent'), isNull);
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/data/repositories/api_economic_repository.dart';
import 'package:tadbeerai/data/repositories/mock_economic_repository.dart';
import 'package:tadbeerai/domain/entities/assistant_api_models.dart';

class _CommodityScriptedAdapter implements HttpClientAdapter {
  _CommodityScriptedAdapter({this.error});

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

    if (options.path.endsWith('/tomatoes')) {
      final item = (_essentialPricesBody['items'] as List)
          .firstWhere((i) => i['id'] == 'tomatoes');
      return ResponseBody.fromString(
        jsonEncode(item),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (options.path.endsWith('/unknown_item')) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 404,
          statusMessage: 'Not Found',
        ),
      );
    }

    return ResponseBody.fromString(
      jsonEncode(_essentialPricesBody),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _essentialPricesBody = {
  'data_status': 'live',
  'period': 'Week ended Sep 03, 2026',
  'source': {
    'name': 'Pakistan Bureau of Statistics (PBS)',
    'url': 'https://www.pbs.gov.pk/price-statistics/',
    'scope': 'Pakistan (50 Markets, 17 Cities)',
  },
  'updated_at': '2026-09-03T12:00:00Z',
  'items': [
    {
      'id': 'wheat_flour',
      'name': 'Wheat Flour (Atta)',
      'normalized_name': 'wheat_flour',
      'category': 'Food & Staples',
      'unit': '10 kg bag',
      'price': 1390.0,
      'previous_price': 1380.0,
      'change_absolute': 10.0,
      'change_percent': 0.72,
      'trend': 'up',
      'data_status': 'live',
      'what_changed': 'Slight mill-gate increase.',
      'why_it_matters': 'Everyday staple.',
      'financial_impact_hint': 'Check for subsidized utility store quotas.',
    },
    {
      'id': 'tomatoes',
      'name': 'Tomatoes',
      'normalized_name': 'tomatoes',
      'category': 'Vegetables',
      'unit': '1 kg',
      'price': 110.0,
      'previous_price': 120.0,
      'change_absolute': -10.0,
      'change_percent': -8.33,
      'trend': 'down',
      'data_status': 'live',
      'what_changed': 'Fresh supply arrived.',
      'why_it_matters': 'Kitchen cooking essential.',
      'financial_impact_hint': 'Perishables see weekly variations.',
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiEconomicRepository - Essential Prices', () {
    test('fetches and parses live essential commodity prices', () async {
      final adapter = _CommodityScriptedAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final repo = ApiEconomicRepository(dio: dio);

      final overview = await repo.getEssentialPrices();

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.first.path, '/v1/economy/essential-prices');
      expect(overview.status, DataStatusKind.live);
      expect(overview.period, 'Week ended Sep 03, 2026');
      expect(overview.items.length, 2);

      final atta = overview.itemById('wheat_flour');
      expect(atta, isNotNull);
      expect(atta!.price, 1390.0);
      expect(atta.changePercent, 0.72);
      expect(atta.trend, 'up');
      expect(atta.dataStatus, DataStatusKind.live);
    });

    test('sends category filter as query parameter', () async {
      final adapter = _CommodityScriptedAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final repo = ApiEconomicRepository(dio: dio);

      await repo.getEssentialPrices(category: 'Vegetables');

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.first.queryParameters['category'], 'Vegetables');
    });

    test('getCommodity retrieves specific item by ID', () async {
      final adapter = _CommodityScriptedAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final repo = ApiEconomicRepository(dio: dio);

      final tomatoes = await repo.getCommodity('tomatoes');
      expect(tomatoes, isNotNull);
      expect(tomatoes!.id, 'tomatoes');
      expect(tomatoes.trend, 'down');

      final unknown = await repo.getCommodity('unknown_item');
      expect(unknown, isNull);
    });

    test('falls back gracefully to seed data on network failure', () async {
      final adapter = _CommodityScriptedAdapter(
        error: DioException(
          requestOptions:
              RequestOptions(path: '/v1/economy/essential-prices'),
          type: DioExceptionType.connectionError,
        ),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final repo = ApiEconomicRepository(dio: dio);

      final overview = await repo.getEssentialPrices();

      expect(overview.items, isNotEmpty);
      expect(overview.status, DataStatusKind.demo);
      expect(overview.fallbackReasons, isNotEmpty);
      expect(
        overview.fallbackReasons['offline'],
        contains('Backend /v1/economy/essential-prices unavailable'),
      );
    });
  });

  group('MockEconomicRepository - Essential Prices', () {
    test('provides mock commodities with category filtering', () async {
      final repo = MockEconomicRepository();

      final allOverview = await repo.getEssentialPrices();
      expect(allOverview.items, isNotEmpty);

      final vegOverview = await repo.getEssentialPrices(category: 'Vegetables');
      expect(vegOverview.items, isNotEmpty);
      for (final item in vegOverview.items) {
        expect(item.category.toLowerCase(), 'vegetables');
      }

      final item = await repo.getCommodity('wheat_flour');
      expect(item, isNotNull);
      expect(item!.id, 'wheat_flour_bag');
    });
  });
}

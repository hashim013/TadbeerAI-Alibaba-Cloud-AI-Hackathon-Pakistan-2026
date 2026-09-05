import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../../domain/entities/assistant_api_models.dart';
import '../../domain/entities/commodity_price.dart';
import '../../domain/entities/economic_indicator.dart';
import '../../domain/entities/economic_overview.dart';
import '../../domain/repositories/economic_repository.dart';
import '../mock/mock_commodity_data.dart';
import '../mock/mock_economic_data.dart';

/// [EconomicRepository] backed by the FastAPI `/v1/economy/snapshot` endpoint.
///
/// Fetches the normalized macroeconomic snapshot from the backend (powered by
/// the live World Bank API and official gateway providers). If the request fails,
/// it safely falls back to the bundled synthetic demo dataset so the UI remains
/// usable offline without crashing.
class ApiEconomicRepository implements EconomicRepository {
  ApiEconomicRepository({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 15),
              ),
            );

  final Dio _dio;

  static const Map<String, ({String id, String name, String category})>
      _catalogMap = {
    'inflation_rate_pct': (
      id: 'inflation',
      name: 'Inflation',
      category: 'prices',
    ),
    'usd_pkr': (
      id: 'usdPkr',
      name: 'USD / PKR',
      category: 'currency',
    ),
    'policy_rate_pct': (
      id: 'policyRate',
      name: 'Policy Rate',
      category: 'rates',
    ),
    'kibor_3m_pct': (
      id: 'kibor',
      name: 'KIBOR (3-month)',
      category: 'rates',
    ),
    'fx_reserves_usd_bn': (
      id: 'fxReserves',
      name: 'FX Reserves',
      category: 'external',
    ),
    'remittances_usd_bn': (
      id: 'remittances',
      name: 'Remittances',
      category: 'external',
    ),
  };

  @override
  Future<EconomicOverview> getOverview() async {
    try {
      final response = await _dio.get(ApiConfig.economySnapshotPath);
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('Malformed economic snapshot payload');
      }

      final snapshotMap =
          data.map((key, value) => MapEntry('$key', value));
      final rawStatus = snapshotMap['status'] as String?;
      final overallStatus = dataStatusFromName(rawStatus);

      DateTime fetchedAt;
      final rawFetchedAt = snapshotMap['fetched_at'] as String?;
      if (rawFetchedAt != null && rawFetchedAt.isNotEmpty) {
        fetchedAt = DateTime.tryParse(rawFetchedAt) ?? DateTime.now();
      } else {
        fetchedAt = DateTime.now();
      }

      final rawIndicators = snapshotMap['indicators'];
      final indicatorsMap = rawIndicators is Map
          ? rawIndicators.map((k, v) => MapEntry('$k', v))
          : const <String, dynamic>{};

      final fallbackReasons = <String, String>{};
      final rawReasons = snapshotMap['fallback_reasons'];
      if (rawReasons is Map) {
        for (final entry in rawReasons.entries) {
          fallbackReasons['${entry.key}'] = '${entry.value}';
        }
      } else if (rawReasons is List) {
        for (var i = 0; i < rawReasons.length; i++) {
          fallbackReasons['reason_$i'] = '${rawReasons[i]}';
        }
      }

      final now = DateTime.now();
      final baselineOverview = MockEconomicData.seed(now);
      final List<EconomicIndicator> indicators = [];

      for (final entry in _catalogMap.entries) {
        final backendKey = entry.key;
        final meta = entry.value;
        final baselineIndicator = baselineOverview.indicatorById(meta.id);

        if (indicatorsMap.containsKey(backendKey)) {
          final item = indicatorsMap[backendKey];
          if (item is Map) {
            final itemMap = item.map((k, v) => MapEntry('$k', v));
            final value = (itemMap['value'] as num?)?.toDouble() ??
                baselineIndicator?.currentValue ??
                0.0;
            final unit = itemMap['unit'] as String? ??
                baselineIndicator?.unit ??
                '';
            final source = itemMap['source'] as String? ??
                baselineIndicator?.source ??
                '';
            final statusStr = itemMap['status'] as String?;
            final indStatus = dataStatusFromName(statusStr);
            final period = itemMap['period'] as String? ?? '';
            final notes = itemMap['notes'] as String? ?? '';

            // Previous value & trend baseline from historical series
            final previousValue = baselineIndicator?.previousValue ?? value;
            final history = baselineIndicator?.history ??
                [
                  IndicatorPoint(month: now, value: value),
                ];

            indicators.add(
              EconomicIndicator(
                id: meta.id,
                name: meta.name,
                currentValue: value,
                previousValue: previousValue,
                unit: unit,
                category: meta.category,
                source: source,
                dataStatus: indStatus,
                updatedAt: fetchedAt,
                history: history,
                period: period,
                notes: notes,
              ),
            );
            continue;
          }
        }

        // If an indicator was omitted in the backend payload, preserve baseline
        if (baselineIndicator != null) {
          indicators.add(baselineIndicator);
        }
      }

      // Preserve any baseline indicators (e.g. fuel prices, gold) not in catalog map
      for (final baseline in baselineOverview.indicators) {
        if (!indicators.any((ind) => ind.id == baseline.id)) {
          indicators.add(baseline);
        }
      }

      return EconomicOverview(
        indicators: indicators,
        events: baselineOverview.events,
        updatedAt: fetchedAt,
        status: overallStatus,
        fallbackReasons: fallbackReasons,
      );
    } catch (e) {
      // Graceful offline fallback: return the clean synthetic demo snapshot
      final seed = MockEconomicData.seed(DateTime.now());
      return EconomicOverview(
        indicators: seed.indicators,
        events: seed.events,
        updatedAt: seed.updatedAt,
        status: DataStatusKind.demo,
        fallbackReasons: {
          'offline': 'Backend /v1/economy/snapshot unavailable: $e',
        },
      );
    }
  }

  @override
  Future<EconomicIndicator?> getIndicator(String id) async {
    final overview = await getOverview();
    return overview.indicatorById(id);
  }

  @override
  Future<CommodityOverview> getEssentialPrices({String? category}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null &&
          category.isNotEmpty &&
          category.toLowerCase() != 'all') {
        queryParams['category'] = category;
      }
      final response = await _dio.get(
        ApiConfig.essentialPricesPath,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('Malformed essential prices payload');
      }
      final map = data.map((k, v) => MapEntry('$k', v));
      return CommodityOverview.fromJson(map);
    } catch (e) {
      final seed = MockCommodityData.seed(DateTime.now());
      if (category == null ||
          category.isEmpty ||
          category.toLowerCase() == 'all') {
        return CommodityOverview(
          items: seed.items,
          period: seed.period,
          sourceName: seed.sourceName,
          sourceUrl: seed.sourceUrl,
          sourceScope: seed.sourceScope,
          status: DataStatusKind.demo,
          updatedAt: seed.updatedAt,
          fallbackReasons: {
            'offline': 'Backend /v1/economy/essential-prices unavailable: $e',
          },
        );
      }
      return CommodityOverview(
        items: seed.filterByCategory(category),
        period: seed.period,
        sourceName: seed.sourceName,
        sourceUrl: seed.sourceUrl,
        sourceScope: seed.sourceScope,
        status: DataStatusKind.demo,
        updatedAt: seed.updatedAt,
        fallbackReasons: {
          'offline': 'Backend /v1/economy/essential-prices unavailable: $e',
        },
      );
    }
  }

  @override
  Future<CommodityPrice?> getCommodity(String id) async {
    try {
      final response = await _dio.get('${ApiConfig.essentialPricesPath}/$id');
      final data = response.data;
      if (data is Map &&
          data.containsKey('id') &&
          data['id'] is String &&
          (data['id'] as String).isNotEmpty) {
        return CommodityPrice.fromJson(data.map((k, v) => MapEntry('$k', v)));
      }
    } catch (_) {}
    final overview = await getEssentialPrices();
    return overview.itemById(id);
  }
}

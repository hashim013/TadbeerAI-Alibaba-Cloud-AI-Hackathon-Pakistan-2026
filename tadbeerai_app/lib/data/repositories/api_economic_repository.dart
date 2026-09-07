import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../../domain/entities/assistant_api_models.dart';
import '../../domain/entities/commodity_price.dart';
import '../../domain/entities/economic_event.dart';
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
    'gdp_growth_pct': (
      id: 'gdp',
      name: 'GDP Growth',
      category: 'growth',
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

      final snapshotMap = data.map((key, value) => MapEntry('$key', value));
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

      final List<EconomicIndicator> indicators = [];

      for (final entry in _catalogMap.entries) {
        final meta = entry.value;
        final raw = indicatorsMap[entry.key];
        if (raw is! Map) continue;
        final item = raw.map((k, v) => MapEntry('$k', v));

        // An indicator with no value has no honest number to show — skip it
        // rather than substituting a demo/baseline figure.
        final value = (item['value'] as num?)?.toDouble();
        if (value == null) continue;

        final indStatus = dataStatusFromName(item['status'] as String?);
        final period = item['period'] as String? ?? '';
        final lastUpdated = item['last_updated'] as String? ?? '';

        // Real history straight from the backend series (oldest-first); no
        // demo trend is ever merged onto a live value.
        final history = _parseHistory(item['history']);
        final previousValue = (item['previous_value'] as num?)?.toDouble() ??
            (history.length >= 2 ? history[history.length - 2].value : value);
        final updatedAt =
            DateTime.tryParse(lastUpdated) ?? _parsePeriod(period) ?? fetchedAt;

        indicators.add(
          EconomicIndicator(
            id: meta.id,
            name: meta.name,
            currentValue: value,
            previousValue: previousValue,
            unit: item['unit'] as String? ?? '',
            category: meta.category,
            source: item['source'] as String? ?? '',
            dataStatus: indStatus,
            updatedAt: updatedAt,
            history: history,
            period: period,
            notes: item['notes'] as String? ?? '',
            frequency: item['frequency'] as String? ?? '',
            sourceUrl: item['source_url'] as String? ?? '',
          ),
        );
      }

      return EconomicOverview(
        indicators: indicators,
        events: _deriveEvents(indicators),
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

  /// Parses the backend `history` array (oldest-first `{period, value}`) into
  /// [IndicatorPoint]s, skipping entries without a usable period or value.
  static List<IndicatorPoint> _parseHistory(dynamic raw) {
    if (raw is! List) return const [];
    final points = <IndicatorPoint>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final date = _parsePeriod('${entry['period'] ?? ''}');
      final value = (entry['value'] as num?)?.toDouble();
      if (date == null || value == null) continue;
      points.add(IndicatorPoint(month: date, value: value));
    }
    return points;
  }

  /// Parses a backend period label into a timestamp: a bare year (`"2025"`)
  /// becomes 1 Jan of that year, `"YYYY-MM"` becomes that month, and a full
  /// ISO date is parsed as-is. Returns null when unparseable (e.g. the demo
  /// snapshot's `"demo snapshot"` period).
  static DateTime? _parsePeriod(String period) {
    final text = period.trim();
    if (text.isEmpty) return null;
    final yearOnly = int.tryParse(text);
    if (yearOnly != null && yearOnly > 1000 && yearOnly < 3000) {
      return DateTime(yearOnly);
    }
    final parts = text.split('-');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null && month >= 1 && month <= 12) {
        return DateTime(year, month);
      }
    }
    return DateTime.tryParse(text);
  }

  /// Builds the "What's changing?" feed from REAL movements only: an entry
  /// appears just when an indicator moved against a genuine previous value
  /// (a non-stable trend). Newest first; no fabricated narratives.
  static List<EconomicEvent> _deriveEvents(List<EconomicIndicator> indicators) {
    final events = <EconomicEvent>[
      for (final indicator in indicators)
        if (indicator.trend != TrendDirection.stable)
          EconomicEvent(
            id: 'change_${indicator.id}',
            indicatorId: indicator.id,
            occurredAt: indicator.updatedAt,
          ),
    ];
    events.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return events;
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

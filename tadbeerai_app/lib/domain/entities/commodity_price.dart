import 'assistant_api_models.dart';

/// An essential consumer commodity price record monitored under the Pakistan
/// Bureau of Statistics (PBS) Sensitive Price Indicator (SPI).
class CommodityPrice {
  const CommodityPrice({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.category,
    required this.unit,
    required this.price,
    this.previousPrice,
    this.changeAbsolute,
    this.changePercent,
    this.trend = 'stable',
    this.locationScope = 'Pakistan (50 Markets, 17 Cities)',
    this.sourceName = 'Pakistan Bureau of Statistics (PBS)',
    this.sourceUrl = 'https://www.pbs.gov.pk/price-statistics/',
    this.sourceType = 'official_statistical',
    this.observationPeriod = 'Week ended Sep 03, 2026',
    this.publishedAt = '2026-09-03',
    required this.retrievedAt,
    this.dataStatus = DataStatusKind.demo,
    this.notes = '',
    this.whatChanged = '',
    this.whyItMatters = '',
    this.financialImpactHint = '',
  });

  final String id;
  final String name;
  final String normalizedName;
  final String category;
  final String unit;
  final double price;
  final double? previousPrice;
  final double? changeAbsolute;
  final double? changePercent;
  final String trend; // 'up', 'down', 'stable'
  final String locationScope;
  final String sourceName;
  final String sourceUrl;
  final String sourceType;
  final String observationPeriod;
  final String publishedAt;
  final DateTime retrievedAt;
  final DataStatusKind dataStatus;
  final String notes;
  final String whatChanged;
  final String whyItMatters;
  final String financialImpactHint;

  bool get isIncreasing => trend == 'up';
  bool get isDecreasing => trend == 'down';

  factory CommodityPrice.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['data_status'] as String?;
    DataStatusKind statusKind = DataStatusKind.demo;
    if (rawStatus == 'live') {
      statusKind = DataStatusKind.live;
    } else if (rawStatus == 'partial') {
      statusKind = DataStatusKind.partial;
    } else if (rawStatus == 'unavailable') {
      statusKind = DataStatusKind.unavailable;
    }

    DateTime retrieved = DateTime.now();
    final rawRetrieved = json['retrieved_at'] as String?;
    if (rawRetrieved != null && rawRetrieved.isNotEmpty) {
      retrieved = DateTime.tryParse(rawRetrieved) ?? DateTime.now();
    }

    return CommodityPrice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      normalizedName: json['normalized_name'] as String? ?? '',
      category: json['category'] as String? ?? 'Other',
      unit: json['unit'] as String? ?? '1 kg',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      previousPrice: (json['previous_price'] as num?)?.toDouble(),
      changeAbsolute: (json['change_absolute'] as num?)?.toDouble(),
      changePercent: (json['change_percent'] as num?)?.toDouble(),
      trend: json['trend'] as String? ?? 'stable',
      locationScope: json['location_scope'] as String? ??
          'Pakistan (50 Markets, 17 Cities)',
      sourceName: json['source_name'] as String? ??
          'Pakistan Bureau of Statistics (PBS)',
      sourceUrl: json['source_url'] as String? ??
          'https://www.pbs.gov.pk/price-statistics/',
      sourceType: json['source_type'] as String? ?? 'official_statistical',
      observationPeriod: json['observation_period'] as String? ?? '',
      publishedAt: json['published_at'] as String? ?? '',
      retrievedAt: retrieved,
      dataStatus: statusKind,
      notes: json['notes'] as String? ?? '',
      whatChanged: json['what_changed'] as String? ?? '',
      whyItMatters: json['why_it_matters'] as String? ?? '',
      financialImpactHint: json['financial_impact_hint'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'normalized_name': normalizedName,
        'category': category,
        'unit': unit,
        'price': price,
        'previous_price': previousPrice,
        'change_absolute': changeAbsolute,
        'change_percent': changePercent,
        'trend': trend,
        'location_scope': locationScope,
        'source_name': sourceName,
        'source_url': sourceUrl,
        'source_type': sourceType,
        'observation_period': observationPeriod,
        'published_at': publishedAt,
        'retrieved_at': retrievedAt.toIso8601String(),
        'data_status': dataStatus.name,
        'notes': notes,
        'what_changed': whatChanged,
        'why_it_matters': whyItMatters,
        'financial_impact_hint': financialImpactHint,
      };
}

/// The aggregate view of essential commodity prices and overall provenance.
class CommodityOverview {
  const CommodityOverview({
    required this.items,
    required this.period,
    required this.sourceName,
    required this.sourceUrl,
    required this.sourceScope,
    required this.status,
    required this.updatedAt,
    this.fallbackReasons = const {},
  });

  final List<CommodityPrice> items;
  final String period;
  final String sourceName;
  final String sourceUrl;
  final String sourceScope;
  final DataStatusKind status;
  final DateTime updatedAt;
  final Map<String, String> fallbackReasons;

  CommodityPrice? itemById(String id) {
    try {
      return items.firstWhere(
        (item) =>
            item.id.toLowerCase() == id.toLowerCase() ||
            item.normalizedName.toLowerCase() == id.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  List<CommodityPrice> filterByCategory(String? category) {
    if (category == null ||
        category.isEmpty ||
        category.toLowerCase() == 'all') {
      return items;
    }
    final catLower = category.toLowerCase();
    return items
        .where((item) =>
            item.category.toLowerCase() == catLower ||
            item.category.toLowerCase().contains(catLower))
        .toList();
  }

  factory CommodityOverview.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final itemsList = rawItems
        .whereType<Map<String, dynamic>>()
        .map((m) => CommodityPrice.fromJson(m))
        .toList();

    final rawSource = json['source'];
    String srcName = 'Pakistan Bureau of Statistics (PBS)';
    String srcUrl = 'https://www.pbs.gov.pk/price-statistics/';
    String srcScope = 'Pakistan (50 Markets, 17 Cities)';
    if (rawSource is Map) {
      srcName = rawSource['name'] as String? ?? srcName;
      srcUrl = rawSource['url'] as String? ?? srcUrl;
      srcScope = rawSource['scope'] as String? ?? srcScope;
    }

    final rawStatus = json['data_status'] as String?;
    DataStatusKind statusKind = DataStatusKind.demo;
    if (rawStatus == 'live') {
      statusKind = DataStatusKind.live;
    } else if (rawStatus == 'partial') {
      statusKind = DataStatusKind.partial;
    } else if (rawStatus == 'unavailable') {
      statusKind = DataStatusKind.unavailable;
    }

    DateTime updated = DateTime.now();
    final rawUpdated = json['updated_at'] as String?;
    if (rawUpdated != null && rawUpdated.isNotEmpty) {
      updated = DateTime.tryParse(rawUpdated) ?? DateTime.now();
    }

    return CommodityOverview(
      items: itemsList,
      period: json['period'] as String? ?? 'Latest Reported Week',
      sourceName: srcName,
      sourceUrl: srcUrl,
      sourceScope: srcScope,
      status: statusKind,
      updatedAt: updated,
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tadbeerai/domain/entities/assistant_api_models.dart';
import 'package:tadbeerai/domain/entities/commodity_price.dart';

void main() {
  group('CommodityPrice Entity & Methods', () {
    test('constructs correctly with full metadata', () {
      final item = CommodityPrice(
        id: 'wheat_flour',
        name: 'Wheat Flour (Atta)',
        normalizedName: 'wheat_flour',
        category: 'Food',
        unit: '10 kg bag',
        price: 1390.0,
        previousPrice: 1380.0,
        changeAbsolute: 10.0,
        changePercent: 0.72,
        trend: 'up',
        sourceName: 'Pakistan Bureau of Statistics (PBS)',
        observationPeriod: 'Week ended Sep 03, 2026',
        retrievedAt: DateTime.parse('2026-09-03T10:00:00Z'),
        dataStatus: DataStatusKind.live,
        whatChanged: 'Prices rose slightly due to regional transportation costs.',
        whyItMatters: 'Staple food consumed by 100% of Pakistani households.',
        financialImpactHint: 'Plan your bulk monthly grocery shopping carefully.',
      );

      expect(item.id, 'wheat_flour');
      expect(item.name, 'Wheat Flour (Atta)');
      expect(item.unit, '10 kg bag');
      expect(item.price, 1390.0);
      expect(item.previousPrice, 1380.0);
      expect(item.changeAbsolute, 10.0);
      expect(item.changePercent, 0.72);
      expect(item.trend, 'up');
      expect(item.isIncreasing, isTrue);
      expect(item.isDecreasing, isFalse);
      expect(item.dataStatus, DataStatusKind.live);
      expect(item.sourceName, 'Pakistan Bureau of Statistics (PBS)');
      expect(item.observationPeriod, 'Week ended Sep 03, 2026');
    });

    test('isDecreasing flag is true when trend is down', () {
      final item = CommodityPrice(
        id: 'tomatoes',
        name: 'Tomatoes',
        normalizedName: 'tomatoes',
        category: 'Vegetables',
        unit: '1 kg',
        price: 110.0,
        previousPrice: 120.0,
        changeAbsolute: -10.0,
        changePercent: -8.33,
        trend: 'down',
        retrievedAt: DateTime.parse('2026-09-03T10:00:00Z'),
        dataStatus: DataStatusKind.live,
      );

      expect(item.isIncreasing, isFalse);
      expect(item.isDecreasing, isTrue);
      expect(item.changePercent, -8.33);
    });

    test('serializes to JSON and deserializes from JSON accurately', () {
      final jsonMap = <String, dynamic>{
        'id': 'chicken_farm',
        'name': 'Live Chicken (Farm)',
        'normalized_name': 'live_chicken',
        'category': 'Meat & Poultry',
        'unit': '1 kg',
        'price': 460.0,
        'previous_price': 440.0,
        'change_absolute': 20.0,
        'change_percent': 4.55,
        'trend': 'up',
        'location_scope': 'Pakistan (50 Markets, 17 Cities)',
        'source_name': 'Pakistan Bureau of Statistics (PBS)',
        'source_url': 'https://www.pbs.gov.pk/price-statistics/',
        'source_type': 'official_statistical',
        'observation_period': 'Week ended Sep 03, 2026',
        'published_at': '2026-09-03',
        'retrieved_at': '2026-09-03T12:00:00.000Z',
        'data_status': 'live',
        'notes': 'Farm-gate price index',
        'what_changed': 'Feed costs increased.',
        'why_it_matters': 'Primary protein source for middle-income urban families.',
        'financial_impact_hint': 'Look for weekend bazaar rates.',
      };

      final parsed = CommodityPrice.fromJson(jsonMap);
      expect(parsed.id, 'chicken_farm');
      expect(parsed.name, 'Live Chicken (Farm)');
      expect(parsed.category, 'Meat & Poultry');
      expect(parsed.unit, '1 kg');
      expect(parsed.price, 460.0);
      expect(parsed.previousPrice, 440.0);
      expect(parsed.changePercent, 4.55);
      expect(parsed.trend, 'up');
      expect(parsed.dataStatus, DataStatusKind.live);
      expect(parsed.whatChanged, 'Feed costs increased.');

      final serialized = parsed.toJson();
      expect(serialized['id'], 'chicken_farm');
      expect(serialized['category'], 'Meat & Poultry');
      expect(serialized['trend'], 'up');
      expect(serialized['data_status'], 'live');
    });

    test('CommodityOverview parses list of items and meta attributes', () {
      final overviewJson = <String, dynamic>{
        'data_status': 'live',
        'period': 'Week ended Sep 03, 2026',
        'source': {
          'name': 'Pakistan Bureau of Statistics (PBS) SPI',
          'url': 'https://www.pbs.gov.pk/price-statistics/',
          'scope': 'Pakistan (50 Markets, 17 Cities)',
        },
        'updated_at': '2026-09-03T12:00:00.000Z',
        'items': [
          {
            'id': 'eggs_farm',
            'name': 'Farm Eggs',
            'normalized_name': 'farm_eggs',
            'category': 'Dairy & Eggs',
            'unit': '1 dozen',
            'price': 310.0,
            'previous_price': 310.0,
            'change_absolute': 0.0,
            'change_percent': 0.0,
            'trend': 'stable',
            'data_status': 'live',
          },
          {
            'id': 'sugar',
            'name': 'Refined Sugar',
            'normalized_name': 'refined_sugar',
            'category': 'Staples',
            'unit': '1 kg',
            'price': 148.0,
            'previous_price': 145.0,
            'change_absolute': 3.0,
            'change_percent': 2.07,
            'trend': 'up',
            'data_status': 'live',
          },
        ],
      };

      final overview = CommodityOverview.fromJson(overviewJson);
      expect(overview.status, DataStatusKind.live);
      expect(overview.period, 'Week ended Sep 03, 2026');
      expect(overview.sourceName, 'Pakistan Bureau of Statistics (PBS) SPI');
      expect(overview.items.length, 2);
      expect(overview.itemById('eggs_farm'), isNotNull);
      expect(overview.itemById('eggs_farm')!.price, 310.0);
      expect(overview.itemById('refined_sugar')!.trend, 'up');
      expect(overview.itemById('non_existent'), isNull);

      final staples = overview.filterByCategory('Staples');
      expect(staples.length, 1);
      expect(staples.first.id, 'sugar');

      final all = overview.filterByCategory('all');
      expect(all.length, 2);
    });
  });
}

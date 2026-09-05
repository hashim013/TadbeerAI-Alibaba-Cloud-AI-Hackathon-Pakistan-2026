import '../../core/constants/app_constants.dart';
import '../../domain/entities/commodity_price.dart';
import '../../domain/entities/economic_indicator.dart';
import '../../domain/entities/economic_overview.dart';
import '../../domain/repositories/economic_repository.dart';
import '../mock/mock_commodity_data.dart';
import '../mock/mock_economic_data.dart';

/// Local, offline economic repository used during the mock phase.
///
/// Serves the bundled synthetic dataset with a simulated latency so the UI
/// exercises realistic loading states. A remote repository (real feeds)
/// replaces this in a later phase without touching UI code.
class MockEconomicRepository implements EconomicRepository {
  MockEconomicRepository({
    DateTime Function()? now,
    Duration latency = AppConstants.mockEconomicLatency,
  })  : _now = now ?? DateTime.now,
        _latency = latency;

  final DateTime Function() _now;
  final Duration _latency;

  @override
  Future<EconomicOverview> getOverview() async {
    await Future<void>.delayed(_latency);
    return MockEconomicData.seed(_now());
  }

  @override
  Future<EconomicIndicator?> getIndicator(String id) async {
    final overview = await getOverview();
    return overview.indicatorById(id);
  }

  @override
  Future<CommodityOverview> getEssentialPrices({String? category}) async {
    await Future<void>.delayed(_latency);
    final overview = MockCommodityData.seed(_now());
    if (category == null || category.isEmpty || category.toLowerCase() == 'all') {
      return overview;
    }
    return CommodityOverview(
      items: overview.filterByCategory(category),
      period: overview.period,
      sourceName: overview.sourceName,
      sourceUrl: overview.sourceUrl,
      sourceScope: overview.sourceScope,
      status: overview.status,
      updatedAt: overview.updatedAt,
    );
  }

  @override
  Future<CommodityPrice?> getCommodity(String id) async {
    final overview = await getEssentialPrices();
    return overview.itemById(id);
  }
}

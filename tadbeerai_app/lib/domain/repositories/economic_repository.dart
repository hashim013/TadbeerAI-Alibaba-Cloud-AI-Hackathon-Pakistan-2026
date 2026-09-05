import '../entities/commodity_price.dart';
import '../entities/economic_overview.dart';
import '../entities/economic_indicator.dart';

/// Economic data contract.
///
/// Ships with both mock and remote API implementations. All providers preserve
/// explicit provenance and fallback safely.
abstract interface class EconomicRepository {
  /// The full economic snapshot for the Economy tab.
  Future<EconomicOverview> getOverview();

  /// A single indicator by id, or null when unknown.
  Future<EconomicIndicator?> getIndicator(String id);

  /// Essential consumer commodities monitored under the PBS SPI.
  Future<CommodityOverview> getEssentialPrices({String? category});

  /// A single commodity by id, or null when unknown.
  Future<CommodityPrice?> getCommodity(String id);
}

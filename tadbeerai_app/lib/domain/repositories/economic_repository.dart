import '../entities/economic_overview.dart';
import '../entities/economic_indicator.dart';

/// Economic data contract.
///
/// Phase 3 ships a mock implementation backed by the bundled demo dataset;
/// a remote implementation (e.g. State Bank of Pakistan feeds) replaces it
/// in a later phase without touching UI code.
abstract interface class EconomicRepository {
  /// The full economic snapshot for the Economy tab.
  Future<EconomicOverview> getOverview();

  /// A single indicator by id, or null when unknown.
  Future<EconomicIndicator?> getIndicator(String id);
}

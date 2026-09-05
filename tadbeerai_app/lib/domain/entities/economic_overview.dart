import 'assistant_api_models.dart';
import 'economic_event.dart';
import 'economic_indicator.dart';

/// The complete economic snapshot exposed to the Economy tab through the
/// repository layer: indicators in display priority order, recent events
/// and the overall freshness of the dataset.
class EconomicOverview {
  const EconomicOverview({
    required this.indicators,
    required this.events,
    required this.updatedAt,
    this.status = DataStatusKind.demo,
    this.fallbackReasons = const {},
  });

  /// Display-priority order: the most important indicators come first.
  final List<EconomicIndicator> indicators;

  /// Most recent first.
  final List<EconomicEvent> events;

  /// When the snapshot was assembled.
  final DateTime updatedAt;

  /// Overall snapshot status (live, partial, demo, unavailable).
  final DataStatusKind status;

  /// Fallback reasons for any indicators that used demo fallback.
  final Map<String, String> fallbackReasons;

  /// Finds an indicator by id, or null when unknown.
  EconomicIndicator? indicatorById(String id) {
    for (final indicator in indicators) {
      if (indicator.id == id) return indicator;
    }
    return null;
  }
}

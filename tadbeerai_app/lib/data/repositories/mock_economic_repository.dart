import '../../core/constants/app_constants.dart';
import '../../domain/entities/economic_indicator.dart';
import '../../domain/entities/economic_overview.dart';
import '../../domain/repositories/economic_repository.dart';
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
}

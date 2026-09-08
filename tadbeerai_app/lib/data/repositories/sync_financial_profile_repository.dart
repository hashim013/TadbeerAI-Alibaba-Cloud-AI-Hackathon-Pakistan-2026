import 'package:dio/dio.dart';

import '../../domain/entities/financial_profile.dart';
import '../../domain/repositories/financial_profile_repository.dart';

/// [FinancialProfileRepository] that keeps the local prefs cache as the source
/// of truth and, on save, fire-and-forget mirrors the persona to the backend's
/// existing `POST /users/persona` endpoint for signed-in (non-guest) users.
///
/// The local write is always awaited first, so the UI stays consistent and
/// fully functional offline. The network push is best-effort and never surfaces
/// errors — mirroring the fire-and-forget theme sync in
/// `app_settings_providers.dart`. The shared Dio already carries the Firebase ID
/// token via [AuthInterceptor], so the persona lands under the correct uid.
class SyncFinancialProfileRepository implements FinancialProfileRepository {
  SyncFinancialProfileRepository({
    required FinancialProfileRepository local,
    required Dio dio,
    required String? Function() uidProvider,
  })  : _local = local,
        _dio = dio,
        _uidProvider = uidProvider;

  final FinancialProfileRepository _local;
  final Dio _dio;
  final String? Function() _uidProvider;

  /// Human-readable persona/goal labels — matching the wording the assistant
  /// sends as financial context (see `ApiAssistantRepository`), so the backend
  /// stores a consistent, display-ready persona string.
  static const Map<Persona, String> _personaLabels = {
    Persona.student: 'Student',
    Persona.salaried: 'Salaried Employee',
    Persona.businessOwner: 'Business Owner',
    Persona.shopOwner: 'Shop Owner',
  };

  static const Map<PrimaryGoal, String> _goalLabels = {
    PrimaryGoal.emergencyFund: 'Emergency Fund',
    PrimaryGoal.saveMore: 'Save More',
    PrimaryGoal.education: 'Education',
    PrimaryGoal.newDevice: 'New Device',
    PrimaryGoal.businessGrowth: 'Business Growth',
    PrimaryGoal.reduceSpending: 'Reduce Spending',
    PrimaryGoal.other: 'Other',
  };

  @override
  Future<FinancialProfile?> loadProfile() => _local.loadProfile();

  @override
  Future<void> clearProfile() => _local.clearProfile();

  @override
  Future<void> saveProfile(FinancialProfile profile) async {
    // Local is the source of truth — always persist it first.
    await _local.saveProfile(profile);
    // Best-effort cloud mirror; never awaited by the caller's success path.
    _syncToBackend(profile);
  }

  void _syncToBackend(FinancialProfile profile) {
    final uid = (_uidProvider() ?? '').trim();
    // Persona sync is for real accounts only — skip signed-out and pure-local
    // guests (same convention as the theme sync and AppUser.isGuest).
    if (uid.isEmpty || uid.startsWith('guest')) return;
    try {
      _dio.post('/users/persona', data: {
        'user_id': uid,
        if (profile.persona != null) 'persona': _personaLabels[profile.persona],
        if (profile.primaryGoal != null)
          'primary_goal': _goalLabels[profile.primaryGoal],
        if (profile.monthlyIncome != null)
          'monthly_income': profile.monthlyIncome,
        if (profile.monthlyEssentialExpenses != null)
          'monthly_essential_expenses': profile.monthlyEssentialExpenses,
        if (profile.totalSavings != null) 'total_savings': profile.totalSavings,
        if (profile.financialHealthScore != null)
          'financial_health_score': profile.financialHealthScore,
        if (profile.name != null) 'name': profile.name,
        'is_guest': false,
      }).catchError((_) => Response(requestOptions: RequestOptions(path: '')));
    } catch (_) {
      // Never let a background sync failure break the local save.
    }
  }
}

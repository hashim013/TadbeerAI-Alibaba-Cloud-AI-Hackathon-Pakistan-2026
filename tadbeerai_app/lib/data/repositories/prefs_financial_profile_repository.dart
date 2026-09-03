import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/financial_profile.dart';
import '../../domain/repositories/financial_profile_repository.dart';

/// SharedPreferences-backed financial profile repository.
///
/// Stores the full profile as a single JSON string under
/// [AppConstants.prefFinancialProfile].
class PrefsFinancialProfileRepository implements FinancialProfileRepository {
  PrefsFinancialProfileRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<FinancialProfile?> loadProfile() async {
    final raw = _prefs.getString(AppConstants.prefFinancialProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      return FinancialProfile.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // Corrupt data — treat as no profile.
      return null;
    }
  }

  @override
  Future<void> saveProfile(FinancialProfile profile) => _prefs.setString(
        AppConstants.prefFinancialProfile,
        jsonEncode(profile.toJson()),
      );

  @override
  Future<void> clearProfile() =>
      _prefs.remove(AppConstants.prefFinancialProfile);
}

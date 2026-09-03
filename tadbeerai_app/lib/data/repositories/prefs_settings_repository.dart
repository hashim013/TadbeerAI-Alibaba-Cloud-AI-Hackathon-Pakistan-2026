import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/repositories/settings_repository.dart';

/// SharedPreferences-backed settings repository.
class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<bool> isOnboardingComplete() async =>
      _prefs.getBool(AppConstants.prefOnboardingComplete) ?? false;

  @override
  Future<void> completeOnboarding() =>
      _prefs.setBool(AppConstants.prefOnboardingComplete, true);

  @override
  Future<String?> readThemeMode() => Future.value(
        _prefs.getString(AppConstants.prefThemeMode),
      );

  @override
  Future<void> writeThemeMode(String mode) =>
      _prefs.setString(AppConstants.prefThemeMode, mode);
}

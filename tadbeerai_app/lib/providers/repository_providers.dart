import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/mock_auth_repository.dart';
import '../data/repositories/prefs_financial_profile_repository.dart';
import '../data/repositories/prefs_settings_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/financial_profile_repository.dart';
import '../domain/repositories/settings_repository.dart';

/// Overridden in `main()` with the real [SharedPreferences] instance
/// (or a mock in tests) — the composition root of the dependency graph.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPrefsProvider must be overridden before the app runs',
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => MockAuthRepository(ref.watch(sharedPrefsProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => PrefsSettingsRepository(ref.watch(sharedPrefsProvider)),
);

final financialProfileRepositoryProvider = Provider<FinancialProfileRepository>(
  (ref) => PrefsFinancialProfileRepository(ref.watch(sharedPrefsProvider)),
);

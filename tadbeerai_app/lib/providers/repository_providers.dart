import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/api_config.dart';
import '../data/repositories/firebase_auth_repository.dart';
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

/// Exposes the FirebaseAuth instance, or null when Firebase is not initialized
/// (e.g. headless unit tests).
final firebaseAuthProvider = Provider<fb.FirebaseAuth?>((ref) {
  try {
    return fb.FirebaseAuth.instance;
  } catch (_) {
    return null;
  }
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  if (ApiConfig.useMockAuth || firebaseAuth == null) {
    return MockAuthRepository(ref.watch(sharedPrefsProvider));
  }
  return FirebaseAuthRepository(firebaseAuth: firebaseAuth);
});

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => PrefsSettingsRepository(ref.watch(sharedPrefsProvider)),
);

final financialProfileRepositoryProvider = Provider<FinancialProfileRepository>(
  (ref) => PrefsFinancialProfileRepository(ref.watch(sharedPrefsProvider)),
);

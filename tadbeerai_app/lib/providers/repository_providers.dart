import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/api_config.dart';
import '../data/repositories/firebase_auth_repository.dart';
import '../data/repositories/mock_auth_repository.dart';
import '../data/repositories/prefs_financial_profile_repository.dart';
import '../data/repositories/prefs_settings_repository.dart';
import '../data/repositories/sync_financial_profile_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/financial_profile_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../features/auth/auth_controller.dart';
import 'assistant_providers.dart';

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
  final prefs = ref.watch(sharedPrefsProvider);
  if (ApiConfig.useMockAuth || firebaseAuth == null) {
    return MockAuthRepository(prefs);
  }
  return FirebaseAuthRepository(
    firebaseAuth: firebaseAuth,
    prefs: prefs,
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => PrefsSettingsRepository(ref.watch(sharedPrefsProvider)),
);

/// Financial profile: local prefs cache as the source of truth, with a
/// best-effort cloud mirror to `POST /users/persona` for signed-in users.
final financialProfileRepositoryProvider = Provider<FinancialProfileRepository>(
  (ref) => SyncFinancialProfileRepository(
    local: PrefsFinancialProfileRepository(ref.watch(sharedPrefsProvider)),
    dio: ref.watch(apiDioProvider),
    uidProvider: () => ref.read(authControllerProvider)?.id,
  ),
);

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tadbeerai/data/repositories/mock_auth_repository.dart';
import 'package:tadbeerai/data/repositories/prefs_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MockAuthRepository', () {
    test('signIn persists a restorable session', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = MockAuthRepository(prefs);

      expect(await repo.currentUser(), isNull);

      final user = await repo.signIn(
        email: 'ahsan.khan@tadbeer.ai',
        password: 'secret123',
      );

      expect(user.email, 'ahsan.khan@tadbeer.ai');
      expect(user.name, 'Ahsan Khan');

      final restored = await repo.currentUser();
      expect(restored, user);
    });

    test('signUp keeps the provided name', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = MockAuthRepository(prefs);

      final user = await repo.signUp(
        name: 'Fatima Noor',
        email: 'fatima@tadbeer.ai',
        password: 'secret123',
      );

      expect(user.name, 'Fatima Noor');
      expect(user.id, isNotEmpty);
      expect(await repo.currentUser(), user);
    });

    test('signOut clears the session', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = MockAuthRepository(prefs);

      await repo.signIn(email: 'a@b.co', password: 'secret123');
      expect(await repo.currentUser(), isNotNull);

      await repo.signOut();
      expect(await repo.currentUser(), isNull);
    });

    test('corrupt persisted session is treated as signed out', () async {
      SharedPreferences.setMockInitialValues({'session_user': '{not json'});
      final prefs = await SharedPreferences.getInstance();
      final repo = MockAuthRepository(prefs);

      expect(await repo.currentUser(), isNull);
    });
  });

  group('PrefsSettingsRepository', () {
    test('onboarding starts incomplete and completes persistently', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PrefsSettingsRepository(prefs);

      expect(await repo.isOnboardingComplete(), isFalse);

      await repo.completeOnboarding();
      expect(await repo.isOnboardingComplete(), isTrue);

      // Same backing store — flag survives a new repository instance.
      final repo2 = PrefsSettingsRepository(prefs);
      expect(await repo2.isOnboardingComplete(), isTrue);
    });

    test('theme mode round-trips', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PrefsSettingsRepository(prefs);

      expect(await repo.readThemeMode(), isNull);

      await repo.writeThemeMode('dark');
      expect(await repo.readThemeMode(), 'dark');
    });
  });
}

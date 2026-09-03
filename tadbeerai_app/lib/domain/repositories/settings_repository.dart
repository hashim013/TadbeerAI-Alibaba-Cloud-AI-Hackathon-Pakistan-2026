/// Local app-settings contract (onboarding state, theme persistence).
abstract interface class SettingsRepository {
  Future<bool> isOnboardingComplete();

  Future<void> completeOnboarding();

  /// 'light' | 'dark' | 'system', or null when never set.
  Future<String?> readThemeMode();

  Future<void> writeThemeMode(String mode);
}

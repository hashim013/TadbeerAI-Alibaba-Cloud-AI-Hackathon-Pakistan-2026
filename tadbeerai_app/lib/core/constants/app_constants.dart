/// App-wide constants for Tadbeer AI 2.0.
abstract final class AppConstants {
  // ── Identity ──────────────────────────────────────────────────────────
  static const appName = 'Tadbeer AI';
  static const appTagline = 'Your AI-Powered Financial Intelligence Companion';
  static const corePromise =
      'Understand your money. Understand the economy. Plan with confidence.';

  // ── Official brand assets ─────────────────────────────────────────────
  static const assetLogo = 'assets/images/tadbeer_logo.png';
  static const assetLogoTransparent =
      'assets/images/tadbeer_logo_transparent.png';
  static const assetOnboardingUnderstand =
      'assets/images/onboarding_understand.png';
  static const assetOnboardingManage = 'assets/images/onboarding_manage.png';
  static const assetOnboardingPlan = 'assets/images/onboarding_plan.png';

  // ── SharedPreferences keys ────────────────────────────────────────────
  static const prefOnboardingComplete = 'onboarding_complete';
  static const prefSessionUser = 'session_user';
  static const prefThemeMode = 'theme_mode';
  static const prefFinanceData = 'mock_finance_data_v1';
  static const prefFinancialProfile = 'financial_profile_v1';

  // ── Timing ────────────────────────────────────────────────────────────
  static const splashDuration = Duration(milliseconds: 3000);
  static const mockAuthLatency = Duration(milliseconds: 600);
  static const mockFinanceLatency = Duration(milliseconds: 350);
  static const mockEconomicLatency = Duration(milliseconds: 450);
  static const mockAssistantLatency = Duration(milliseconds: 800);
}

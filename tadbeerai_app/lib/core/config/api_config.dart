/// Backend connection settings.
///
/// Every value comes from `--dart-define` at build time so the base URL is
/// configured in one place (never hardcoded throughout the app) and no
/// secret ever ships inside Flutter — the backend alone owns the provider
/// keys (Gemini, Groq, SBP/PBS).
///
/// Typical values:
/// - Android emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:8000`
///   (the emulator's loopback to the host machine — also the safe default)
/// - Physical device:   `--dart-define=API_BASE_URL=http://<LAN-IP>:8000`
/// - Production:       supplied explicitly at build/deployment time
class ApiConfig {
  ApiConfig._();

  /// Base URL of the FastAPI backend.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Endpoint of the multi-agent assistant chat.
  static const String assistantChatPath = '/v1/assistant/chat';

  /// Endpoint of the macroeconomic indicators snapshot.
  static const String economySnapshotPath = '/v1/economy/snapshot';

  /// Endpoint of the PBS SPI essential commodity prices.
  static const String essentialPricesPath = '/v1/economy/essential-prices';

  /// Assistant data source: `live` (default) answers through the real
  /// backend; `demo` keeps the offline mock for UI development and tests.
  static const String assistantMode = String.fromEnvironment(
    'ASSISTANT_MODE',
    defaultValue: 'live',
  );

  static bool get useMockAssistant => assistantMode == 'demo';

  /// Economy data source: `live` (default) fetches from backend; `demo` uses offline mock.
  static bool get useMockEconomy => assistantMode == 'demo';

  /// Authentication data source: `firebase` (default) connects to Firebase Auth;
  /// `demo` keeps offline mock for headless unit tests.
  static const String authMode = String.fromEnvironment(
    'AUTH_MODE',
    defaultValue: 'firebase',
  );

  static bool get useMockAuth => authMode == 'demo';
}

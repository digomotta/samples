/// App-wide configuration constants.
class AppConfig {
  AppConfig._();

  /// Use mock data instead of calling the real business agent.
  /// Set to 'false' via --dart-define=USE_MOCK=false to use live agent.
  static const bool useMock = String.fromEnvironment(
        'USE_MOCK',
        defaultValue: 'true',
      ) ==
      'true';

  /// Base URL of the UCP A2A business agent.
  static const String agentBaseUrl = String.fromEnvironment(
    'AGENT_URL',
    defaultValue: 'http://localhost:10999',
  );

  /// URL for the buyer's UCP profile (capability negotiation).
  static const String ucpProfileUrl = String.fromEnvironment(
    'UCP_PROFILE_URL',
    defaultValue: 'http://localhost:3100/buyer_profile.json',
  );

  /// A2A UCP extension URI.
  static const String ucpExtensionUri =
      'https://ucp.dev/specification/reference?v=2026-01-11';
}

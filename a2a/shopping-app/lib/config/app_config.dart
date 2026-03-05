/// App-wide configuration constants.
class AppConfig {
  AppConfig._();

  /// Use mock data instead of calling the real business agent.
  /// Set to 'true' via --dart-define=USE_MOCK=true to use mock.
  static const bool useMock = String.fromEnvironment(
        'USE_MOCK',
        defaultValue: 'false',
      ) ==
      'true';

  /// Base URL of the UCP A2A business agent (via CORS proxy).
  /// Run proxy.py to forward requests to the agent on port 10999.
  static const String agentBaseUrl = String.fromEnvironment(
    'AGENT_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// URL for the buyer's UCP profile (capability negotiation).
  /// Proxied through to the business agent's /.well-known/ucp.
  static const String ucpProfileUrl = String.fromEnvironment(
    'UCP_PROFILE_URL',
    defaultValue: 'http://localhost:8080/.well-known/ucp',
  );

  /// A2A UCP extension URI.
  static const String ucpExtensionUri =
      'https://ucp.dev/specification/reference?v=2026-01-11';
}

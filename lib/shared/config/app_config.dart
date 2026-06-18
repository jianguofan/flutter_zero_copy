/// Multi-environment configuration for the Lava App.
///
/// Usage:
/// ```dart
/// final config = AppConfig.dev;  // or .staging, .prod
/// print(config.apiBaseUrl);
/// ```

/// Deployment environment.
enum AppEnvironment { dev, staging, prod }

/// Immutable app configuration loaded at startup.
class AppConfig {
  final AppEnvironment environment;
  final String apiBaseUrl;
  final String mqttBrokerHost;
  final int mqttBrokerPort;
  final bool enableSsl;
  final Duration connectionTimeout;
  final Duration heartbeatInterval;
  final bool enableDebugLogging;

  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.mqttBrokerHost,
    this.mqttBrokerPort = 1884,
    this.enableSsl = false,
    this.connectionTimeout = const Duration(seconds: 10),
    this.heartbeatInterval = const Duration(seconds: 30),
    this.enableDebugLogging = false,
  });

  // ── Pre-built configurations ──

  /// Development configuration (emulators, local MQTT).
  static const dev = AppConfig(
    environment: AppEnvironment.dev,
    apiBaseUrl: 'http://localhost:8080/api',
    mqttBrokerHost: 'localhost',
    mqttBrokerPort: 1884,
    enableDebugLogging: true,
  );

  /// Staging configuration (test cloud, staging API).
  static const staging = AppConfig(
    environment: AppEnvironment.staging,
    apiBaseUrl: 'https://staging-api.snapmaker.com/api',
    mqttBrokerHost: 'staging-mqtt.snapmaker.com',
    mqttBrokerPort: 8883,
    enableSsl: true,
    enableDebugLogging: true,
  );

  /// Production configuration (US).
  static const prod = AppConfig(
    environment: AppEnvironment.prod,
    apiBaseUrl: 'https://id.snapmaker.com/api',
    mqttBrokerHost: 'mqtt.snapmaker.com',
    mqttBrokerPort: 8883,
    enableSsl: true,
  );

  /// Production configuration (CN).
  static const prodCN = AppConfig(
    environment: AppEnvironment.prod,
    apiBaseUrl: 'https://api.snapmaker.cn/api',
    mqttBrokerHost: 'mqtt.snapmaker.cn',
    mqttBrokerPort: 8883,
    enableSsl: true,
  );

  /// Whether this is a development build.
  bool get isDev => environment == AppEnvironment.dev;

  /// Whether SSL/TLS should be used for MQTT connections.
  bool get useSecureMqtt => enableSsl;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zero_copy/shared/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('dev config has correct defaults', () {
      const config = AppConfig.dev;
      expect(config.environment, equals(AppEnvironment.dev));
      expect(config.apiBaseUrl, contains('localhost'));
      expect(config.mqttBrokerPort, equals(1884));
      expect(config.enableSsl, isFalse);
      expect(config.enableDebugLogging, isTrue);
      expect(config.isDev, isTrue);
      expect(config.useSecureMqtt, isFalse);
    });

    test('staging config uses SSL', () {
      const config = AppConfig.staging;
      expect(config.environment, equals(AppEnvironment.staging));
      expect(config.enableSsl, isTrue);
      expect(config.enableDebugLogging, isTrue);
      expect(config.isDev, isFalse);
      expect(config.useSecureMqtt, isTrue);
    });

    test('prod config has debug logging off', () {
      const config = AppConfig.prod;
      expect(config.environment, equals(AppEnvironment.prod));
      expect(config.enableDebugLogging, isFalse);
      expect(config.enableSsl, isTrue);
    });

    test('connectionTimeout has reasonable default', () {
      const config = AppConfig.dev;
      expect(config.connectionTimeout.inSeconds, equals(10));
    });

    test('heartbeatInterval has reasonable default', () {
      const config = AppConfig.dev;
      expect(config.heartbeatInterval.inSeconds, equals(30));
    });

    test('AppEnvironment enum has 3 values', () {
      expect(AppEnvironment.values.length, equals(3));
    });
  });
}

import 'package:lava_device_sdk/src/models/types.dart';
import 'package:lava_device_sdk/src/mqtt/mqtt_transport.dart';
import 'package:test/test.dart';

void main() {
  group('MqttTransport', () {
    test('stores config correctly', () {
      final config = MqttConfig(
        host: '192.168.1.100',
        port: 1883,
        clientId: 'test_client',
        username: 'user',
        password: 'pass',
      );

      expect(config.host, '192.168.1.100');
      expect(config.port, 1883);
      expect(config.clientId, 'test_client');
    });

    test('default port is 1883', () {
      final config = MqttConfig(host: 'localhost');
      expect(config.port, 1883);
    });

    test('default subscribe topics include /status and /response', () {
      final config = MqttConfig(host: 'localhost');
      expect(config.subscribeTopics, contains('/status'));
      expect(config.subscribeTopics, contains('/response'));
    });

    test('transport implements DeviceTransport interface', () {
      final config = MqttConfig(host: 'localhost');
      final transport = MqttTransport(config: config);
      expect(transport.isConnected, isFalse);
      expect(transport.messageStream, isNotNull);
      transport.dispose();
    });
  });
}

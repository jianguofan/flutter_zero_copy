import 'dart:convert';
import 'package:lava_device_sdk/src/client/device_client.dart';
import 'package:lava_device_sdk/src/core/schema.dart';
import 'package:lava_device_sdk/src/core/state_tree.dart';
import 'package:lava_device_sdk/src/models/types.dart';
import 'package:test/test.dart';

DeviceSchema _testSchema() {
  return DeviceSchema.fromJson(jsonDecode(_testJson) as Map<String, dynamic>);
}

void main() {
  group('DeviceClient construction', () {
    test('can be created with moonraker factory', () {
      final schema = _testSchema();
      final client = DeviceClient.moonraker(
        schema: schema,
        mqttConfig: MqttConfig(host: 'localhost'),
      );

      expect(client.schema, same(schema));
      expect(client.state, isA<StateTree>());
      expect(client.transport, isNotNull);

      client.dispose();
    });

    test('client is not connected initially', () {
      final schema = _testSchema();
      final client = DeviceClient.moonraker(
        schema: schema,
        mqttConfig: MqttConfig(host: 'localhost'),
      );

      expect(client.transport.isConnected, isFalse);

      client.dispose();
    });
  });
}

const _testJson = '''
{
  "version": "1.0",
  "deviceType": "test",
  "fields": {
    "toolhead.position": {
      "type": "array",
      "default": [0, 0, 0, 0]
    },
    "print_stats.state": {
      "type": "string",
      "default": "idle"
    }
  },
  "dataSource": {
    "type": "moonraker",
    "subscribe": {
      "toolhead": null,
      "print_stats": null
    }
  }
}
''';

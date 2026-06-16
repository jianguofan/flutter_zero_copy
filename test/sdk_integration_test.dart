import 'package:flutter_test/flutter_test.dart';
import 'package:lava_device_sdk/lava_device_sdk.dart';

/// SDK Integration Tests
///
/// Verify that the lava-device-controll SDK is properly integrated and its
/// public API compiles and functions correctly.
void main() {
  group('SDK API surface', () {
    test('DeviceHub is importable', () {
      // Verify the DeviceHub class exists and is accessible
      expect(DeviceHub, isNotNull);
    });

    test('DeviceClient is importable', () {
      // Verify DeviceClient is exported
      expect(DeviceClient, isNotNull);
    });

    test('DeviceSchema is importable', () {
      expect(DeviceSchema, isNotNull);
    });

    test('StateTree is importable', () {
      expect(StateTree, isNotNull);
    });

    test('MqttTransport is importable', () {
      expect(MqttTransport, isNotNull);
    });

    test('LanStrategy is importable', () {
      expect(LanStrategy, isNotNull);
    });

    test('WanStrategy is importable', () {
      expect(WanStrategy, isNotNull);
    });

    test('ConnectionStrategy is importable', () {
      expect(ConnectionStrategy, isNotNull);
    });
  });

  group('ConnectionStrategy types', () {
    test('ConnectionProgress is importable', () {
      expect(ConnectionProgress, isNotNull);
    });

    test('CloudApiClient is a type', () {
      // CloudApiClient is an abstract interface from the SDK
      expect(CloudApiClient, isNotNull);
    });
  });

  group('DeviceSchema - basic construction', () {
    test('can create DeviceSchema from JSON map', () {
      // Verify DeviceSchema can be constructed with minimal valid input
      final json = {
        'fields': <String, dynamic>{
          'temperature.nozzle': {
            'type': 'number',
            'strategy': 'replace',
            'interval': 1000,
          },
        },
      };

      final schema = DeviceSchema.fromJson(json);
      expect(schema.keys.length, equals(1));
      expect(schema.keys.first, equals('temperature.nozzle'));
      expect(schema.lookup('temperature.nozzle'), isNotNull);
    });

    test('DeviceSchema validate returns empty for valid schema', () {
      final json = {
        'fields': <String, dynamic>{
          'temperature.nozzle': {
            'type': 'number',
            'strategy': 'replace',
            'interval': 1000,
            'min': 0,
            'max': 300,
          },
        },
      };

      final schema = DeviceSchema.fromJson(json);
      final errors = schema.validate();
      expect(errors, isEmpty);
    });

    test('DeviceSchema keysByPrefix works', () {
      final json = {
        'fields': <String, dynamic>{
          'temperature.nozzle': {'type': 'number'},
          'temperature.bed': {'type': 'number'},
          'print_stats.state': {'type': 'string'},
        },
      };

      final schema = DeviceSchema.fromJson(json);
      final tempKeys = schema.keysByPrefix('temperature');
      expect(tempKeys.length, equals(2));
    });
  });
}

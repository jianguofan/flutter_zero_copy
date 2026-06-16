import 'dart:convert';
import 'package:lava_device_sdk/src/core/schema.dart';
import 'package:lava_device_sdk/src/core/field_definition.dart';
import 'package:test/test.dart';

void main() {
  group('DeviceSchema.fromJson', () {
    test('loads fields from JSON', () {
      final json = jsonDecode(_schemaJson) as Map<String, dynamic>;
      final schema = DeviceSchema.fromJson(json);

      expect(schema.lookup('extruder.temperature')!.type, FieldType.number);
      expect(schema.lookup('toolhead.position')!.type, FieldType.array);
      expect(schema.lookup('print_stats.state')!.type, FieldType.enum_);
    });

    test('throws on missing fields key', () {
      expect(
        () => DeviceSchema.fromJson({}),
        throwsArgumentError,
      );
    });

    test('parses update strategy', () {
      final json = jsonDecode(_schemaJson) as Map<String, dynamic>;
      final schema = DeviceSchema.fromJson(json);

      final temp = schema.lookup('extruder.temperature')!;
      expect(temp.strategy, UpdateStrategy.replace);

      final progress = schema.lookup('virtual_sdcard.progress')!;
      expect(progress.strategy, UpdateStrategy.max);
    });

    test('parses validation constraints', () {
      final json = jsonDecode(_schemaJson) as Map<String, dynamic>;
      final schema = DeviceSchema.fromJson(json);

      final temp = schema.lookup('extruder.temperature')!;
      expect(temp.min, 0);
      expect(temp.max, 500);

      final progress = schema.lookup('virtual_sdcard.progress')!;
      expect(progress.min, 0);
      expect(progress.max, 1);
    });

    test('parses default values', () {
      final json = jsonDecode(_schemaJson) as Map<String, dynamic>;
      final schema = DeviceSchema.fromJson(json);

      expect(schema.lookup('print_stats.state')!.defaultValue, 'standby');
      expect(schema.lookup('toolhead.position')!.defaultValue, [0, 0, 0, 0]);
      expect(schema.lookup('extruder.temperature')!.defaultValue, 0);
      expect(schema.lookup('print_stats.filename')!.defaultValue, '');
    });

    test('parses readonly flag', () {
      final json = jsonDecode(_schemaJson) as Map<String, dynamic>;
      final schema = DeviceSchema.fromJson(json);

      expect(schema.lookup('device_info.device_id')!.readonly, true);
      expect(schema.lookup('extruder.temperature')!.readonly, false);
    });
  });

  group('DeviceSchema.lookup', () {
    final schema = DeviceSchema.fromJson(jsonDecode(_schemaJson) as Map<String, dynamic>);

    test('returns FieldDefinition for known key', () {
      final field = schema.lookup('extruder.temperature');
      expect(field, isNotNull);
      expect(field!.key, 'extruder.temperature');
    });

    test('returns null for unknown key', () {
      expect(schema.lookup('nonexistent.field'), isNull);
    });
  });

  group('DeviceSchema.keysByPrefix', () {
    final schema = DeviceSchema.fromJson(jsonDecode(_schemaJson) as Map<String, dynamic>);

    test('matches category prefix "print_stats.*"', () {
      final keys = schema.keysByPrefix('print_stats.*');
      expect(keys, contains('print_stats.state'));
      expect(keys, contains('print_stats.filename'));
      expect(keys, contains('print_stats.total_duration'));
      expect(keys, contains('print_stats.print_duration'));
      expect(keys, isNot(contains('extruder.temperature')));
    });

    test('wildcard "*" returns all keys', () {
      final keys = schema.keysByPrefix('*');
      expect(keys.length, greaterThan(5));
      expect(keys, contains('toolhead.position'));
    });

    test('exact key returns itself', () {
      final keys = schema.keysByPrefix('extruder.temperature');
      expect(keys, ['extruder.temperature']);
    });

    test('unknown prefix returns empty', () {
      final keys = schema.keysByPrefix('unknown.*');
      expect(keys, isEmpty);
    });
  });

  group('DeviceSchema.validate', () {
    test('valid schema returns no errors', () {
      final schema = DeviceSchema.fromJson(jsonDecode(_schemaJson) as Map<String, dynamic>);
      final errors = schema.validate();
      expect(errors, isEmpty);
    });

    test('enum field without values produces error', () {
      final json = {
        'fields': {
          'bad.enum_field': {
            'type': 'enum',
            'default': 'x',
          },
        },
      };
      final schema = DeviceSchema.fromJson(json);
      final errors = schema.validate();
      expect(errors.length, 1);
      expect(errors.first.message, contains('enum'));
    });

    test('min > max produces error', () {
      final json = {
        'fields': {
          'bad.field': {
            'type': 'number',
            'default': 5,
            'validate': {'min': 100, 'max': 0},
          },
        },
      };
      final schema = DeviceSchema.fromJson(json);
      final errors = schema.validate();
      // 2 errors: min>max + default value fails validation
      expect(errors.any((e) => e.message.contains('min')), isTrue);
    });
  });

  group('DeviceSchema.dataSource', () {
    test('stores raw dataSource config', () {
      final schema = DeviceSchema.fromJson(jsonDecode(_schemaJson) as Map<String, dynamic>);
      final ds = schema.dataSource;
      expect(ds['type'], 'moonraker');
      expect(ds['responseTopic'], '/response');
      expect(ds['statusTopic'], '/status');
      expect(ds['subscribe'], isA<Map>());
      expect(ds['subscribe']['toolhead'], isNull);
      expect(ds['subscribe']['extruder'], ['temperature', 'target']);
    });
  });
}

const _schemaJson = '''
{
  "version": "1.0",
  "deviceType": "snapmaker_a350",
  "fields": {
    "device_info.device_id": {
      "type": "string",
      "default": "",
      "readonly": true,
      "strategy": "first"
    },
    "toolhead.position": {
      "type": "array",
      "default": [0, 0, 0, 0]
    },
    "extruder.temperature": {
      "type": "number",
      "default": 0,
      "validate": {"min": 0, "max": 500},
      "strategy": "replace"
    },
    "print_stats.state": {
      "type": "enum",
      "default": "standby",
      "enum": ["standby", "printing", "paused", "complete", "cancelled", "error"]
    },
    "print_stats.filename": {
      "type": "string",
      "default": ""
    },
    "print_stats.total_duration": {
      "type": "number",
      "default": 0
    },
    "print_stats.print_duration": {
      "type": "number",
      "default": 0
    },
    "virtual_sdcard.progress": {
      "type": "number",
      "default": 0,
      "validate": {"min": 0, "max": 1},
      "strategy": "max"
    }
  },
  "dataSource": {
    "type": "moonraker",
    "subscribe": {
      "toolhead": null,
      "extruder": ["temperature", "target"],
      "print_stats": null,
      "virtual_sdcard": ["progress", "is_active"]
    },
    "responseTopic": "/response",
    "statusTopic": "/status"
  }
}
''';

import 'dart:convert';
import 'package:lava_device_sdk/src/core/schema.dart';
import 'package:lava_device_sdk/src/core/state_patch.dart';
import 'package:lava_device_sdk/src/core/state_tree.dart';
import 'package:test/test.dart';

DeviceSchema _testSchema() {
  return DeviceSchema.fromJson(jsonDecode(_schemaJson) as Map<String, dynamic>);
}

void main() {
  group('StateTree initialization', () {
    test('populates defaults from schema', () {
      final state = StateTree(schema: _testSchema());

      expect(state.get<num>('extruder.temperature'), 0);
      expect(state.get<String>('print_stats.state'), 'standby');
      expect(state.get<List>('toolhead.position'), [0, 0, 0, 0]);
    });

    test('creates nested structure from dotted keys', () {
      final state = StateTree(schema: _testSchema());

      final exported = state.export();
      expect(exported['extruder'], isA<Map>());
      expect(exported['extruder']['temperature'], 0);
    });
  });

  group('StateTree.patch', () {
    test('updates values and get returns new value', () {
      final state = StateTree(schema: _testSchema());

      state.patch({'extruder.temperature': 210.5});
      expect(state.get<num>('extruder.temperature'), 210.5);
    });

    test('batch updates multiple fields', () {
      final state = StateTree(schema: _testSchema());

      state.patch({
        'extruder.temperature': 210.5,
        'print_stats.state': 'printing',
        'print_stats.filename': 'model.gcode',
      });

      expect(state.get<num>('extruder.temperature'), 210.5);
      expect(state.get<String>('print_stats.state'), 'printing');
      expect(state.get<String>('print_stats.filename'), 'model.gcode');
    });

    test('rejects invalid value range', () {
      final state = StateTree(schema: _testSchema());

      state.patch({'extruder.temperature': 999}); // > max 500
      expect(state.get<num>('extruder.temperature'), 0); // stays default
    });

    test('rejects invalid value type', () {
      final state = StateTree(schema: _testSchema());

      state.patch({'extruder.temperature': 'hot'}); // not a number
      expect(state.get<num>('extruder.temperature'), 0); // stays default
    });

    test('applies "max" strategy', () {
      final state = StateTree(schema: _testSchema());

      state.patch({'virtual_sdcard.progress': 0.5});
      expect(state.get<num>('virtual_sdcard.progress'), 0.5);

      state.patch({'virtual_sdcard.progress': 0.3});
      expect(state.get<num>('virtual_sdcard.progress'), 0.5); // stays at max

      state.patch({'virtual_sdcard.progress': 0.8});
      expect(state.get<num>('virtual_sdcard.progress'), 0.8); // goes up
    });

    test('applies "first" strategy', () {
      final state = StateTree(schema: _testSchema());

      state.patch({'device_info.device_id': '001'});
      expect(state.get<String>('device_info.device_id'), '001');

      state.patch({'device_info.device_id': '002'});
      expect(state.get<String>('device_info.device_id'), '001'); // stays first
    });

    test('rejects enum value not in list', () {
      final state = StateTree(schema: _testSchema());

      state.patch({'print_stats.state': 'invalid_state'});
      expect(state.get<String>('print_stats.state'), 'standby'); // stays default
    });
  });

  group('StateTree.export', () {
    test('exports nested JSON', () {
      final state = StateTree(schema: _testSchema());
      state.patch({
        'extruder.temperature': 210.5,
        'print_stats.state': 'printing',
      });

      final json = state.export();
      expect(json['extruder']['temperature'], 210.5);
      expect(json['print_stats']['state'], 'printing');
    });

    test('export returns a deep copy', () {
      final state = StateTree(schema: _testSchema());
      final json1 = state.export();
      json1['extruder']['temperature'] = 999;

      expect(state.get<num>('extruder.temperature'), 0); // unaffected
    });
  });

  group('StateTree.reset', () {
    test('clears all data and re-populates defaults', () {
      final state = StateTree(schema: _testSchema());
      state.patch({
        'extruder.temperature': 210.5,
        'print_stats.state': 'printing',
      });

      state.reset(_testSchema());

      expect(state.get<num>('extruder.temperature'), 0); // back to default
      expect(state.get<String>('print_stats.state'), 'standby');
    });
  });

  group('StateTree.watch', () {
    test('receives patch for matching prefix', () async {
      final state = StateTree(schema: _testSchema());

      final patches = <Map<String, dynamic>>[];
      state.watch('print_stats.*').listen((patch) {
        patches.add(patch.values);
      });

      state.patch({'print_stats.state': 'printing'});

      // 16ms batch window — wait for it
      await Future.delayed(const Duration(milliseconds: 50));

      expect(patches.length, 1);
      expect(patches.first, contains('print_stats.state'));
    });

    test('does not receive patch for non-matching prefix', () async {
      final state = StateTree(schema: _testSchema());

      final patches = <Map<String, dynamic>>[];
      state.watch('extruder.*').listen((patch) {
        patches.add(patch.values);
      });

      state.patch({'print_stats.state': 'printing'});

      await Future.delayed(const Duration(milliseconds: 50));
      expect(patches, isEmpty);
    });

    test('batch merges within 16ms window', () async {
      final state = StateTree(schema: _testSchema());

      final patches = <StatePatch>[];
      state.watch('print_stats.*').listen((patch) {
        patches.add(patch);
      });

      // Multiple updates in quick succession
      state.patch({'print_stats.state': 'printing'});
      state.patch({'print_stats.filename': 'model.gcode'});
      state.patch({'print_stats.total_duration': 3600.5});

      await Future.delayed(const Duration(milliseconds: 50));

      // Should be merged into 1 patch
      expect(patches.length, 1);
      expect(patches.first.values.length, 3);
      expect(patches.first.values, contains('print_stats.state'));
      expect(patches.first.values, contains('print_stats.filename'));
      expect(patches.first.values, contains('print_stats.total_duration'));
    });
  });

  group('StateTree.dispose', () {
    test('cleans up correctly', () {
      final state = StateTree(schema: _testSchema());
      state.patch({'extruder.temperature': 210.5});

      state.dispose();
      // no throw = ok
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
    }
  }
}
''';

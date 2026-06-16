import 'dart:async';
import 'dart:convert';
import 'package:lava_device_sdk/src/core/schema.dart';
import 'package:lava_device_sdk/src/core/state_tree.dart';
import 'package:test/test.dart';

DeviceSchema _testSchema() {
  return DeviceSchema.fromJson(jsonDecode(_testJson) as Map<String, dynamic>);
}

void main() {
  group('Subscription prefix matching', () {
    late StateTree state;

    setUp(() {
      state = StateTree(schema: _testSchema());
    });

    tearDown(() {
      state.dispose();
    });

    test('"print_stats.*" only receives print_stats fields', () async {
      final patches = <Map<String, dynamic>>[];
      state.watch('print_stats.*').listen((patch) {
        patches.add(patch.values);
      });

      state.patch({'print_stats.state': 'printing'});
      state.patch({'extruder.temperature': 210.5});

      await Future.delayed(const Duration(milliseconds: 50));

      expect(patches.length, 1);
      expect(patches.first, containsPair('print_stats.state', 'printing'));
    });

    test('"extruder.*" only receives extruder fields', () async {
      final patches = <Map<String, dynamic>>[];
      state.watch('extruder.*').listen((patch) {
        patches.add(patch.values);
      });

      state.patch({'extruder.temperature': 210.5});
      state.patch({'print_stats.state': 'printing'});

      await Future.delayed(const Duration(milliseconds: 50));

      expect(patches.length, 1);
      expect(patches.first, containsPair('extruder.temperature', 210.5));
    });

    test('"*" receives all fields', () async {
      final patches = <Map<String, dynamic>>[];
      state.watch('*').listen((patch) {
        patches.add(patch.values);
      });

      state.patch({'extruder.temperature': 210.5});
      state.patch({'print_stats.state': 'printing'});

      await Future.delayed(const Duration(milliseconds: 50));

      expect(patches.length, 1);
      expect(patches.first, containsPair('extruder.temperature', 210.5));
      expect(patches.first, containsPair('print_stats.state', 'printing'));
    });
  });

  group('Subscription batching', () {
    late StateTree state;

    setUp(() {
      state = StateTree(schema: _testSchema());
    });

    tearDown(() {
      state.dispose();
    });

    test('multiple rapid patches merged into one emit', () async {
      final patches = <Map<String, dynamic>>[];
      state.watch('extruder.*').listen((patch) {
        patches.add(patch.values);
      });

      state.patch({'extruder.temperature': 100});
      state.patch({'extruder.temperature': 200});
      state.patch({'extruder.temperature': 300});

      await Future.delayed(const Duration(milliseconds: 50));

      expect(patches.length, 1);
      // Last write wins (strategy is "replace")
      expect(patches.first['extruder.temperature'], 300);
    });

    test('patches separated by >16ms are separate emits', () async {
      final patches = <Map<String, dynamic>>[];
      state.watch('extruder.*').listen((patch) {
        patches.add(patch.values);
      });

      state.patch({'extruder.temperature': 100});
      await Future.delayed(const Duration(milliseconds: 30));

      state.patch({'extruder.temperature': 200});

      await Future.delayed(const Duration(milliseconds: 50));

      expect(patches.length, 2);
    });
  });

  group('Subscription dispose', () {
    late StateTree state;

    setUp(() {
      state = StateTree(schema: _testSchema());
    });

    test('subscription stops after cancel', () async {
      final patches = <Map<String, dynamic>>[];
      final sub = state.watch('extruder.*').listen((patch) {
        patches.add(patch.values);
      });

      state.patch({'extruder.temperature': 100});
      await Future.delayed(const Duration(milliseconds: 30));
      expect(patches.length, 1);

      await sub.cancel();

      state.patch({'extruder.temperature': 200});
      await Future.delayed(const Duration(milliseconds: 30));
      expect(patches.length, 1); // no new patches
    });
  });
}

const _testJson = '''
{
  "version": "1.0",
  "deviceType": "test",
  "fields": {
    "extruder.temperature": {
      "type": "number",
      "default": 0,
      "strategy": "replace"
    },
    "extruder.target": {
      "type": "number",
      "default": 0,
      "strategy": "replace"
    },
    "print_stats.state": {
      "type": "string",
      "default": "idle"
    },
    "print_stats.filename": {
      "type": "string",
      "default": ""
    }
  }
}
''';

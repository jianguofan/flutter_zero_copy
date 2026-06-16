import 'dart:async';
import 'package:lava_device_sdk/lava_device_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('MetadataStateManager', () {
    late MetadataStateManager mgr;
    final schema = DeviceSchema.fromJson(const {
      'fields': {
        'temperature': {'type': 'number', 'default': 0, 'validate': {'min': 0, 'max': 500}},
        'target': {'type': 'number', 'default': 0, 'validate': {'min': 0, 'max': 500}},
        'status': {'type': 'string', 'default': 'offline'},
        'progress': {'type': 'number', 'default': 0, 'strategy': 'max'},
        'history': {'type': 'array', 'default': [], 'strategy': 'append'},
        'count': {'type': 'number', 'default': 0, 'strategy': 'increment'},
        'meta': {'type': 'object', 'default': {}, 'strategy': 'merge'},
      },
    });

    setUp(() {
      mgr = MetadataStateManager(schema: schema);
    });
    tearDown(() => mgr.dispose());

    test('stateStream emits on batchUpdate', () async {
      final events = <StateUpdateEvent>[];
      final sub = mgr.stateStream.listen(events.add);

      mgr.batchUpdate({'temperature': 42});
      // Wait for 16ms batch timer → StatePatch → StateUpdateEvent
      await Future.delayed(const Duration(milliseconds: 50));

      mgr.batchUpdate({'target': 100});
      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(events.any((e) => e.key == 'temperature' && e.value == 42), isTrue);
      expect(events.any((e) => e.key == 'target' && e.value == 100), isTrue);
    });

    test('watchField receives only matching key', () async {
      final values = <num>[];
      final sub = mgr.watchField<num>('temperature').listen(values.add);

      mgr.batchUpdate({'temperature': 50});
      await Future.delayed(const Duration(milliseconds: 50));

      mgr.batchUpdate({'target': 200});
      await Future.delayed(const Duration(milliseconds: 50));

      mgr.batchUpdate({'temperature': 75});
      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(values, [50, 75]); // target=200 not included
    });

    test('watchFields batches into 16ms snapshots', () async {
      final snapshots = <Map<String, dynamic>>[];
      final sub = mgr.watchFields(['temperature', 'target']).listen(snapshots.add);

      mgr.batchUpdate({'temperature': 10, 'target': 20});
      await Future.delayed(const Duration(milliseconds: 50));

      mgr.batchUpdate({'temperature': 30});
      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(snapshots.length, greaterThanOrEqualTo(1));
      // First snapshot should have both keys from the first batchUpdate
      final first = snapshots.first;
      expect(first['temperature'], 10);
      expect(first['target'], 20);
    });

    test('watchPrefix with 16ms batching', () async {
      final snapshots = <Map<String, dynamic>>[];
      final sub = mgr.watchPrefix('temp').listen(snapshots.add);

      mgr.batchUpdate({'temperature': 66, 'target': 67});
      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(snapshots.length, greaterThanOrEqualTo(1));
    });

    test('max strategy keeps highest value', () {
      mgr.batchUpdate({'progress': 0.3});
      expect(mgr.get<num>('progress'), 0.3);

      mgr.batchUpdate({'progress': 0.5});
      expect(mgr.get<num>('progress'), 0.5);

      mgr.batchUpdate({'progress': 0.2});
      expect(mgr.get<num>('progress'), 0.5); // keeps max
    });

    test('append strategy concatenates lists', () {
      mgr.batchUpdate({'history': [1, 2]});
      mgr.batchUpdate({'history': [3, 4]});
      expect(mgr.get<List>('history'), [1, 2, 3, 4]);
    });

    test('increment strategy adds to current value', () {
      mgr.batchUpdate({'count': 1});
      mgr.batchUpdate({'count': 2});
      expect(mgr.get<num>('count'), 3);
    });

    test('merge strategy merges objects', () {
      mgr.batchUpdate({'meta': {'a': 1}});
      mgr.batchUpdate({'meta': {'b': 2}});
      final meta = mgr.get<Map<String, dynamic>>('meta');
      expect(meta['a'], 1);
      expect(meta['b'], 2);
    });

    test('invalid values are skipped', () {
      mgr.batchUpdate({'temperature': 999}); // > max=500
      expect(mgr.get<num>('temperature'), 0); // stays at default
    });

    test('export returns full tree', () {
      mgr.batchUpdate({'temperature': 100, 'status': 'online'});
      final exported = mgr.export();
      expect(exported['temperature'], 100);
      expect(exported['status'], 'online');
    });

    test('reset clears state and applies new schema defaults', () {
      mgr.reset(DeviceSchema.fromJson(const {
        'fields': {
          'new_field': {'type': 'string', 'default': 'hello'},
        },
      }));
      expect(mgr.get<String>('new_field'), 'hello');
    });
  });
}

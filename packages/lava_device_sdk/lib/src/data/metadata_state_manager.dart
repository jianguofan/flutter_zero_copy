import 'dart:async';
import 'package:lava_device_sdk/src/core/schema.dart';
import 'package:lava_device_sdk/src/core/state_patch.dart';
import 'package:lava_device_sdk/src/core/state_tree.dart';
import 'package:lava_device_sdk/src/data/state_update_event.dart';

/// Unified metadata-driven state manager.
///
/// Wraps [StateTree] and provides a higher-level API:
/// - Single unified [stateStream] for all state changes
/// - Field-level subscription via [watchField]
/// - Batch subscription with 16ms batching via [watchFields] and [watchPrefix]
/// - Batch update with validation + strategy via [batchUpdate]
class MetadataStateManager {
  final StateTree _tree;
  final StreamController<StateUpdateEvent> _controller =
      StreamController<StateUpdateEvent>.broadcast();
  StreamSubscription<StatePatch>? _broadcastSub;

  MetadataStateManager({DeviceSchema? schema})
      : _tree = StateTree(schema: schema) {
    // Bridge StateTree's batched patches → individual StateUpdateEvents
    _broadcastSub = _tree.watch('*').listen((patch) {
      for (final entry in patch.values.entries) {
        _controller.add(StateUpdateEvent(
          key: entry.key,
          value: entry.value,
          timestamp: patch.timestamp,
        ));
      }
    });
  }

  /// Single unified stream — all state changes flow through here.
  Stream<StateUpdateEvent> get stateStream => _controller.stream;

  /// Field-level subscription.
  /// Returns a stream that emits only when [key] changes.
  Stream<T> watchField<T>(String key) {
    return stateStream
        .where((event) => event.key == key)
        .map((event) => event.value as T);
  }

  /// Batch subscription — emits a snapshot Map whenever any watched key changes.
  /// 16ms batching is handled by the underlying SubscriptionManager.
  Stream<Map<String, dynamic>> watchFields(List<String> keys) {
    return _tree.watchKeys(keys).map((patch) => patch.values);
  }

  /// Prefix subscription — emits a snapshot Map for all keys under [prefix].
  /// 16ms batching is handled by the underlying SubscriptionManager.
  Stream<Map<String, dynamic>> watchPrefix(String prefix) {
    return _tree.watch(prefix).map((patch) => patch.values);
  }

  /// Batch update with validation and strategy.
  /// Invalid values are silently skipped.
  void batchUpdate(Map<String, dynamic> updates) {
    _tree.patch(updates);
  }

  /// Get current value for a dotted key.
  T get<T>(String key) => _tree.get<T>(key);

  /// Export full state tree as nested JSON.
  Map<String, dynamic> export() => _tree.export();

  /// Reset state tree with a new schema.
  void reset(DeviceSchema schema) => _tree.reset(schema);

  /// Subscribe low-level: returns raw [StatePatch] stream for a prefix.
  Stream<StatePatch> watch(String prefix) => _tree.watch(prefix);

  void dispose() {
    _broadcastSub?.cancel();
    _controller.close();
    _tree.dispose();
  }
}

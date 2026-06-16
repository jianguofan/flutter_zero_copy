import 'dart:typed_data';
import 'package:lava_device_sdk/src/core/state_tree.dart';

enum DeviceEventType { online, offline }

class DeviceEvent {
  final DeviceEventType type;
  final DateTime timestamp;

  DeviceEvent(this.type) : timestamp = DateTime.now();

  @override
  String toString() => 'DeviceEvent($type)';
}

abstract class DeviceAdapter {
  /// Called when MQTT receives a message on a subscribed topic.
  void onMessage(String topic, Uint8List payload);

  /// Stream of messages to be published via MQTT.
  Stream<(String topic, Uint8List payload)> get outgoing;

  /// Stream of device lifecycle events (online/offline from Last Will).
  Stream<DeviceEvent> get deviceEvents;

  /// Called after MQTT connection is established.
  Future<void> onConnected(StateTree state, DeviceSchemaRef schemaRef);

  /// Send a command and await its JSON-RPC response.
  /// Returns null on timeout or error.
  Future<Map<String, dynamic>?> send(String method, [Map<String, dynamic>? params, Duration timeout = const Duration(seconds: 10)]);

  /// Clean up resources.
  Future<void> dispose();
}

/// Lightweight reference so the adapter can read schema fields.
class DeviceSchemaRef {
  final Map<String, dynamic>? Function(String key)? _lookup;
  final List<String> Function(String prefix) _keysByPrefix;
  final Map<String, dynamic> dataSource;

  DeviceSchemaRef({
    required Map<String, dynamic>? Function(String key)? lookup,
    required List<String> Function(String prefix) keysByPrefix,
    required this.dataSource,
  })  : _lookup = lookup,
        _keysByPrefix = keysByPrefix;

  List<String> keysByPrefix(String prefix) => _keysByPrefix(prefix);
  Map<String, dynamic>? lookup(String key) => _lookup?.call(key);
}

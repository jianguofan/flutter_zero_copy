import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:lava_device_sdk/src/adapter/adapter.dart';
import 'package:lava_device_sdk/src/adapter/moonraker/json_rpc.dart';
import 'package:lava_device_sdk/src/adapter/moonraker/moonraker_config.dart';
import 'package:lava_device_sdk/src/core/state_tree.dart';
import 'package:lava_device_sdk/src/data/request_tracker_manager.dart';

class MoonrakerAdapter implements DeviceAdapter {
  final MoonrakerConfig _config;
  final StreamController<(String, Uint8List)> _outgoingController =
      StreamController.broadcast();
  final StreamController<DeviceEvent> _deviceEventController =
      StreamController.broadcast();
  final RequestTrackerManager _requestTracker = RequestTrackerManager();

  StateTree? _state;
  int _nextId = 1;

  MoonrakerAdapter({required MoonrakerConfig config}) : _config = config {
    _requestTracker.start();
  }

  factory MoonrakerAdapter.fromDataSource(Map<String, dynamic> dataSource) {
    return MoonrakerAdapter(config: MoonrakerConfig.fromDataSource(dataSource));
  }

  /// Convenience factory: specify subscribe objects, response/status topics directly.
  factory MoonrakerAdapter.forTopics({
    Map<String, List<String>?> subscribe = const {},
    String responseTopic = '/response',
    String statusTopic = '/status',
    String? notificationTopic,
  }) {
    return MoonrakerAdapter(config: MoonrakerConfig(
      subscribe: subscribe,
      responseTopic: responseTopic,
      statusTopic: statusTopic,
      notificationTopic: notificationTopic,
    ));
  }

  @override
  Stream<(String topic, Uint8List payload)> get outgoing =>
      _outgoingController.stream;

  @override
  Stream<DeviceEvent> get deviceEvents => _deviceEventController.stream;

  @override
  Future<void> onConnected(StateTree state, DeviceSchemaRef schemaRef) async {
    _state = state;

    // Step 1: Subscribe first (fire-and-forget) — ensures no gap
    final subscribeMsg = _buildSubscribeMessage();
    _outgoingController
        .add(('/request', Uint8List.fromList(utf8.encode(subscribeMsg))));

    // Step 2: Query full current state — fills in initial values
    await _queryAndPatch();
  }

  String _buildSubscribeMessage() {
    final request = JsonRpcRequest(
      id: _nextId++,
      method: 'printer.objects.subscribe',
      params: {'objects': _config.subscribe},
    );
    return request.encode();
  }

  @override
  void onMessage(String topic, Uint8List payload) {
    if (topic == _config.statusTopic) {
      _handleStatus(payload);
    } else if (topic == _config.responseTopic) {
      _handleResponse(payload);
    } else if (_config.notificationTopic != null &&
        topic == _config.notificationTopic) {
      _handleNotification(payload);
    }
  }

  // ── Status push (notify_status_update) ──

  void _handleStatus(Uint8List payload) {
    if (_state == null) return;

    try {
      final str = utf8.decode(payload);
      final json = jsonDecode(str) as Map<String, dynamic>;

      Map<String, dynamic>? status;
      if (json['status'] is Map<String, dynamic>) {
        status = json['status'] as Map<String, dynamic>;
      } else if (json['params'] is List &&
          (json['params'] as List).isNotEmpty) {
        final firstParam = (json['params'] as List).first;
        if (firstParam is Map<String, dynamic> &&
            firstParam['status'] is Map<String, dynamic>) {
          status = firstParam['status'] as Map<String, dynamic>;
        }
      }
      if (status == null) return;

      final updates = <String, dynamic>{};
      _expandStatus(status, '', updates);

      if (updates.isNotEmpty) {
        _state!.patch(updates);
      }
    } catch (_) {
      // Malformed status payload — skip
    }
  }

  void _expandStatus(
      Map<String, dynamic> obj, String prefix, Map<String, dynamic> out) {
    for (final entry in obj.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (entry.value is Map<String, dynamic>) {
        _expandStatus(entry.value as Map<String, dynamic>, key, out);
      } else {
        out[key] = entry.value;
      }
    }
  }

  // ── Response (JSON-RPC reply to a pending request) ──

  void _handleResponse(Uint8List payload) {
    final response = JsonRpcResponse.tryParse(payload);
    if (response == null) return;

    final id = response.id.toString();
    if (response.isError) {
      // Return error payload as the result so callers can inspect code/message
      _requestTracker.complete(id, response.error ?? {});
    } else {
      _requestTracker.complete(id, response.result ?? {});
    }
  }

  // ── Notification (Last Will, klippy state changes) ──

  void _handleNotification(Uint8List payload) {
    try {
      final str = utf8.decode(payload);
      final json = jsonDecode(str) as Map<String, dynamic>;

      if (json['server'] == 'online') {
        _onDeviceOnline();
      } else if (json['server'] == 'offline') {
        _deviceEventController.add(DeviceEvent(DeviceEventType.offline));
      }
    } catch (_) {
      // Malformed notification — skip
    }
  }

  Future<void> _onDeviceOnline() async {
    if (_state == null) return;

    // Discard stale state and reset to defaults
    _state!.clearToDefaults();

    // Re-populate with fresh current state
    await _queryAndPatch();

    _deviceEventController.add(DeviceEvent(DeviceEventType.online));
  }

  // ── Full state query ──

  Future<void> _queryAndPatch() async {
    final result = await send(
      'printer.objects.query',
      {'objects': _config.subscribe},
    );
    if (result == null || _state == null) return;

    final status = result['status'] as Map<String, dynamic>?;
    if (status == null) return;

    final updates = <String, dynamic>{};
    _expandStatus(status, '', updates);
    _state!.patch(updates);
  }

  // ── Send with request tracking ──

  @override
  Future<Map<String, dynamic>?> send(
    String method, [
    Map<String, dynamic>? params,
    Duration timeout = const Duration(seconds: 10),
  ]) async {
    final id = _nextId++;
    final request = JsonRpcRequest(id: id, method: method, params: params);
    final encoded = request.encode();

    final future = _requestTracker.track(
      id: id.toString(),
      timeout: timeout,
    );

    _outgoingController
        .add(('/request', Uint8List.fromList(utf8.encode(encoded))));

    try {
      return await future;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Lifecycle ──

  @override
  Future<void> dispose() async {
    _requestTracker.dispose();
    await _outgoingController.close();
    await _deviceEventController.close();
    _state = null;
  }
}

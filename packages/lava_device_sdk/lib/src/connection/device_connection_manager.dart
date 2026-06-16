import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:lava_device_sdk/src/connection/device_health_monitor.dart';
import 'package:lava_device_sdk/src/connection/link_quality_monitor.dart';
import 'package:lava_device_sdk/src/connection/smart_heartbeat_manager.dart';
import 'package:lava_device_sdk/src/data/connection_metrics.dart';
import 'package:lava_device_sdk/src/data/metadata_state_manager.dart';
import 'package:lava_device_sdk/src/data/request_tracker_manager.dart';
import 'package:lava_device_sdk/src/mqtt/mqtt_transport.dart';
import 'package:lava_device_sdk/src/transport/transport.dart';

/// Unified device connection orchestrator.
///
/// Layers:
/// ```
/// DeviceClient (adapter + schema)
///   → DeviceConnectionManager (this)
///     → DeviceTransport (MQTT / WebSocket)
///     → MetadataStateManager     ← unified state
///     → RequestTrackerManager    ← request timeout + adaptive extension
///     → SmartHeartbeatManager    ← idle-triggered heartbeat
///     → DeviceHealthMonitor      ← dual-signal health evaluation
///     → LinkQualityMonitor       ← multi-signal link quality (PUBACK + RTT + Delta)
/// ```
///
/// Adaptive timeouts: when link quality degrades, pending command timeouts
/// are extended rather than cleared. Only a truly dead connection triggers
/// cleanup (via transport-layer reconnect or manual disconnect).
class DeviceConnectionManager {
  final DeviceTransport _transport;
  final MetadataStateManager _stateManager;
  final RequestTrackerManager _requestTracker;
  late final SmartHeartbeatManager _heartbeat;
  late final DeviceHealthMonitor _healthMonitor;
  late final LinkQualityMonitor _linkMonitor;

  StreamSubscription<TransportMessage>? _messageSub;
  StreamSubscription<Duration>? _pubAckSub;
  StreamSubscription<void>? _disconnectSub;
  int _requestSeq = 0;

  /// Optional callback for custom message handling (adapter layer).
  void Function(String topic, Map<String, dynamic> json)? onMessage;

  /// Optional callback for notification messages.
  void Function(Map<String, dynamic> json)? onNotification;

  DeviceConnectionManager({
    required DeviceTransport transport,
    MetadataStateManager? stateManager,
    RequestTrackerManager? requestTracker,
    DeviceHealthMonitor? healthMonitor,
    LinkQualityMonitor? linkMonitor,
    bool isWanMode = false,
    this.onMessage,
    this.onNotification,
  })  : _transport = transport,
        _stateManager = stateManager ?? MetadataStateManager(),
        _requestTracker = requestTracker ?? RequestTrackerManager(),
        _healthMonitor = healthMonitor ?? DeviceHealthMonitor(),
        _linkMonitor = linkMonitor ?? LinkQualityMonitor(isWanMode: isWanMode);

  MetadataStateManager get state => _stateManager;
  RequestTrackerManager get requests => _requestTracker;
  DeviceTransport get transport => _transport;
  DeviceHealthMonitor get healthMonitor => _healthMonitor;
  DeviceHealth get health => _healthMonitor.health;
  Stream<HealthChangeEvent> get healthStream => _healthMonitor.healthStream;
  LinkQualityMonitor get linkMonitor => _linkMonitor;
  LinkQuality get linkQuality => _linkMonitor.quality;
  Stream<LinkQualityEvent> get linkQualityStream => _linkMonitor.qualityStream;

  /// Get the shared [ConnectionMetrics] instance from the MqttTransport.
  /// Returns null if the transport is not MqttTransport.
  ConnectionMetrics? get metrics =>
      _transport is MqttTransport ? (_transport as MqttTransport).metrics : null;

  // ── Adaptive timeout ──

  /// Command timeout adjusted for current link quality.
  /// Degraded links get longer timeouts instead of killing commands.
  Duration get _adaptiveTimeout => switch (_linkMonitor.quality) {
        LinkQuality.good => const Duration(seconds: 10),
        LinkQuality.degraded => const Duration(seconds: 30),
        LinkQuality.poor => const Duration(seconds: 60),
      };

  // ── Connect ──

  /// Connect to the device.
  ///
  /// [onHeartbeat] — called each heartbeat cycle. If provided, should send
  ///   `server.info` and return the parsed result. If omitted, a default
  ///   implementation sends `server.info` via [sendRpc] and parses
  ///   klippy_connected / klippy_state.
  Future<void> connect({
    Future<Map<String, dynamic>?> Function()? onHeartbeat,
  }) async {
    _heartbeat = SmartHeartbeatManager(
      onSendHeartbeat: onHeartbeat ?? _defaultHeartbeat,
    );

    await _transport.connect();

    _messageSub = _transport.messageStream.listen(_handleMessage);

    // Wire PUBACK delay and disconnect streams from MqttTransport
    if (_transport is MqttTransport) {
      final mqtt = _transport as MqttTransport;
      _pubAckSub = mqtt.pubAckDelayStream.listen(_linkMonitor.onPubAckDelay);
      _disconnectSub =
          mqtt.onDisconnectStream.listen((_) => _linkMonitor.onDisconnected());
    }

    // React to link quality changes
    _linkMonitor.qualityStream.listen(_onLinkQualityChanged);

    _heartbeat.start();
    _requestTracker.start();
    _linkMonitor.start();

    // Default: assume MQTT is alive once transport connects
    _healthMonitor.onMqttOnline();
  }

  // ── Heartbeat ──

  Future<void> _defaultHeartbeat() async {
    final startTime = DateTime.now();
    try {
      final seqId = ++_requestSeq;
      final payload = jsonEncode({
        'jsonrpc': '2.0',
        'method': 'server.info',
        'id': seqId,
      });

      final future = _requestTracker.track(
        id: seqId.toString(),
        timeout: const Duration(seconds: 5),
      );

      _transport.send('/request', Uint8List.fromList(utf8.encode(payload)));

      final response = await future;
      final rtt = DateTime.now().difference(startTime);
      final result = response['result'] as Map<String, dynamic>?;

      final klippyConnected = result?['klippy_connected'] as bool? ?? false;
      final klippyState = result?['klippy_state'] as String?;

      _healthMonitor.onHeartbeatResult(
        true,
        rtt: rtt,
        klippyConnected: klippyConnected,
        klippyState: klippyState,
      );
      _linkMonitor.onHeartbeatResult(true, rtt: rtt);
      metrics?.recordHeartbeat(true, rtt: rtt);
      metrics?.recordFullPathLatency(rtt);
      // Record Link B (Delta) if available from the link monitor
      final delta = _linkMonitor.lastDelta;
      if (delta != null) {
        metrics?.recordLinkBLatency(delta);
      }
    } on TimeoutException {
      _healthMonitor.onHeartbeatResult(false);
      _linkMonitor.onHeartbeatResult(false);
      metrics?.recordHeartbeat(false);
    } catch (_) {
      _healthMonitor.onHeartbeatResult(false);
      _linkMonitor.onHeartbeatResult(false);
      metrics?.recordHeartbeat(false);
    }
  }

  // ── Send RPC ──

  /// Send a JSON-RPC request and return the response.
  ///
  /// If [timeout] is not specified, uses an adaptive timeout based on
  /// current link quality (10s good / 30s degraded / 60s poor).
  Future<Map<String, dynamic>> sendRpc(
    String method, {
    Map<String, dynamic>? params,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _adaptiveTimeout;
    final seqId = ++_requestSeq;
    final payload = jsonEncode({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
      'id': seqId,
    });

    final future = _requestTracker.track(
      id: seqId.toString(),
      timeout: effectiveTimeout,
    );
    _transport.send('/request', Uint8List.fromList(utf8.encode(payload)));
    _heartbeat.recordCommunication();

    // Feed command result to link monitor (fire-and-forget)
    _trackCommandResult(future);

    return future;
  }

  void _trackCommandResult(Future<Map<String, dynamic>> future) {
    metrics?.recordCommandSent();
    future.then(
      (_) {
        _linkMonitor.onCommandResult(true);
        metrics?.recordCommandResult(true);
      },
      onError: (e) {
        _linkMonitor.onCommandResult(false);
        metrics?.recordCommandResult(false,
            timedOut: e is TimeoutException);
      },
    );
  }

  /// Send raw bytes to a topic.
  void sendRaw(String topic, Uint8List payload) {
    _transport.send(topic, payload);
    _heartbeat.recordCommunication();
  }

  // ── Link quality reaction ──

  void _onLinkQualityChanged(LinkQualityEvent event) {
    metrics?.recordQualityChange(event.previous, event.current);

    // Extend pending timeouts when quality drops
    if (event.current == LinkQuality.degraded &&
        event.previous == LinkQuality.good) {
      _requestTracker.extendAllPending(const Duration(seconds: 20));
      metrics?.recordTimeoutExtension();
    } else if (event.current == LinkQuality.poor &&
        event.previous != LinkQuality.poor) {
      _requestTracker.extendAllPending(const Duration(seconds: 50));
      metrics?.recordTimeoutExtension();
    }

    // Prolonged severe degradation → force reconnect
    if (event.current == LinkQuality.poor && event.consecutiveCount >= 6) {
      _transport.disconnect();
    }
  }

  // ── Message routing ──

  void _handleMessage(TransportMessage msg) {
    _heartbeat.recordCommunication();

    try {
      final json = jsonDecode(utf8.decode(msg.payload)) as Map<String, dynamic>;

      // JSON-RPC response with id → complete pending request
      final idField = json['id'];
      if (idField != null) {
        final id = idField is int ? idField.toString() : idField.toString();
        if (_requestTracker.totalCount > 0) {
          _requestTracker.complete(id, json);
        }
        return;
      }

      // Status push (notify_status_update) → update state
      _handleStatusPush(json);

      // Notification → health monitor + custom handler
      _handleNotification(json);
    } catch (_) {
      // Non-JSON payload — ignore
    }

    // Forward to adapter callback for custom handling
    onMessage?.call(msg.topic, {});
  }

  void _handleStatusPush(Map<String, dynamic> json) {
    final method = json['method'] as String?;
    if (method == null) return;

    if (json['params'] is List && (json['params'] as List).isNotEmpty) {
      final params = json['params'] as List;
      final data = params[0];
      if (data is Map<String, dynamic>) {
        final status = data['status'] as Map<String, dynamic>? ?? data;
        _stateManager.batchUpdate(_flatten(status));
      }
      return;
    }

    if (json['status'] is Map<String, dynamic>) {
      _stateManager.batchUpdate(
        _flatten(json['status'] as Map<String, dynamic>),
      );
    }
  }

  void _handleNotification(Map<String, dynamic> json) {
    // MQTT Last Will (server online/offline)
    if (json['server'] == 'online') {
      _healthMonitor.onMqttOnline();
    } else if (json['server'] == 'offline') {
      _healthMonitor.onMqttOffline();
    }

    // Klipper state changes
    if (json['name'] == 'notify_klippy_state_changed') {
      _healthMonitor.onKlippyStateChanged(
        connected: json['state'] != null,
        state: json['state'] as String?,
      );
    }

    // Forward to custom handler
    onNotification?.call(json);
  }

  Map<String, dynamic> _flatten(Map<String, dynamic> obj,
      [String prefix = '']) {
    final out = <String, dynamic>{};
    for (final e in obj.entries) {
      final key = prefix.isEmpty ? e.key : '$prefix.${e.key}';
      if (e.value is Map<String, dynamic>) {
        out.addAll(_flatten(e.value as Map<String, dynamic>, key));
      } else {
        out[key] = e.value;
      }
    }
    return out;
  }

  void updateState(Map<String, dynamic> data) {
    _stateManager.batchUpdate(data);
  }

  // ── Disconnect ──

  Future<void> disconnect() async {
    _linkMonitor.stop();
    _healthMonitor.reset();
    _heartbeat.stop();
    _requestTracker.stop();
    await _messageSub?.cancel();
    await _pubAckSub?.cancel();
    await _disconnectSub?.cancel();
    await _transport.disconnect();
  }

  Future<void> dispose() async {
    await disconnect();
    _stateManager.dispose();
    _requestTracker.dispose();
    _healthMonitor.dispose();
    _linkMonitor.dispose();
    await _transport.dispose();
  }
}

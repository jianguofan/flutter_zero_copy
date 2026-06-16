import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:mqtt5_client/mqtt5_client.dart';
import 'package:mqtt5_client/mqtt5_server_client.dart';
import 'package:lava_device_sdk/src/data/connection_metrics.dart';
import 'package:lava_device_sdk/src/models/types.dart';
import 'package:lava_device_sdk/src/transport/transport.dart';

class MqttTransport implements DeviceTransport {
  final MqttConfig _config;
  final ConnectionMetrics metrics;
  MqttServerClient? _client;
  final StreamController<TransportMessage> _messageController =
      StreamController.broadcast();

  // Exponential backoff state
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _intentionalDisconnect = false;
  final _random = Random();

  // PUBACK delay tracking (App ↔ Broker segment)
  final _pubAckController = StreamController<Duration>.broadcast();
  final _pendingPubTimestamps = <int, DateTime>{};

  // Disconnect event stream (for LinkQualityMonitor)
  final _disconnectController = StreamController<void>.broadcast();

  /// Stream of PUBACK round-trip delays (App → Broker → App).
  /// Each event is the time between publishMessage() and the broker's PUBACK.
  /// In WAN mode this covers only the App ↔ AWS IoT segment.
  Stream<Duration> get pubAckDelayStream => _pubAckController.stream;

  /// Stream of unsolicited disconnect events.
  Stream<void> get onDisconnectStream => _disconnectController.stream;

  MqttTransport({
    required MqttConfig config,
    ConnectionMetrics? metrics,
  })  : _config = config,
        metrics = metrics ?? ConnectionMetrics();

  @override
  Stream<TransportMessage> get messageStream => _messageController.stream;

  @override
  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  @override
  Future<void> connect() async {
    _intentionalDisconnect = false;
    _reconnectAttempts = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    _reconnectTimer?.cancel();
    metrics.recordConnectAttempt();

    final clientId = _config.clientId ??
        'lava_device_${DateTime.now().millisecondsSinceEpoch}';

    final client = MqttServerClient.withPort(
      _config.host,
      clientId,
      _config.port,
    );

    client.logging(on: false);
    client.keepAlivePeriod = 30;
    client.autoReconnect = false;

    // TLS support
    final secCtx = _config.securityContext;
    if (secCtx != null) {
      client.securityContext = secCtx;
      client.secure = true;
    }

    // MQTT v5 connection message with persistent session
    final connMsg = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .keepAliveFor(30);
    if (_config.username != null) {
      connMsg.authenticateAs(_config.username!, _config.password ?? '');
    }

    if (_config.cleanStart) {
      connMsg.startClean();
    } else {
      connMsg.startSession(sessionExpiryInterval: _config.sessionExpiryInterval);
    }

    client.connectionMessage = connMsg;
    client.onDisconnected = _onDisconnected;

    try {
      await client.connect();
    } catch (e, stack) {
      stderr.writeln('[MqttTransport] connect failed: $e\n$stack');
      _messageController.addError(e, stack);
      metrics.recordConnectFailure();
      _scheduleReconnect();
      return;
    }

    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      stderr.writeln(
          '[MqttTransport] connect failed: ${client.connectionStatus}');
      metrics.recordConnectFailure();
      _scheduleReconnect();
      return;
    }

    _client = client;

    if (_reconnectAttempts > 0) {
      metrics.recordReconnectSuccess();
    } else {
      metrics.recordConnectSuccess();
    }
    _reconnectAttempts = 0;

    for (final topic in _config.subscribeTopics) {
      client.subscribe(topic, MqttQos.atLeastOnce);
    }

    client.updates.listen(
      (List<MqttReceivedMessage<MqttMessage>> messages) {
        for (final msg in messages) {
          final publishMsg = msg.payload as MqttPublishMessage;
          final raw = publishMsg.payload.message;
          if (raw == null || raw.isEmpty) continue;
          _messageController.add(TransportMessage(
            topic: msg.topic ?? '',
            payload: Uint8List.fromList(raw),
          ));
          metrics.recordMessageReceived();
        }
      },
      onError: (Object error, StackTrace stack) {
        stderr.writeln('[MqttTransport] updates stream error: $error\n$stack');
        _messageController.addError(error, stack);
      },
      onDone: () {
        stderr.writeln('[MqttTransport] updates stream closed');
      },
    );

    // PUBACK delay monitoring: track time between publish and broker ACK
    client.published?.listen((MqttPublishMessage msg) {
      final msgId = msg.variableHeader?.messageIdentifier;
      if (msgId == null) return;
      final sendTime = _pendingPubTimestamps.remove(msgId);
      if (sendTime != null) {
        final delay = DateTime.now().difference(sendTime);
        _pubAckController.add(delay);
        metrics.recordPubAckDelay(delay);
      }
    });
  }

  // ── Exponential backoff reconnect ──

  void _onDisconnected() {
    _disconnectController.add(null);
    metrics.recordDisconnect(intentional: _intentionalDisconnect);
    if (_intentionalDisconnect) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    if (_config.maxReconnectAttempts >= 0 &&
        _reconnectAttempts >= _config.maxReconnectAttempts) {
      stderr.writeln(
          '[MqttTransport] max reconnect attempts (${_config.maxReconnectAttempts}) reached');
      return;
    }

    metrics.recordReconnectAttempt();
    final delay = _calculateBackoff(_reconnectAttempts);
    _reconnectAttempts++;
    stderr.writeln(
        '[MqttTransport] scheduling reconnect attempt $_reconnectAttempts in ${delay.inMilliseconds}ms');
    _reconnectTimer = Timer(delay, _doConnect);
  }

  Duration _calculateBackoff(int attempt) {
    final baseMs = _config.reconnectBackoffBase.inMilliseconds;
    final maxMs = _config.reconnectBackoffMax.inMilliseconds;
    final backoff = min(baseMs * pow(2, attempt).toInt(), maxMs);
    if (backoff >= maxMs && attempt > 0) {
      metrics.recordMaxBackoffReached();
    }
    final jitter = _random.nextInt(max(backoff ~/ 4, 100));
    return Duration(milliseconds: backoff + jitter);
  }

  // ── Send ──

  @override
  void send(String topic, Uint8List payload) {
    if (_client == null) {
      stderr.writeln('[MqttTransport] send failed: not connected');
      return;
    }
    final builder = MqttPayloadBuilder();
    builder.payload?.addAll(payload);
    final builtPayload = builder.payload;
    if (builtPayload != null) {
      final msgId = _client!.publishMessage(
        topic, MqttQos.atLeastOnce, builtPayload);
      _pendingPubTimestamps[msgId] = DateTime.now();
      metrics.recordMessageSent();
    }
  }

  @override
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      _client?.disconnect();
    } catch (e, stack) {
      stderr.writeln('[MqttTransport] disconnect error: $e\n$stack');
    }
    _client = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _pubAckController.close();
    await _disconnectController.close();
  }
}

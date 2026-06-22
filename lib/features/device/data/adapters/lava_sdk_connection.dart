import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:lava_device_sdk/lava_device_sdk.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_message.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_connection.dart';

/// Adapts the lava-device-controll SDK to the [IConnection] interface.
///
/// Wraps a [DeviceClient] and translates between SDK types and domain types:
/// - SDK [TransportMessage] → domain [DeviceMessage]
/// - SDK transport state → domain [ConnectionStatus]
class LavaSdkConnection implements IConnection {
  final DeviceClient _client;
  final StreamController<ConnectionStatus> _statusController;
  final StreamController<DeviceMessage> _messageController;
  StreamSubscription? _transportSub;
  StreamSubscription? _connectionStateSub;
  ConnectionStatus _status = ConnectionStatus.idle;

  /// The credentials used to establish this connection.
  /// Contains raw TLS certificate strings for caching via [CertificateStorage].
  final MqttCredentials? credentials;

  LavaSdkConnection._(this._client, {this.credentials})
      : _statusController = StreamController<ConnectionStatus>.broadcast(),
        _messageController = StreamController<DeviceMessage>.broadcast() {
    _listenToTransport();
    _listenToConnectionState();
  }

  // ── Factory methods ──

  /// Create a LAN connection via [DeviceHub.connectLan].
  ///
  /// Returns the connection with [credentials] populated (ca/cert/key PEM strings)
  /// for persisting via [CertificateStorage].
  /// Returns null if the connection or authorization failed.
  static Future<LavaSdkConnection?> createLan({
    required String ip,
    int authPort = 1884,
    String accessCode = '12345678',
    DeviceSchema? schema,
  }) async {
    final result = await DeviceHub.connectLan(
      ip: ip,
      authPort: authPort,
      accessCode: accessCode,
      schema: schema,
    );
    if (result == null) return null;
    return LavaSdkConnection._(result.client, credentials: result.credentials);
  }

  /// Create a connection using previously cached [MqttCredentials].
  ///
  /// Skips the LAN auth flow entirely — connects directly via TLS.
  /// Returns null if the connection failed (e.g., expired cert).
  static Future<LavaSdkConnection?> createWithCredentials(
    MqttCredentials creds, {
    DeviceSchema? schema,
  }) async {
    final result = await DeviceHub.connectWithCredentials(
      creds,
      schema: schema,
    );
    if (result == null) return null;
    return LavaSdkConnection._(result.client,
        credentials: result.credentials);
  }

  /// Create a WAN connection via [DeviceHub.connectWan].
  static Future<LavaSdkConnection?> createWan({
    required CloudApiClient api,
    required String token,
    String? deviceIp,
    String? sn,
    String? pinCode,
    DeviceSchema? schema,
  }) async {
    final result = await DeviceHub.connectWan(
      api: api,
      token: token,
      deviceIp: deviceIp,
      sn: sn,
      pinCode: pinCode,
      schema: schema,
    );
    if (result == null) return null;
    return LavaSdkConnection._(result.client, credentials: result.credentials);
  }

  // ── IConnection implementation ──

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  ConnectionStatus get status => _status;

  @override
  Stream<DeviceMessage> get messageStream => _messageController.stream;

  @override
  Future<void> connect() async {
    // DeviceHub already connected the client (via ..connect() in _connect).
    // Avoid double-connecting which would re-subscribe message streams.
    if (_client.isConnected) {
      _setStatus(ConnectionStatus.connected);
      return;
    }
    _setStatus(ConnectionStatus.connecting);
    try {
      await _client.connect();
      _setStatus(ConnectionStatus.connected);
    } catch (e) {
      _setStatus(ConnectionStatus.error);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _client.disconnect();
      _setStatus(ConnectionStatus.disconnected);
    } catch (e) {
      _setStatus(ConnectionStatus.error);
      rethrow;
    }
  }

  @override
  Future<void> send(DeviceMessage message) async {
    _client.transport.send(
      message.topic,
      Uint8List.fromList(utf8.encode(jsonEncode(message.payload))),
    );
  }

  @override
  ConnectionInfo get info => ConnectionInfo(
        type: 'mqtt',
        endpoint: 'device',
        isSecure: credentials?.securityContext != null ||
            credentials?.hasTlsCredentials == true,
      );

  // ── Internal ──

  void _listenToTransport() {
    _transportSub = _client.transport.messageStream.listen((msg) {
      try {
        final payload =
            jsonDecode(utf8.decode(msg.payload)) as Map<String, dynamic>;
        _messageController.add(DeviceMessage(
          topic: msg.topic,
          payload: payload,
          timestamp: DateTime.now(),
        ));
      } catch (_) {
        // Ignore malformed messages
      }
    });
  }

  /// Bridge SDK [DeviceClient.connectionState] to [IConnection.statusStream].
  void _listenToConnectionState() {
    if (_client.isConnected) {
      _setStatus(ConnectionStatus.connected);
    }
    _connectionStateSub = _client.connectionState.listen((state) {
      _setStatus(_mapSdkConnectionState(state));
    });
  }

  ConnectionStatus _mapSdkConnectionState(ConnectionState state) {
    return switch (state) {
      ConnectionState.disconnected => ConnectionStatus.disconnected,
      ConnectionState.connecting   => ConnectionStatus.connecting,
      ConnectionState.connected    => ConnectionStatus.connected,
      ConnectionState.reconnecting => ConnectionStatus.connecting,
    };
  }

  void _setStatus(ConnectionStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    _statusController.add(newStatus);
  }

  /// Release resources held by the adapter.
  Future<void> dispose() async {
    await _connectionStateSub?.cancel();
    await _transportSub?.cancel();
    await _statusController.close();
    await _messageController.close();
    await _client.dispose();
  }
}

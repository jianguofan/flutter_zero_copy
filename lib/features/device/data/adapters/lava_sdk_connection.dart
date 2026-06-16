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
  ConnectionStatus _status = ConnectionStatus.idle;

  LavaSdkConnection._(this._client)
      : _statusController = StreamController<ConnectionStatus>.broadcast(),
        _messageController = StreamController<DeviceMessage>.broadcast() {
    _listenToTransport();
  }

  // ── Factory methods ──

  /// Create a LAN connection via [DeviceHub.connectLan].
  static Future<LavaSdkConnection?> createLan({
    required String ip,
    int authPort = 1884,
    String accessCode = '12345678',
    DeviceSchema? schema,
  }) async {
    final client = await DeviceHub.connectLan(
      ip: ip,
      authPort: authPort,
      accessCode: accessCode,
      schema: schema,
    );
    if (client == null) return null;
    return LavaSdkConnection._(client);
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
    final client = await DeviceHub.connectWan(
      api: api,
      token: token,
      deviceIp: deviceIp,
      sn: sn,
      pinCode: pinCode,
      schema: schema,
    );
    if (client == null) return null;
    return LavaSdkConnection._(client);
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
        isSecure: false,
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

  void _setStatus(ConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  /// Release resources held by the adapter.
  Future<void> dispose() async {
    await _transportSub?.cancel();
    await _statusController.close();
    await _messageController.close();
    await _client.dispose();
  }
}

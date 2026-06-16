import 'dart:async';
import 'package:flutter_zero_copy/features/device/domain/entities/device_message.dart';

/// Transport-level connection status.
enum ConnectionStatus {
  idle,
  connecting,
  connected,
  disconnected,
  error,
}

/// Metadata about an active connection.
class ConnectionInfo {
  final String type; // 'mqtt', 'websocket'
  final String endpoint;
  final bool isSecure;

  const ConnectionInfo({
    required this.type,
    required this.endpoint,
    required this.isSecure,
  });
}

/// Transport-layer abstraction — decouples protocol from business logic.
///
/// Implementations:
/// - [LavaSdkConnection] — wraps lava-device-controll SDK
/// - MockConnection — for testing
abstract class IConnection {
  /// Connection state stream.
  Stream<ConnectionStatus> get statusStream;

  /// Current connection state.
  ConnectionStatus get status;

  /// Inbound message stream.
  Stream<DeviceMessage> get messageStream;

  /// Establish the transport connection.
  Future<void> connect();

  /// Tear down the transport connection.
  Future<void> disconnect();

  /// Send a message over the transport.
  Future<void> send(DeviceMessage message);

  /// Connection metadata for logging / debugging.
  ConnectionInfo get info;
}

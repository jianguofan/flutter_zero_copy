import 'dart:typed_data';

/// Abstract transport layer. Implement for MQTT, WebSocket, etc.
abstract class DeviceTransport {
  /// Connect to the device/endpoint.
  Future<void> connect();

  /// Disconnect.
  Future<void> disconnect();

  /// Send raw bytes to a topic/sub-channel.
  void send(String topic, Uint8List payload);

  /// Stream of received messages.
  Stream<TransportMessage> get messageStream;

  /// Whether currently connected.
  bool get isConnected;

  /// Clean up all resources.
  Future<void> dispose();
}

class TransportMessage {
  final String topic;
  final Uint8List payload;

  const TransportMessage({required this.topic, required this.payload});
}

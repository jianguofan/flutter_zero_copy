/// Represents the current connection state of a [DeviceClient].
enum ConnectionState {
  /// Not connected and not attempting to connect.
  disconnected,

  /// Actively attempting to establish a connection.
  connecting,

  /// Fully connected and operational.
  connected,

  /// Connection was lost, attempting to reconnect automatically.
  reconnecting,
}

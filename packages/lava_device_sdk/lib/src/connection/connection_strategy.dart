import 'dart:async';
import 'package:lava_device_sdk/src/models/mqtt_credentials.dart';

/// Progress update emitted during pre-connection.
class ConnectionProgress {
  final String step;
  final bool isDone;
  final String? error;

  const ConnectionProgress(this.step, {this.isDone = false, this.error});

  static ConnectionProgress done(String step) =>
      ConnectionProgress(step, isDone: true);

  static ConnectionProgress failed(String step, String error) =>
      ConnectionProgress(step, error: error);
}

/// Pre-connection strategy — handles the platform-specific dance required
/// to obtain MQTT credentials before the unified [DeviceClient] takes over.
///
/// Implementations:
/// - [LanStrategy] — LAN auth handshake → device-issued TLS cert
/// - [WanStrategy] — Cloud login → PIN → bind → AWS IoT cert
abstract class ConnectionStrategy {
  /// Execute the pre-connection flow. Returns MQTT credentials on success,
  /// or null on failure (check [progressStream] for the error).
  Future<MqttCredentials?> execute();

  /// Stream of progress updates during execution. UI can listen to show
  /// step-by-step status.
  Stream<ConnectionProgress> get progressStream;

  /// Cancel an in-progress connection attempt.
  void cancel();
}

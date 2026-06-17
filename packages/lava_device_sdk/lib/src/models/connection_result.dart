import 'package:lava_device_sdk/src/client/device_client.dart';
import 'package:lava_device_sdk/src/models/mqtt_credentials.dart';

/// Result of a successful device connection via [DeviceHub].
///
/// Contains both the [DeviceClient] for interacting with the device and the
/// [MqttCredentials] for persisting/caching for future reconnections.
/// The raw certificate fields on [credentials] ([MqttCredentials.ca],
/// [MqttCredentials.cert], [MqttCredentials.key]) can be serialized and
/// later passed to [DeviceHub.connectWithCredentials] for fast reconnection
/// without re-authorization.
class ConnectionResult {
  /// The connected device client, ready for commands and state access.
  final DeviceClient client;

  /// The credentials used to establish the connection.
  /// Contains raw TLS certificate strings suitable for caching.
  final MqttCredentials credentials;

  const ConnectionResult({
    required this.client,
    required this.credentials,
  });
}

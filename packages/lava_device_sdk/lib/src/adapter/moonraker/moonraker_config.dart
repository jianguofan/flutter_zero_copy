class MoonrakerConfig {
  /// Map of Moonraker object name → attribute names to subscribe to.
  /// null value means subscribe to all attributes.
  final Map<String, List<String>?> subscribe;

  /// MQTT topic for receiving JSON-RPC responses.
  final String responseTopic;

  /// MQTT topic for receiving status updates (notify_status_update).
  final String statusTopic;

  /// MQTT topic for receiving device notifications (Last Will, state changes).
  /// null means no notification handling.
  final String? notificationTopic;

  const MoonrakerConfig({
    required this.subscribe,
    this.responseTopic = '/response',
    this.statusTopic = '/status',
    this.notificationTopic,
  });

  factory MoonrakerConfig.fromDataSource(Map<String, dynamic> dataSource) {
    final subscribeRaw = dataSource['subscribe'] as Map<String, dynamic>? ?? {};

    final subscribe = <String, List<String>?>{};
    for (final entry in subscribeRaw.entries) {
      if (entry.value == null) {
        subscribe[entry.key] = null;
      } else {
        subscribe[entry.key] = List<String>.from(entry.value as List);
      }
    }

    return MoonrakerConfig(
      subscribe: subscribe,
      responseTopic: dataSource['responseTopic'] as String? ?? '/response',
      statusTopic: dataSource['statusTopic'] as String? ?? '/status',
      notificationTopic: dataSource['notificationTopic'] as String?,
    );
  }
}

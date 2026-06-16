import 'dart:io';

/// Unified MQTT connection credentials — the output of any pre-connection
/// strategy (LAN auth, WAN cloud, etc.) and the input to [DeviceClient].
class MqttCredentials {
  final String host;
  final int port;
  final String clientId;
  final String sn;
  final SecurityContext? securityContext;
  final List<String> subscribeTopics;
  final String publishTopic;

  const MqttCredentials({
    required this.host,
    required this.port,
    required this.clientId,
    required this.sn,
    this.securityContext,
    this.subscribeTopics = const [],
    this.publishTopic = '',
  });

  /// Convenience: build the default Moonraker topic set from [sn].
  static List<String> defaultSubscribeTopics(String sn) => [
        '$sn/response',
        '$sn/status',
        '$sn/notification',
      ];

  static String defaultPublishTopic(String sn) => '$sn/request';
}

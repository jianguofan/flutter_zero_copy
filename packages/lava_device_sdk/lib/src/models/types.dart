import 'dart:io';

class MqttConfig {
  final String host;
  final int port;
  final String? clientId;
  final String? username;
  final String? password;
  final List<String> subscribeTopics;
  final SecurityContext? securityContext;

  // MQTT v5 session persistence
  final bool cleanStart;
  final int sessionExpiryInterval;

  // Exponential backoff reconnect
  final int maxReconnectAttempts;
  final Duration reconnectBackoffBase;
  final Duration reconnectBackoffMax;

  /// If true, accept self-signed / untrusted server certificates during TLS
  /// handshake. Required for LAN connections where the device broker uses a
  /// self-signed certificate that cannot be verified through standard PKI.
  final bool allowBadCertificate;

  const MqttConfig({
    required this.host,
    this.port = 1883,
    this.clientId,
    this.username,
    this.password,
    this.subscribeTopics = const ['/status', '/response'],
    this.securityContext,
    this.cleanStart = false,
    this.sessionExpiryInterval = 3600,
    this.maxReconnectAttempts = -1,
    this.reconnectBackoffBase = const Duration(seconds: 1),
    this.reconnectBackoffMax = const Duration(seconds: 60),
    this.allowBadCertificate = false,
  });
}

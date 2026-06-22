import 'dart:convert';
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

  /// Raw CA certificate PEM string (for persistence/caching).
  final String? ca;

  /// Raw client certificate PEM string (for persistence/caching).
  final String? cert;

  /// Raw client private key PEM string (for persistence/caching).
  final String? key;

  const MqttCredentials({
    required this.host,
    required this.port,
    required this.clientId,
    required this.sn,
    this.securityContext,
    this.subscribeTopics = const [],
    this.publishTopic = '',
    this.ca,
    this.cert,
    this.key,
  });

  /// Whether raw TLS certificate strings are available for persistence.
  bool get hasTlsCredentials => ca != null && cert != null && key != null;

  /// Returns [securityContext] if already set, otherwise constructs one from
  /// [ca]/[cert]/[key] PEM strings. Returns null if neither is available.
  SecurityContext? getOrCreateSecurityContext() {
    if (securityContext != null) return securityContext;
    if (!hasTlsCredentials) return null;
    final ctx = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(cert!))
      ..usePrivateKeyBytes(utf8.encode(key!));
    if (ca != null) {
      ctx.setTrustedCertificatesBytes(utf8.encode(ca!));
    }
    return ctx;
  }

  /// Convenience: build the default Moonraker topic set from [sn].
  static List<String> defaultSubscribeTopics(String sn) => [
        '$sn/response',
        '$sn/status',
        '$sn/notification',
      ];

  static String defaultPublishTopic(String sn) => '$sn/request';

  /// Serialize to JSON for persistence (certificates included as PEM strings).
  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'clientId': clientId,
        'sn': sn,
        'subscribeTopics': subscribeTopics,
        'publishTopic': publishTopic,
        if (ca != null) 'ca': ca,
        if (cert != null) 'cert': cert,
        if (key != null) 'key': key,
      };

  /// Deserialize from JSON (certificates reconstructed from PEM strings).
  factory MqttCredentials.fromJson(Map<String, dynamic> json) {
    final ca = json['ca'] as String?;
    final cert = json['cert'] as String?;
    final key = json['key'] as String?;

    return MqttCredentials(
      host: json['host'] as String,
      port: json['port'] as int,
      clientId: json['clientId'] as String,
      sn: json['sn'] as String,
      subscribeTopics: (json['subscribeTopics'] as List?)?.cast<String>() ?? [],
      publishTopic: json['publishTopic'] as String? ?? '',
      ca: ca,
      cert: cert,
      key: key,
      // SecurityContext is reconstructed at connection time via getOrCreateSecurityContext()
    );
  }
}

/// 连接事件类型（13 种）
enum MetricsEventType {
  connectAttempt,
  connectSuccess,
  connectFailure,
  disconnect,
  reconnectAttempt,
  reconnectSuccess,
  reconnectFailure,
  maxBackoffReached,
  qualityChange,
  timeoutExtension,
  heartbeatFailure,
  commandTimeout,
  /// Latency sample: data = {link: "A"|"B"|"full", delayMs: 45.2}
  latencySample,
}

/// 单条连接事件
class MetricsEvent {
  final DateTime timestamp;
  final MetricsEventType type;
  final Map<String, dynamic>? data;

  const MetricsEvent({
    required this.timestamp,
    required this.type,
    this.data,
  });

  Map<String, dynamic> toJson() => {
        'ts': timestamp.toIso8601String(),
        'type': type.name,
        if (data != null && data!.isNotEmpty) 'data': data,
      };

  @override
  String toString() =>
      '${timestamp.toIso8601String().substring(11, 23)} $type${data != null ? ' $data' : ''}';
}

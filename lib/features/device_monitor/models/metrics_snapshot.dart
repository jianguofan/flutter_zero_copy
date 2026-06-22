import 'dart:convert';
import 'metrics_event.dart';
import 'link_quality.dart';

/// 连接指标聚合快照
class MetricsSnapshot {
  final DateTime timestamp;
  final Duration sessionDuration;

  final int connectAttempts, connectSuccesses, connectFailures;
  final int reconnectAttempts, reconnectSuccesses, reconnectFailures;
  final int unsolicitedDisconnects, intentionalDisconnects, maxBackoffReached;
  final int messagesSent, messagesReceived;
  final int commandsSent, commandsSucceeded, commandsTimedOut, commandsFailed;
  final int timeoutExtensions;
  final int heartbeatsSent, heartbeatsSucceeded, heartbeatsFailed;

  final String currentQuality;
  final int qualityDegradations, qualityRecoveries, qualityPoorCount;

  final double availability, connectSuccessRate, reconnectSuccessRate;
  final double commandSuccessRate, heartbeatSuccessRate;
  final double pubAckP50Ms, pubAckP95Ms, pubAckP99Ms;
  final double heartbeatRttP50Ms, heartbeatRttP95Ms, heartbeatRttP99Ms;

  final List<MetricsEvent> eventTimeline;

  const MetricsSnapshot({
    required this.timestamp,
    required this.sessionDuration,
    this.connectAttempts = 0,
    this.connectSuccesses = 0,
    this.connectFailures = 0,
    this.reconnectAttempts = 0,
    this.reconnectSuccesses = 0,
    this.reconnectFailures = 0,
    this.unsolicitedDisconnects = 0,
    this.intentionalDisconnects = 0,
    this.maxBackoffReached = 0,
    this.messagesSent = 0,
    this.messagesReceived = 0,
    this.commandsSent = 0,
    this.commandsSucceeded = 0,
    this.commandsTimedOut = 0,
    this.commandsFailed = 0,
    this.timeoutExtensions = 0,
    this.heartbeatsSent = 0,
    this.heartbeatsSucceeded = 0,
    this.heartbeatsFailed = 0,
    this.currentQuality = 'good',
    this.qualityDegradations = 0,
    this.qualityRecoveries = 0,
    this.qualityPoorCount = 0,
    this.availability = 1.0,
    this.connectSuccessRate = 1.0,
    this.reconnectSuccessRate = 1.0,
    this.commandSuccessRate = 1.0,
    this.heartbeatSuccessRate = 1.0,
    this.pubAckP50Ms = 0,
    this.pubAckP95Ms = 0,
    this.pubAckP99Ms = 0,
    this.heartbeatRttP50Ms = 0,
    this.heartbeatRttP95Ms = 0,
    this.heartbeatRttP99Ms = 0,
    this.eventTimeline = const [],
  });

  static MetricsSnapshot empty() =>
      MetricsSnapshot(timestamp: DateTime.now(), sessionDuration: Duration.zero);

  Map<String, dynamic> toJson() => {
        'exportedAt': timestamp.toIso8601String(),
        'sessionDuration': _fmtDuration(sessionDuration),
        'counters': {
          'connectAttempts': connectAttempts,
          'connectSuccesses': connectSuccesses,
          'connectFailures': connectFailures,
          'reconnectAttempts': reconnectAttempts,
          'reconnectSuccesses': reconnectSuccesses,
          'reconnectFailures': reconnectFailures,
          'unsolicitedDisconnects': unsolicitedDisconnects,
          'intentionalDisconnects': intentionalDisconnects,
        },
        'messages': {'sent': messagesSent, 'received': messagesReceived},
        'commands': {
          'sent': commandsSent,
          'succeeded': commandsSucceeded,
          'timedOut': commandsTimedOut,
          'failed': commandsFailed,
        },
        'heartbeat': {
          'sent': heartbeatsSent,
          'succeeded': heartbeatsSucceeded,
          'failed': heartbeatsFailed,
        },
        'quality': {
          'current': currentQuality,
          'degradations': qualityDegradations,
          'recoveries': qualityRecoveries,
          'poorCount': qualityPoorCount,
        },
        'rates': {
          'availability': availability,
          'connectSuccessRate': connectSuccessRate,
          'commandSuccessRate': commandSuccessRate,
          'heartbeatSuccessRate': heartbeatSuccessRate,
        },
        'latency': {
          'pubAckP50Ms': pubAckP50Ms,
          'pubAckP95Ms': pubAckP95Ms,
          'pubAckP99Ms': pubAckP99Ms,
          'heartbeatRttP50Ms': heartbeatRttP50Ms,
          'heartbeatRttP95Ms': heartbeatRttP95Ms,
          'heartbeatRttP99Ms': heartbeatRttP99Ms,
        },
        'eventTimeline': eventTimeline.map((e) => e.toJson()).toList(),
      };

  String toJsonString() =>
      const JsonEncoder.withIndent('  ').convert(toJson());

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h${m}m${s}s';
    if (m > 0) return '${m}m${s}s';
    return '${s}s';
  }

  @override
  String toString() => 'MetricsSnapshot(events=${eventTimeline.length}, '
      'quality=$currentQuality, avail=${(availability*100).toStringAsFixed(1)}%)';
}

// ══════════════════════════════════════════════
// ConnectionMetrics — 事件收集器
// ══════════════════════════════════════════════

/// 内存中的连接指标收集器。
///
/// 两层数据:
/// 1. 聚合计数器 — 快速概览
/// 2. 事件时间线 — 所有重要事件，2000 条环形缓冲
class ConnectionMetrics {
  int connectAttempts = 0, connectSuccesses = 0, connectFailures = 0;
  int reconnectAttempts = 0, reconnectSuccesses = 0, reconnectFailures = 0;
  int unsolicitedDisconnects = 0, intentionalDisconnects = 0;
  int maxBackoffReached = 0;
  int messagesSent = 0, messagesReceived = 0;
  int commandsSent = 0, commandsSucceeded = 0;
  int commandsTimedOut = 0, commandsFailed = 0;
  int timeoutExtensions = 0;
  int heartbeatsSent = 0, heartbeatsSucceeded = 0, heartbeatsFailed = 0;
  int qualityDegradations = 0, qualityRecoveries = 0, qualityPoorCount = 0;

  DateTime? sessionStartTime;
  DateTime? _connectStartTime;
  Duration totalConnectedDuration = Duration.zero;
  Duration totalDisconnectedDuration = Duration.zero;

  static const int _maxLatencySamples = 200;
  final List<Duration> _pubAckDelays = [];
  final List<Duration> _heartbeatRtts = [];

  static const int _maxTimelineEvents = 2000;
  final List<MetricsEvent> _eventTimeline = [];

  String _currentQuality = 'good';
  final Map<String, Duration> timeInQuality = {
    'good': Duration.zero,
    'degraded': Duration.zero,
    'poor': Duration.zero,
  };

  void Function(MetricsEvent event)? onEvent;

  void _addEvent(MetricsEventType type, {Map<String, dynamic>? data}) {
    final event = MetricsEvent(
        timestamp: DateTime.now(), type: type, data: data);
    _eventTimeline.add(event);
    if (_eventTimeline.length > _maxTimelineEvents) {
      _eventTimeline.removeAt(0);
    }
    onEvent?.call(event);
  }

  void recordConnectSuccess() {
    connectSuccesses++;
    sessionStartTime ??= DateTime.now();
    _connectStartTime = DateTime.now();
    _addEvent(MetricsEventType.connectSuccess);
  }

  void recordConnectAttempt() {
    connectAttempts++;
    _addEvent(MetricsEventType.connectAttempt);
  }

  void recordConnectFailure() {
    connectFailures++;
    _addEvent(MetricsEventType.connectFailure);
  }

  void recordDisconnect({bool intentional = false}) {
    if (intentional) {
      intentionalDisconnects++;
    } else {
      unsolicitedDisconnects++;
    }
    if (_connectStartTime != null) {
      totalConnectedDuration += DateTime.now().difference(_connectStartTime!);
      _connectStartTime = null;
    }
    _addEvent(MetricsEventType.disconnect,
        data: {'intentional': intentional});
  }

  void recordCommandSent() => commandsSent++;
  void recordCommandResult(bool success, {bool timedOut = false}) {
    if (success) {
      commandsSucceeded++;
    } else if (timedOut) {
      commandsTimedOut++;
      _addEvent(MetricsEventType.commandTimeout);
    } else {
      commandsFailed++;
    }
  }

  /// Decimation factor for message send/receive events.
  /// Records every Nth message as an event to avoid flooding the timeline.
  static const int _messageEventDecimation = 5;

  void recordMessageSent({String? topic, int? size}) {
    messagesSent++;
    if (messagesSent % _messageEventDecimation == 0) {
      _addEvent(MetricsEventType.messageSent,
          data: {'topic': topic ?? '—', 'size': size, 'count': messagesSent});
    }
  }

  void recordMessageReceived({String? topic, int? size}) {
    messagesReceived++;
    if (messagesReceived % _messageEventDecimation == 0) {
      _addEvent(MetricsEventType.messageReceived,
          data: {'topic': topic ?? '—', 'size': size, 'count': messagesReceived});
    }
  }

  void recordHeartbeat(bool success, {Duration? rtt}) {
    heartbeatsSent++;
    if (success) {
      heartbeatsSucceeded++;
      if (rtt != null) {
        _heartbeatRtts.add(rtt);
        if (_heartbeatRtts.length > _maxLatencySamples) {
          _heartbeatRtts.removeAt(0);
        }
      }
    } else {
      heartbeatsFailed++;
      _addEvent(MetricsEventType.heartbeatFailure);
    }
  }

  void recordPubAckDelay(Duration delay) {
    _pubAckDelays.add(delay);
    if (_pubAckDelays.length > _maxLatencySamples) _pubAckDelays.removeAt(0);
    // Decimated: record every 10th sample
    if (messagesSent % 10 == 0) {
      _addEvent(MetricsEventType.latencySample,
          data: {'link': 'A', 'delayMs': _delayMs(delay)});
    }
  }

  void recordQualityChange(LinkQuality from, LinkQuality to) {
    if (to == LinkQuality.degraded || to == LinkQuality.poor) {
      qualityDegradations++;
    } else if (to == LinkQuality.good) {
      qualityRecoveries++;
    }
    if (to == LinkQuality.poor) qualityPoorCount++;
    _addEvent(MetricsEventType.qualityChange,
        data: {'from': from.name, 'to': to.name});
    _currentQuality = to.name;

  }

  static double _delayMs(Duration d) =>
      (d.inMicroseconds / 1000.0).roundToDouble() / 1.0;

  double get availability {
    final total = totalConnectedDuration + totalDisconnectedDuration;
    return total == Duration.zero
        ? 1.0
        : totalConnectedDuration.inMicroseconds / total.inMicroseconds;
  }

  double get connectSuccessRate =>
      connectAttempts == 0 ? 1.0 : connectSuccesses / connectAttempts;
  double get commandSuccessRate =>
      commandsSent == 0 ? 1.0 : commandsSucceeded / commandsSent;
  double get heartbeatSuccessRate =>
      heartbeatsSent == 0 ? 1.0 : heartbeatsSucceeded / heartbeatsSent;

  double get pubAckP50Ms => _percentileMs(_pubAckDelays, 50);
  double get pubAckP95Ms => _percentileMs(_pubAckDelays, 95);
  double get pubAckP99Ms => _percentileMs(_pubAckDelays, 99);
  double get heartbeatRttP50Ms => _percentileMs(_heartbeatRtts, 50);
  double get heartbeatRttP95Ms => _percentileMs(_heartbeatRtts, 95);
  double get heartbeatRttP99Ms => _percentileMs(_heartbeatRtts, 99);

  static double _percentileMs(List<Duration> samples, int percentile) {
    if (samples.isEmpty) return -1;
    final sorted = List<Duration>.from(samples)..sort();
    final index = ((percentile / 100) * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)].inMicroseconds / 1000.0;
  }

  int get eventCount => _eventTimeline.length;

  /// Export all events as a list (for full export).
  List<MetricsEvent> get events => List<MetricsEvent>.from(_eventTimeline);

  MetricsSnapshot snapshot() {
    final sessionDuration = sessionStartTime != null
        ? DateTime.now().difference(sessionStartTime!)
        : Duration.zero;
    return MetricsSnapshot(
      timestamp: DateTime.now(),
      sessionDuration: sessionDuration,
      connectAttempts: connectAttempts,
      connectSuccesses: connectSuccesses,
      connectFailures: connectFailures,
      reconnectAttempts: reconnectAttempts,
      reconnectSuccesses: reconnectSuccesses,
      reconnectFailures: reconnectFailures,
      unsolicitedDisconnects: unsolicitedDisconnects,
      intentionalDisconnects: intentionalDisconnects,
      maxBackoffReached: maxBackoffReached,
      messagesSent: messagesSent,
      messagesReceived: messagesReceived,
      commandsSent: commandsSent,
      commandsSucceeded: commandsSucceeded,
      commandsTimedOut: commandsTimedOut,
      commandsFailed: commandsFailed,
      timeoutExtensions: timeoutExtensions,
      heartbeatsSent: heartbeatsSent,
      heartbeatsSucceeded: heartbeatsSucceeded,
      heartbeatsFailed: heartbeatsFailed,
      currentQuality: _currentQuality,
      qualityDegradations: qualityDegradations,
      qualityRecoveries: qualityRecoveries,
      qualityPoorCount: qualityPoorCount,
      availability: availability,
      connectSuccessRate: connectSuccessRate,
      commandSuccessRate: commandSuccessRate,
      heartbeatSuccessRate: heartbeatSuccessRate,
      pubAckP50Ms: pubAckP50Ms,
      pubAckP95Ms: pubAckP95Ms,
      pubAckP99Ms: pubAckP99Ms,
      heartbeatRttP50Ms: heartbeatRttP50Ms,
      heartbeatRttP95Ms: heartbeatRttP95Ms,
      heartbeatRttP99Ms: heartbeatRttP99Ms,
      eventTimeline: List<MetricsEvent>.from(_eventTimeline),
    );
  }

  void reset() {
    connectAttempts = 0; connectSuccesses = 0; connectFailures = 0;
    reconnectAttempts = 0; reconnectSuccesses = 0; reconnectFailures = 0;
    unsolicitedDisconnects = 0; intentionalDisconnects = 0;
    maxBackoffReached = 0;
    messagesSent = 0; messagesReceived = 0;
    commandsSent = 0; commandsSucceeded = 0; commandsTimedOut = 0;
    commandsFailed = 0; timeoutExtensions = 0;
    heartbeatsSent = 0; heartbeatsSucceeded = 0; heartbeatsFailed = 0;
    qualityDegradations = 0; qualityRecoveries = 0; qualityPoorCount = 0;
    sessionStartTime = null; _connectStartTime = null;
    totalConnectedDuration = Duration.zero;
    totalDisconnectedDuration = Duration.zero;
    _pubAckDelays.clear(); _heartbeatRtts.clear(); _eventTimeline.clear();
    _currentQuality = 'good';
    timeInQuality['good'] = Duration.zero;
    timeInQuality['degraded'] = Duration.zero;
    timeInQuality['poor'] = Duration.zero;
  }
}

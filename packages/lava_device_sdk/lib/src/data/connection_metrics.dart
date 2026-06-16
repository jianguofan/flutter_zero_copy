import 'dart:convert';
import 'package:lava_device_sdk/src/connection/link_quality_monitor.dart';

// ── Event types ──

/// Tagged union of all significant connection events.
/// Kept in memory as a ring buffer for timeline reconstruction.
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
  /// Latency sample for a specific network segment.
  /// data: {link: "A"|"B"|"full", delayMs: 45.2}
  latencySample,
}

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
      '${timestamp.toIso8601String()} $type${data != null ? ' $data' : ''}';
}

// ── Immutable snapshot ──

class MetricsSnapshot {
  final DateTime timestamp;
  final Duration sessionDuration;

  // Counters
  final int connectAttempts;
  final int connectSuccesses;
  final int connectFailures;
  final int reconnectAttempts;
  final int reconnectSuccesses;
  final int reconnectFailures;
  final int unsolicitedDisconnects;
  final int intentionalDisconnects;
  final int maxBackoffReached;

  // Messages
  final int messagesSent;
  final int messagesReceived;

  // Commands
  final int commandsSent;
  final int commandsSucceeded;
  final int commandsTimedOut;
  final int commandsFailed;
  final int timeoutExtensions;

  // Heartbeat
  final int heartbeatsSent;
  final int heartbeatsSucceeded;
  final int heartbeatsFailed;

  // Quality
  final String currentQuality;
  final int qualityDegradations;
  final int qualityRecoveries;
  final int qualityPoorCount;
  final Map<String, Duration> timeInQuality;

  // Rates
  final double availability;
  final double connectSuccessRate;
  final double reconnectSuccessRate;
  final double commandSuccessRate;
  final double heartbeatSuccessRate;

  // Latency
  final double pubAckP50Ms;
  final double pubAckP95Ms;
  final double pubAckP99Ms;
  final double heartbeatRttP50Ms;
  final double heartbeatRttP95Ms;
  final double heartbeatRttP99Ms;

  // ── Event timeline ──

  /// Full event log since session start (ring buffer snapshot).
  /// Events are ordered by timestamp.
  final List<MetricsEvent> eventTimeline;

  const MetricsSnapshot({
    required this.timestamp,
    required this.sessionDuration,
    required this.connectAttempts,
    required this.connectSuccesses,
    required this.connectFailures,
    required this.reconnectAttempts,
    required this.reconnectSuccesses,
    required this.reconnectFailures,
    required this.unsolicitedDisconnects,
    required this.intentionalDisconnects,
    required this.maxBackoffReached,
    required this.messagesSent,
    required this.messagesReceived,
    required this.commandsSent,
    required this.commandsSucceeded,
    required this.commandsTimedOut,
    required this.commandsFailed,
    required this.timeoutExtensions,
    required this.heartbeatsSent,
    required this.heartbeatsSucceeded,
    required this.heartbeatsFailed,
    required this.currentQuality,
    required this.qualityDegradations,
    required this.qualityRecoveries,
    required this.qualityPoorCount,
    required this.timeInQuality,
    required this.availability,
    required this.connectSuccessRate,
    required this.reconnectSuccessRate,
    required this.commandSuccessRate,
    required this.heartbeatSuccessRate,
    required this.pubAckP50Ms,
    required this.pubAckP95Ms,
    required this.pubAckP99Ms,
    required this.heartbeatRttP50Ms,
    required this.heartbeatRttP95Ms,
    required this.heartbeatRttP99Ms,
    required this.eventTimeline,
  });

  /// Full export as JSON-compatible map.
  /// Includes counters, rates, latency percentiles, and the complete
  /// event timeline for offline analysis.
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
          'maxBackoffReached': maxBackoffReached,
        },
        'messages': {
          'sent': messagesSent,
          'received': messagesReceived,
        },
        'commands': {
          'sent': commandsSent,
          'succeeded': commandsSucceeded,
          'timedOut': commandsTimedOut,
          'failed': commandsFailed,
          'timeoutExtensions': timeoutExtensions,
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
          'timeInGood': _fmtDuration(
              timeInQuality['good'] ?? Duration.zero),
          'timeInDegraded': _fmtDuration(
              timeInQuality['degraded'] ?? Duration.zero),
          'timeInPoor': _fmtDuration(
              timeInQuality['poor'] ?? Duration.zero),
        },
        'rates': {
          'availability': availability,
          'connectSuccessRate': connectSuccessRate,
          'reconnectSuccessRate': reconnectSuccessRate,
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
        'eventTimeline':
            eventTimeline.map((e) => e.toJson()).toList(),
      };

  /// Compact JSON string for logging or file export.
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
  String toString() {
    final rates = 'avail=${(availability * 100).toStringAsFixed(2)}% '
        'conn=${(connectSuccessRate * 100).toStringAsFixed(1)}% '
        'cmd=${(commandSuccessRate * 100).toStringAsFixed(1)}% '
        'hb=${(heartbeatSuccessRate * 100).toStringAsFixed(1)}%';
    final latency =
        'pubAck[p50=${pubAckP50Ms.toStringAsFixed(0)}ms p95=${pubAckP95Ms.toStringAsFixed(0)}ms] '
        'rtt[p50=${heartbeatRttP50Ms.toStringAsFixed(0)}ms p95=${heartbeatRttP95Ms.toStringAsFixed(0)}ms]';
    final events =
        'events=${eventTimeline.length} quality=$currentQuality';
    return 'MetricsSnapshot($rates, $latency, $events)';
  }
}

// ── Metrics collector ──

/// Collects connection stability metrics entirely in memory.
///
/// Two layers of data:
/// 1. **Aggregated counters** — quick overview (availability, success rates)
/// 2. **Event timeline** — timestamped log of all significant events for
///    offline reconstruction and debugging
///
/// High-frequency data (PUBACK delays, heartbeat RTTs) are kept as
/// sliding windows for percentile computation rather than individual
/// events to bound memory usage.
///
/// Export happens on demand via [snapshot], typically triggered by:
/// - Session end (disconnect / dispose)
/// - Error/crash (write last-known-good metrics)
/// - Manual diagnostic request
///
/// Usage:
/// ```dart
/// final metrics = ConnectionMetrics();
///
/// // Record events as they happen:
/// metrics.recordConnectSuccess();
/// metrics.recordQualityChange(LinkQuality.good, LinkQuality.degraded);
///
/// // Export on disconnect:
/// void onDisconnected() {
///   final snap = metrics.snapshot();
///   File('crash_metrics.json').writeAsStringSync(snap.toJsonString());
/// }
/// ```
class ConnectionMetrics {
  // ── Aggregated counters ──

  int connectAttempts = 0;
  int connectSuccesses = 0;
  int connectFailures = 0;
  int reconnectAttempts = 0;
  int reconnectSuccesses = 0;
  int reconnectFailures = 0;
  int unsolicitedDisconnects = 0;
  int intentionalDisconnects = 0;
  int maxBackoffReached = 0;

  int messagesSent = 0;
  int messagesReceived = 0;
  int commandsSent = 0;
  int commandsSucceeded = 0;
  int commandsTimedOut = 0;
  int commandsFailed = 0;
  int timeoutExtensions = 0;
  int heartbeatsSent = 0;
  int heartbeatsSucceeded = 0;
  int heartbeatsFailed = 0;
  int qualityDegradations = 0;
  int qualityRecoveries = 0;
  int qualityPoorCount = 0;

  // ── Timing ──

  DateTime? sessionStartTime;
  DateTime? _connectStartTime;
  DateTime? _disconnectStartTime;
  Duration totalConnectedDuration = Duration.zero;
  Duration totalDisconnectedDuration = Duration.zero;

  // ── Sliding windows (for percentiles, not individual events) ──

  static const int _maxLatencySamples = 200;
  final List<Duration> _pubAckDelays = [];
  final List<Duration> _heartbeatRtts = [];

  // ── Latency event decimation ──

  /// PUBACK fires on every QoS 1 publish (potentially hundreds/sec).
  /// Decimate to keep the event timeline manageable: record every Nth
  /// sample as a latency event, plus all outliers regardless.
  static const int _pubAckDecimation = 10;
  static const _pubAckOutlierThreshold = Duration(seconds: 1);
  int _pubAckSampleCount = 0;

  /// Heartbeat RTT fires ~120 times/hour — record every sample.
  /// Delta is recorded alongside RTT (same sampling rate).

  // ── Event timeline (ring buffer) ──

  /// Maximum number of events kept in the timeline.
  /// At ~100 events/hour for a typical session, 2000 events covers ~20 hours.
  static const int _maxTimelineEvents = 2000;
  final List<MetricsEvent> _eventTimeline = [];

  // ── Quality tracking ──

  String _currentQuality = 'good';
  DateTime? _qualityChangeTime;
  final Map<String, Duration> timeInQuality = {
    'good': Duration.zero,
    'degraded': Duration.zero,
    'poor': Duration.zero,
  };

  /// Optional callback invoked on each event (for real-time monitoring).
  void Function(MetricsEvent event)? onEvent;

  // ── Event recording ──

  void _addEvent(MetricsEventType type, {Map<String, dynamic>? data}) {
    final event = MetricsEvent(
      timestamp: DateTime.now(),
      type: type,
      data: data,
    );
    _eventTimeline.add(event);
    if (_eventTimeline.length > _maxTimelineEvents) {
      _eventTimeline.removeAt(0);
    }
    onEvent?.call(event);
  }

  // ── Connection lifecycle ──

  void recordConnectAttempt() {
    connectAttempts++;
    _addEvent(MetricsEventType.connectAttempt);
  }

  void recordConnectSuccess() {
    connectSuccesses++;
    final now = DateTime.now();
    sessionStartTime ??= now;
    _connectStartTime = now;
    _disconnectStartTime = null;
    _addEvent(MetricsEventType.connectSuccess);
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

    final now = DateTime.now();
    if (_connectStartTime != null) {
      totalConnectedDuration += now.difference(_connectStartTime!);
      _connectStartTime = null;
    }
    _disconnectStartTime = now;

    _addEvent(MetricsEventType.disconnect,
        data: {'intentional': intentional});
  }

  void recordReconnectAttempt() {
    reconnectAttempts++;
    final now = DateTime.now();
    if (_disconnectStartTime != null) {
      totalDisconnectedDuration += now.difference(_disconnectStartTime!);
      _disconnectStartTime = null;
    }
    _addEvent(MetricsEventType.reconnectAttempt);
  }

  void recordReconnectSuccess() {
    reconnectSuccesses++;
    final now = DateTime.now();
    _connectStartTime = now;
    _disconnectStartTime = null;
    _addEvent(MetricsEventType.reconnectSuccess);
  }

  void recordReconnectFailure() {
    reconnectFailures++;
    _addEvent(MetricsEventType.reconnectFailure);
  }

  void recordMaxBackoffReached() {
    maxBackoffReached++;
    _addEvent(MetricsEventType.maxBackoffReached);
  }

  // ── Messages ──

  void recordMessageSent() {
    messagesSent++;
  }

  void recordMessageReceived() {
    messagesReceived++;
  }

  void recordPubAckDelay(Duration delay) {
    _pubAckDelays.add(delay);
    if (_pubAckDelays.length > _maxLatencySamples) {
      _pubAckDelays.removeAt(0);
    }

    // Decimated event recording for offline threshold analysis
    _pubAckSampleCount++;
    if (_pubAckSampleCount % _pubAckDecimation == 0 ||
        delay > _pubAckOutlierThreshold) {
      _addEvent(MetricsEventType.latencySample,
          data: {'link': 'A', 'delayMs': _delayMs(delay)});
    }
  }

  /// Record a Link B (Broker ↔ Device + Moonraker) latency sample.
  /// Called from DeviceConnectionManager when Delta is computed.
  void recordLinkBLatency(Duration delta) {
    _addEvent(MetricsEventType.latencySample,
        data: {'link': 'B', 'delayMs': _delayMs(delta)});
  }

  /// Record full-path (heartbeat RTT) latency sample.
  /// Called from DeviceConnectionManager on each heartbeat success.
  void recordFullPathLatency(Duration rtt) {
    _addEvent(MetricsEventType.latencySample,
        data: {'link': 'full', 'delayMs': _delayMs(rtt)});
  }

  static double _delayMs(Duration d) =>
      (d.inMicroseconds / 1000.0).roundToDouble() / 1.0;

  // ── Commands ──

  void recordCommandSent() {
    commandsSent++;
  }

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

  void recordTimeoutExtension() {
    timeoutExtensions++;
    _addEvent(MetricsEventType.timeoutExtension);
  }

  // ── Heartbeat ──

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

  // ── Quality ──

  void recordQualityChange(LinkQuality from, LinkQuality to) {
    final now = DateTime.now();

    if (_qualityChangeTime != null) {
      final elapsed = now.difference(_qualityChangeTime!);
      final prevKey = from.name;
      timeInQuality[prevKey] =
          (timeInQuality[prevKey] ?? Duration.zero) + elapsed;
    }

    if (to == LinkQuality.degraded || to == LinkQuality.poor) {
      qualityDegradations++;
    } else if (to == LinkQuality.good) {
      qualityRecoveries++;
    }
    if (to == LinkQuality.poor) {
      qualityPoorCount++;
    }

    _addEvent(MetricsEventType.qualityChange,
        data: {'from': from.name, 'to': to.name});

    _currentQuality = to.name;
    _qualityChangeTime = now;
  }

  // ── Computed ──

  double get availability {
    final total = totalConnectedDuration + totalDisconnectedDuration;
    if (total == Duration.zero) return 1.0;
    return totalConnectedDuration.inMicroseconds / total.inMicroseconds;
  }

  double get connectSuccessRate =>
      connectAttempts == 0 ? 1.0 : connectSuccesses / connectAttempts;

  double get reconnectSuccessRate =>
      reconnectAttempts == 0 ? 1.0 : reconnectSuccesses / reconnectAttempts;

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

  // ── Export ──

  /// Produce an immutable snapshot of all metrics including the full
  /// event timeline. Call on disconnect, crash, or manual diagnostic.
  MetricsSnapshot snapshot() {
    if (_qualityChangeTime != null) {
      final elapsed = DateTime.now().difference(_qualityChangeTime!);
      timeInQuality[_currentQuality] =
          (timeInQuality[_currentQuality] ?? Duration.zero) + elapsed;
      _qualityChangeTime = DateTime.now();
    }

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
      timeInQuality: Map<String, Duration>.from(timeInQuality),
      availability: availability,
      connectSuccessRate: connectSuccessRate,
      reconnectSuccessRate: reconnectSuccessRate,
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

  /// Compact one-line summary for logging.
  @override
  String toString() => snapshot().toString();

  /// Reset everything. Call at the start of a new session.
  void reset() {
    connectAttempts = 0;
    connectSuccesses = 0;
    connectFailures = 0;
    reconnectAttempts = 0;
    reconnectSuccesses = 0;
    reconnectFailures = 0;
    unsolicitedDisconnects = 0;
    intentionalDisconnects = 0;
    maxBackoffReached = 0;
    messagesSent = 0;
    messagesReceived = 0;
    commandsSent = 0;
    commandsSucceeded = 0;
    commandsTimedOut = 0;
    commandsFailed = 0;
    timeoutExtensions = 0;
    heartbeatsSent = 0;
    heartbeatsSucceeded = 0;
    heartbeatsFailed = 0;
    qualityDegradations = 0;
    qualityRecoveries = 0;
    qualityPoorCount = 0;
    sessionStartTime = null;
    _connectStartTime = null;
    _disconnectStartTime = null;
    totalConnectedDuration = Duration.zero;
    totalDisconnectedDuration = Duration.zero;
    _pubAckDelays.clear();
    _heartbeatRtts.clear();
    _eventTimeline.clear();
    _currentQuality = 'good';
    _qualityChangeTime = null;
    timeInQuality['good'] = Duration.zero;
    timeInQuality['degraded'] = Duration.zero;
    timeInQuality['poor'] = Duration.zero;
  }
}

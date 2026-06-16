import 'dart:async';

/// Link quality levels derived from cross-validating multiple signals.
enum LinkQuality { good, degraded, poor }

/// Event emitted when link quality changes.
class LinkQualityEvent {
  final LinkQuality current;
  final LinkQuality previous;
  final int consecutiveCount;
  final Map<String, double> scores;
  final DateTime timestamp;

  LinkQualityEvent({
    required this.current,
    required this.previous,
    required this.consecutiveCount,
    Map<String, double>? scores,
    DateTime? timestamp,
  })  : scores = scores ?? {},
        timestamp = timestamp ?? DateTime.now();
}

/// Monitors link quality by aggregating multiple network signals:
///
/// - PUBACK delay (App ↔ Broker segment)
/// - Heartbeat RTT (full path)
/// - RTT − PUBACK delta (Broker ↔ Device segment, WAN only)
/// - Command success rate (application layer)
///
/// Supports two evaluation modes:
/// - LAN mode: single TCP hop; uses PUBACK + RTT (no delta)
/// - WAN mode: two-hop (App ↔ AWS IoT ↔ Device); uses PUBACK + RTT + delta
///
/// Anti-flap: uses asymmetric thresholds — 2 consecutive degraded/poor
/// evaluations to downgrade, 3 consecutive good to upgrade.
class LinkQualityMonitor {
  // ── Mode ──

  /// Whether this is a WAN (cloud-relayed) connection.
  /// In LAN mode the delta signal is not used since PUBACK and RTT
  /// measure the same TCP hop.
  final bool isWanMode;

  // ── Sliding windows ──

  static const int _pubAckWindowSize = 20;
  static const int _rttWindowSize = 20;
  static const int _deltaWindowSize = 10; // lower sampling rate (heartbeat-driven)
  static const int _cmdWindowSize = 20;

  final List<Duration> _pubAckSamples = [];
  final List<Duration> _rttSamples = [];
  final List<Duration> _deltaSamples = [];
  final List<bool> _cmdResults = []; // true = success, false = timeout/fail

  // ── Thresholds (WAN) ──

  static const _pubAckGoodWan = Duration(milliseconds: 200);
  static const _pubAckPoorWan = Duration(seconds: 2);
  static const _deltaGoodWan = Duration(milliseconds: 300);
  static const _deltaPoorWan = Duration(seconds: 3);
  static const _rttGoodWan = Duration(milliseconds: 500);

  // ── Thresholds (LAN) ──

  static const _pubAckGoodLan = Duration(milliseconds: 50);
  static const _pubAckPoorLan = Duration(milliseconds: 500);
  static const _rttGoodLan = Duration(milliseconds: 100);
  static const _rttPoorLan = Duration(seconds: 1);

  // ── Evaluation ──

  static const _evaluationInterval = Duration(seconds: 5);
  static const _degradeThreshold = 2; // consecutive degraded/poor → downgrade
  static const _recoverThreshold = 3; // consecutive good → upgrade

  Timer? _evalTimer;

  // ── State ──

  LinkQuality _quality = LinkQuality.good;
  int _consecutiveCount = 0; // consecutive evaluations at current quality
  LinkQuality _pendingQuality = LinkQuality.good;
  int _pendingCount = 0;

  /// The most recently computed RTT − PUBACK delta (Link B latency).
  /// Null if no heartbeat has completed yet or in LAN mode.
  Duration? get lastDelta => _deltaSamples.isNotEmpty ? _deltaSamples.last : null;

  final _qualityController = StreamController<LinkQualityEvent>.broadcast();

  LinkQualityMonitor({this.isWanMode = false});

  LinkQuality get quality => _quality;
  Stream<LinkQualityEvent> get qualityStream => _qualityController.stream;

  // ── Inputs ──

  /// Record a PUBACK delay sample (App ↔ Broker).
  void onPubAckDelay(Duration delay) {
    _pubAckSamples.add(delay);
    if (_pubAckSamples.length > _pubAckWindowSize) {
      _pubAckSamples.removeAt(0);
    }
  }

  /// Record a heartbeat result.
  ///
  /// [rtt] is the full-path round-trip time (null if heartbeat failed).
  void onHeartbeatResult(bool success, {Duration? rtt}) {
    if (success && rtt != null) {
      _rttSamples.add(rtt);
      if (_rttSamples.length > _rttWindowSize) {
        _rttSamples.removeAt(0);
      }

      // Compute delta: RTT − PUBACK baseline = Broker ↔ Device segment
      if (isWanMode) {
        final pubAckBaseline = _medianPubAck();
        if (pubAckBaseline != null) {
          final delta = rtt - pubAckBaseline;
          // Clamp negative values (can happen if RTT < PUBACK due to timing)
          _deltaSamples.add(delta > Duration.zero ? delta : Duration.zero);
          if (_deltaSamples.length > _deltaWindowSize) {
            _deltaSamples.removeAt(0);
          }
        }
      }
    }
  }

  /// Record a command result.
  void onCommandResult(bool success) {
    _cmdResults.add(success);
    if (_cmdResults.length > _cmdWindowSize) {
      _cmdResults.removeAt(0);
    }
  }

  /// Reset all windows (e.g., on reconnect).
  void onDisconnected() {
    // Don't clear windows immediately — stale data is worse than no data.
    // Let old samples age out naturally.
  }

  // ── Lifecycle ──

  void start() {
    _evalTimer?.cancel();
    _evalTimer = Timer.periodic(_evaluationInterval, (_) => _evaluate());
  }

  void stop() {
    _evalTimer?.cancel();
    _evalTimer = null;
  }

  void dispose() {
    stop();
    _qualityController.close();
  }

  // ── Evaluation ──

  void _evaluate() {
    final newQuality = isWanMode ? _evaluateWan() : _evaluateLan();

    if (newQuality == _pendingQuality) {
      _pendingCount++;
    } else {
      _pendingQuality = newQuality;
      _pendingCount = 1;
    }

    // Downgrade: need _degradeThreshold consecutive degraded/poor
    if (newQuality != LinkQuality.good && _pendingCount >= _degradeThreshold) {
      _transition(newQuality);
      return;
    }

    // Upgrade: need _recoverThreshold consecutive good
    if (newQuality == LinkQuality.good) {
      if (_quality != LinkQuality.good && _pendingCount >= _recoverThreshold) {
        _transition(LinkQuality.good);
        return;
      }
      if (_quality == LinkQuality.good && _pendingCount >= _recoverThreshold) {
        // Already good, just update consecutive count for tracking
        _consecutiveCount++;
      }
    }
  }

  void _transition(LinkQuality newQuality) {
    if (newQuality == _quality) {
      _consecutiveCount++;
      return;
    }

    final event = LinkQualityEvent(
      current: newQuality,
      previous: _quality,
      consecutiveCount: _consecutiveCount,
      scores: _computeScores(),
    );

    _quality = newQuality;
    _consecutiveCount = 1;
    _pendingQuality = newQuality;
    _pendingCount = 0;

    _qualityController.add(event);
  }

  // ── WAN evaluation ──

  LinkQuality _evaluateWan() {
    final p95PubAck = _percentile(_pubAckSamples, 95);
    final p95Rtt = _percentile(_rttSamples, 95);
    final p95Delta = _percentile(_deltaSamples, 95);
    final cmdRate = _successRate();

    // Require minimum samples before making decisions
    if (_pubAckSamples.length < 3) return _quality;

    final pubAckOk = p95PubAck != null && p95PubAck < _pubAckGoodWan;
    final pubAckPoor = p95PubAck != null && p95PubAck > _pubAckPoorWan;
    final rttOk = p95Rtt != null && p95Rtt < _rttGoodWan;
    final deltaOk = p95Delta == null || p95Delta < _deltaGoodWan;
    final deltaPoor = p95Delta != null && p95Delta > _deltaPoorWan;
    final cmdOk = _cmdResults.isEmpty || cmdRate == null || cmdRate > 0.5;

    // All green → good
    if (pubAckOk && rttOk && deltaOk && cmdOk) return LinkQuality.good;

    // Command failure rate high → poor
    if (!cmdOk) return LinkQuality.poor;

    // App-side only → degraded
    if (pubAckPoor && deltaOk) return LinkQuality.degraded;

    // Device-side only → degraded
    if (pubAckOk && deltaPoor) return LinkQuality.degraded;

    // Both sides poor → poor
    if (pubAckPoor && deltaPoor) return LinkQuality.poor;

    // Default: degraded
    return LinkQuality.degraded;
  }

  // ── LAN evaluation ──

  LinkQuality _evaluateLan() {
    final p95PubAck = _percentile(_pubAckSamples, 95);
    final p95Rtt = _percentile(_rttSamples, 95);
    final cmdRate = _successRate();

    if (_pubAckSamples.length < 3) return _quality;

    final pubAckOk = p95PubAck != null && p95PubAck < _pubAckGoodLan;
    final pubAckPoor = p95PubAck != null && p95PubAck > _pubAckPoorLan;
    final rttOk = p95Rtt != null && p95Rtt < _rttGoodLan;
    final rttPoor = p95Rtt != null && p95Rtt > _rttPoorLan;
    final cmdOk = _cmdResults.isEmpty || cmdRate == null || cmdRate > 0.5;

    if (pubAckOk && rttOk && cmdOk) return LinkQuality.good;
    if (!cmdOk) return LinkQuality.poor;
    if (pubAckPoor || rttPoor) return LinkQuality.degraded;
    return LinkQuality.good;
  }

  // ── Statistics helpers ──

  Duration? _percentile(List<Duration> samples, int percentile) {
    if (samples.isEmpty) return null;
    final sorted = List<Duration>.from(samples)..sort();
    final index = ((percentile / 100) * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  Duration? _medianPubAck() {
    if (_pubAckSamples.isEmpty) return null;
    final sorted = List<Duration>.from(_pubAckSamples)..sort();
    return sorted[sorted.length ~/ 2];
  }

  double? _successRate() {
    if (_cmdResults.isEmpty) return null;
    return _cmdResults.where((r) => r).length / _cmdResults.length;
  }

  Map<String, double> _computeScores() {
    final p95PubAck = _percentile(_pubAckSamples, 95);
    final p95Rtt = _percentile(_rttSamples, 95);
    final p95Delta = _percentile(_deltaSamples, 95);
    final cmdRate = _successRate();

    return {
      'pubAckP95Ms': p95PubAck?.inMilliseconds.toDouble() ?? -1,
      'rttP95Ms': p95Rtt?.inMilliseconds.toDouble() ?? -1,
      if (isWanMode) 'deltaP95Ms': p95Delta?.inMilliseconds.toDouble() ?? -1,
      'cmdSuccessRate': cmdRate ?? -1,
    };
  }
}

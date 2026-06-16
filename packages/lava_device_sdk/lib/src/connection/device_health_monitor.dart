import 'dart:async';

/// Overall device health determined by cross-validating
/// MQTT Last Will + heartbeat signals.
///
/// Per the heartbeat optimization design:
///   healthy    — both signals agree the device is alive and responsive
///   degraded   — device is reachable but something is wrong
///                (zombie process, Klipper disconnected, or high latency)
///   unreachable — device is definitely offline (Last Will triggered)
enum DeviceHealth { healthy, degraded, unreachable }

/// Reason for a degraded/unreachable state.
enum HealthChangeReason {
  mqttDisconnected,   // Last Will triggered → unreachable
  heartbeatTimeout3x,  // MQTT alive but 3 consecutive heartbeats timed out
  klipperDisconnected, // Klipper is not connected to Moonraker
  highLatency,         // RTT > threshold
  restored,            // Returned to healthy
  unknown,
}

/// Event emitted when device health changes.
class HealthChangeEvent {
  final DeviceHealth health;
  final HealthChangeReason reason;
  final String? detail;
  final DateTime timestamp;

  HealthChangeEvent({
    required this.health,
    required this.reason,
    this.detail,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'HealthChangeEvent($health, $reason${detail != null ? " detail: $detail" : ""})';
}

/// Monitors device health by cross-validating two signals:
///
/// Signal 1: MQTT Last Will — detects disconnect/power-off (TCP-level)
/// Signal 2: Heartbeat (server.info) — detects zombie processes (app-level)
///
/// The two signals' blind spots don't overlap:
///   - Last Will alone can't detect zombie (TCP still alive but app dead)
///   - Heartbeat alone can't distinguish WiFi drop from zombie
///   - Together: Last Will=online + heartbeat=timeout → zombie
///
/// Usage:
/// ```dart
/// final monitor = DeviceHealthMonitor();
/// monitor.healthStream.listen((event) {
///   switch (event.health) {
///     case DeviceHealth.unreachable: showOffline();
///     case DeviceHealth.degraded: showWarning(event.reason);
///     case DeviceHealth.healthy: showOk();
///   }
/// });
///
/// // Wire up signals:
/// mqttClient.onNotification((msg) {
///   if (msg['server'] == 'online') monitor.onMqttOnline();
///   if (msg['server'] == 'offline') monitor.onMqttOffline();
/// });
/// heartbeat.onResult((ok, rtt) => monitor.onHeartbeatResult(ok, rtt: rtt));
/// ```
class DeviceHealthMonitor {
  final int maxHeartbeatFailures;
  final Duration highLatencyThreshold;

  // Signal states
  bool _mqttAlive = false; // Assume offline until proven otherwise
  int _hbFailCount = 0;
  Duration? _lastRtt;
  DateTime? _lastHbOk;
  bool _klippyConnected = true; // Assume ok until told otherwise

  DeviceHealth _health = DeviceHealth.unreachable;
  HealthChangeReason _lastReason = HealthChangeReason.unknown;

  final _healthCtrl = StreamController<HealthChangeEvent>.broadcast();
  final _disposeCtrl = StreamController<void>.broadcast();

  DeviceHealthMonitor({
    this.maxHeartbeatFailures = 3,
    this.highLatencyThreshold = const Duration(milliseconds: 400),
  });

  /// Stream of health change events. Only emits when health or reason changes.
  Stream<HealthChangeEvent> get healthStream => _healthCtrl.stream;

  /// Current health state.
  DeviceHealth get health => _health;

  /// Reason for the current health state.
  HealthChangeReason get lastReason => _lastReason;

  // ── Signal inputs ──

  /// Call when MQTT Last Will reports device online.
  void onMqttOnline() {
    _mqttAlive = true;
    _evaluate(HealthChangeReason.restored);
  }

  /// Call when MQTT Last Will reports device offline.
  void onMqttOffline() {
    _mqttAlive = false;
    _hbFailCount = 0;
    _lastRtt = null;
    _lastHbOk = null;
    _evaluate(HealthChangeReason.mqttDisconnected);
  }

  /// Call after each heartbeat attempt completes.
  ///
  /// [success] — whether the heartbeat got a response.
  /// [rtt] — round-trip time if successful.
  /// [klippyConnected] — from server.info response (if available).
  /// [klippyState] — Klipper state string (ready/printing/paused/error).
  void onHeartbeatResult(
    bool success, {
    Duration? rtt,
    bool? klippyConnected,
    String? klippyState,
  }) {
    if (success) {
      _hbFailCount = 0;
      _lastHbOk = DateTime.now();
      _lastRtt = rtt;
      if (klippyConnected != null) {
        _klippyConnected = klippyConnected;
      }
    } else {
      _hbFailCount++;
    }
    _evaluate(success ? HealthChangeReason.restored : HealthChangeReason.heartbeatTimeout3x);
  }

  /// Update Klipper connection state from an external source
  /// (e.g., notify_klippy_state_changed notification).
  void onKlippyStateChanged({required bool connected, String? state}) {
    if (!connected && _klippyConnected) {
      _klippyConnected = false;
      _evaluate(HealthChangeReason.klipperDisconnected);
    } else if (connected && !_klippyConnected) {
      _klippyConnected = true;
      _evaluate(HealthChangeReason.restored);
    }
  }

  // ── Evaluation ──

  void _evaluate(HealthChangeReason trigger) {
    DeviceHealth newHealth;
    HealthChangeReason reason = trigger;

    if (!_mqttAlive) {
      // Last Will triggered → definitely offline
      newHealth = DeviceHealth.unreachable;
      reason = HealthChangeReason.mqttDisconnected;
    } else if (_hbFailCount >= maxHeartbeatFailures && _hbFailCount > 0) {
      // MQTT alive but heartbeat keeps failing → zombie process
      // Check: was it previously healthy? If so, degraded. If never connected, unreachable.
      newHealth = _lastHbOk != null
          ? DeviceHealth.degraded
          : DeviceHealth.unreachable;
      reason = HealthChangeReason.heartbeatTimeout3x;
    } else if (!_klippyConnected) {
      newHealth = DeviceHealth.degraded;
      reason = HealthChangeReason.klipperDisconnected;
    } else if (_lastRtt != null && _lastRtt! > highLatencyThreshold) {
      newHealth = DeviceHealth.degraded;
      reason = HealthChangeReason.highLatency;
    } else {
      newHealth = DeviceHealth.healthy;
      reason = HealthChangeReason.restored;
    }

    if (newHealth != _health || reason != _lastReason) {
      _health = newHealth;
      _lastReason = reason;
      _healthCtrl.add(HealthChangeEvent(
        health: _health,
        reason: reason,
        detail: _healthDetail(),
      ));
    }
  }

  String? _healthDetail() {
    return switch (_health) {
      DeviceHealth.healthy => null,
      DeviceHealth.degraded => 'hbFails=$_hbFailCount/${maxHeartbeatFailures} '
          'klippy=${_klippyConnected ? "ok" : "disconnected"} '
          'rtt=${_lastRtt?.inMilliseconds ?? "?"}ms',
      DeviceHealth.unreachable => _mqttAlive
          ? 'zombie (MQTT alive but no response)'
          : 'mqtt disconnected',
    };
  }

  /// Reset all state (e.g., on manual disconnect).
  void reset() {
    _mqttAlive = false;
    _hbFailCount = 0;
    _lastRtt = null;
    _lastHbOk = null;
    _klippyConnected = true;
    _health = DeviceHealth.unreachable;
    _lastReason = HealthChangeReason.unknown;
  }

  void dispose() {
    _healthCtrl.close();
    _disposeCtrl.close();
  }
}

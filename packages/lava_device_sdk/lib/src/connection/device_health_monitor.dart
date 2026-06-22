// Deprecated: Use SmartHeartbeatManager instead.
//
// DeviceHealthMonitor has been superseded by SmartHeartbeatManager which now
// combines heartbeat sending + health evaluation in a single class.
//
// To migrate:
//   - Replace `DeviceHealthMonitor()` with `SmartHeartbeatManager()`
//   - All signal inputs (onMqttOnline, onMqttOffline, onHeartbeatResult, etc.)
//     are now available directly on SmartHeartbeatManager
//   - Health stream: `healthStream` is on SmartHeartbeatManager
import 'dart:async';
import 'smart_heartbeat_manager.dart';

/// Deprecated. Use [SmartHeartbeatManager] instead.
///
/// Monitors device health by cross-validating MQTT Last Will + heartbeat signals.
///
/// This class is kept for backward compatibility. New code should use
/// [SmartHeartbeatManager] which provides the same health monitoring
/// plus integrated heartbeat management.
class DeviceHealthMonitor {
  final int maxHeartbeatFailures;
  final Duration highLatencyThreshold;

  // Signal states
  bool _mqttAlive = false;
  int _hbFailCount = 0;
  Duration? _lastRtt;
  DateTime? _lastHbOk;
  bool _klippyConnected = true;

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

  /// Update Klipper connection state from an external source.
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
      newHealth = DeviceHealth.unreachable;
      reason = HealthChangeReason.mqttDisconnected;
    } else if (_hbFailCount >= maxHeartbeatFailures && _hbFailCount > 0) {
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

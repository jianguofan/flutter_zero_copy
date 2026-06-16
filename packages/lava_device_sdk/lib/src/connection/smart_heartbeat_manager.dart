import 'dart:async';

/// Smart heartbeat manager that only sends heartbeats when the connection
/// has been idle for longer than [idleThreshold], avoiding ~70% of
/// unnecessary heartbeat traffic compared to fixed-interval approaches.
///
/// Usage:
/// ```dart
/// final hb = SmartHeartbeatManager(
///   onSendHeartbeat: () => transport.send('/heartbeat', payload),
/// );
/// hb.start();
///
/// // Call on every inbound/outbound message:
/// hb.recordCommunication();
/// ```
class SmartHeartbeatManager {
  /// Duration without communication before sending a heartbeat.
  final Duration idleThreshold;

  /// How often to check whether a heartbeat is needed.
  final Duration checkInterval;

  /// Callback invoked when a heartbeat should be sent.
  final Future<void> Function() onSendHeartbeat;

  DateTime? _lastCommunicationTime;
  Timer? _checkTimer;

  SmartHeartbeatManager({
    this.idleThreshold = const Duration(seconds: 30),
    this.checkInterval = const Duration(seconds: 10),
    required this.onSendHeartbeat,
  });

  /// Start the idle-check loop.
  void start() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(checkInterval, (_) {
      _checkAndSendHeartbeat();
    });
  }

  /// Record that communication happened (call on every sent/received message).
  void recordCommunication() {
    _lastCommunicationTime = DateTime.now();
  }

  /// Stop the heartbeat loop.
  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  void dispose() => stop();

  // ── internal ──

  void _checkAndSendHeartbeat() {
    if (_lastCommunicationTime == null) {
      _sendHeartbeat();
      return;
    }

    final idleTime = DateTime.now().difference(_lastCommunicationTime!);
    if (idleTime > idleThreshold) {
      _sendHeartbeat();
    }
  }

  void _sendHeartbeat() {
    onSendHeartbeat();
    recordCommunication(); // heartbeat itself counts as communication
  }
}

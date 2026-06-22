import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/connection_phase.dart';
import '../models/heartbeat_state.dart';
import '../models/link_quality.dart';
import '../models/metrics_event.dart';
import '../models/metrics_snapshot.dart';

/// 模拟设备连接监控器 — ChangeNotifier，驱动 UI 实时刷新
///
/// 模拟真实的设备连接生命周期：
/// - 连接阶段变化 (disconnected → connecting → ... → connected)
/// - 心跳 (每 10s, 95% 成功率)
/// - PUBACK 延迟 (50-200ms)
/// - 链路质量波动
/// - 消息/命令计数
class MockDeviceMonitor extends ChangeNotifier {
  final _random = Random();

  // ── 连接状态 ──
  ConnectionPhase _phase = ConnectionPhase.disconnected;
  DateTime? _sessionStart;

  // ── 心跳 ──
  HeartbeatState _heartbeat = const HeartbeatState();

  // ── 链路质量 ──
  LinkQuality _quality = LinkQuality.good;
  LinkQuality _prevQuality = LinkQuality.good;

  // ── 指标收集器 ──
  final ConnectionMetrics _metrics = ConnectionMetrics();

  // ── 事件流 ──
  final _eventController = StreamController<MetricsEvent>.broadcast();

  // ── 定时器 ──
  Timer? _lifecycleTimer;
  Timer? _heartbeatTimer;
  Timer? _messageTimer;

  // ── Getters ──

  ConnectionPhase get phase => _phase;
  HeartbeatState get heartbeat => _heartbeat;
  LinkQuality get quality => _quality;
  ConnectionMetrics get metrics => _metrics;
  MetricsSnapshot get snapshot => _metrics.snapshot();
  Stream<MetricsEvent> get eventStream => _eventController.stream;
  DateTime? get sessionStart => _sessionStart;
  String get phaseLabel {
    switch (_phase) {
      case ConnectionPhase.disconnected: return '未连接';
      case ConnectionPhase.connecting:   return '连接中…';
      case ConnectionPhase.authorizing:  return '授权中…';
      case ConnectionPhase.authorized:   return '已授权';
      case ConnectionPhase.connected:    return '已连接';
      case ConnectionPhase.failed:       return '失败';
    }
  }

  Color get phaseColor {
    switch (_phase) {
      case ConnectionPhase.connected:  return const Color(0xFF00D4AA);
      case ConnectionPhase.authorizing:
      case ConnectionPhase.authorized:
      case ConnectionPhase.connecting: return const Color(0xFFFF9900);
      case ConnectionPhase.failed:     return const Color(0xFFF40004);
      case ConnectionPhase.disconnected: return const Color(0xFF999999);
    }
  }

  Color get qualityColor {
    switch (_quality) {
      case LinkQuality.good:     return const Color(0xFF00D4AA);
      case LinkQuality.degraded: return const Color(0xFFFF9900);
      case LinkQuality.poor:     return const Color(0xFFF40004);
    }
  }

  // ── 生命周期 ──

  void start() {
    _metrics.onEvent = (e) => _eventController.add(e);
    _startLifecycle();
    _startHeartbeat();
    _startMessages();
    notifyListeners();
  }

  void _startLifecycle() {
    // 模拟: 立即开始连接
    _transition(ConnectionPhase.connecting);
    _metrics.recordConnectAttempt();

    Future.delayed(const Duration(seconds: 1), () {
      _transition(ConnectionPhase.authorizing);
      Future.delayed(const Duration(milliseconds: 800), () {
        _transition(ConnectionPhase.authorized);
        Future.delayed(const Duration(milliseconds: 600), () {
          _transition(ConnectionPhase.connected);
          _metrics.recordConnectSuccess();
          _sessionStart = DateTime.now();
          notifyListeners();
        });
      });
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final success = _random.nextDouble() > 0.05; // 95% success
      final rtt = Duration(milliseconds: 80 + _random.nextInt(400));
      _metrics.recordHeartbeat(success, rtt: rtt);

      _heartbeat = _heartbeat.copyWith(
        active: true,
        lastOk: success ? DateTime.now() : _heartbeat.lastOk,
        failCount: success ? 0 : _heartbeat.failCount + 1,
        isIdle: false,
        lastComm: DateTime.now(),
      );
      notifyListeners();
    });
  }

  void _startMessages() {
    _messageTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_phase != ConnectionPhase.connected) return;

      // 发送消息
      _metrics.recordMessageSent();
      _metrics.recordMessageReceived();

      // 模拟 PUBACK 延迟
      final pubAckDelay =
          Duration(milliseconds: 40 + _random.nextInt(150));
      _metrics.recordPubAckDelay(pubAckDelay);

      // 偶尔模拟命令
      if (_random.nextDouble() > 0.7) {
        _metrics.recordCommandSent();
        final success = _random.nextDouble() > 0.08;
        _metrics.recordCommandResult(success,
            timedOut: !success && _random.nextDouble() > 0.5);
      }

      // 偶尔质量波动
      if (_random.nextDouble() > 0.85) {
        final qualities = LinkQuality.values;
        final newQ = qualities[_random.nextInt(3)];
        if (newQ != _quality) {
          _prevQuality = _quality;
          _quality = newQ;
          _metrics.recordQualityChange(_prevQuality, _quality);
          notifyListeners();
        }
      }

      notifyListeners();
    });
  }

  void _transition(ConnectionPhase newPhase) {
    _phase = newPhase;
    _eventController.add(MetricsEvent(
        timestamp: DateTime.now(),
        type: MetricsEventType.connectAttempt));
    notifyListeners();
  }

  void disconnect() {
    _metrics.recordDisconnect(intentional: true);
    _transition(ConnectionPhase.disconnected);
    _heartbeat = const HeartbeatState();
    notifyListeners();
  }

  /// 导出 JSON 到控制台
  String exportJson() => _metrics.snapshot().toJsonString();

  @override
  void dispose() {
    _lifecycleTimer?.cancel();
    _heartbeatTimer?.cancel();
    _messageTimer?.cancel();
    _eventController.close();
    super.dispose();
  }
}

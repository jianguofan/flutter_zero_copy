import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/connection_phase.dart';
import '../models/connection_config.dart';
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

  // ── 连接配置（元数据） ──
  final ConnectionConfig config = const ConnectionConfig(
    mode: ConnectionMode.lan,
    host: '192.168.1.100',
    port: 7125,
    sn: 'SM-4B-202406-00042',
    accessCode: '12345678',
  );

  // ── 模拟 Store 数据 ──
  final Map<String, dynamic> _storeData = {
    'print_stats': {
      'state': 'printing',
      'filename': 'gear_bracket.gcode',
      'total_duration': 1432.5,
      'print_duration': 623.8,
      'filament_used': 42.3,
      'progress': 0.47,
    },
    'toolhead': {
      'position': {'x': 120.5, 'y': 85.3, 'z': 15.2},
      'extruder': {'temperature': 210.0, 'target': 210.0},
    },
    'heated_bed': {
      'temperature': 60.0,
      'target': 60.0,
    },
    'fan': {
      'speed': 0.85,
    },
    'gcode_move': {
      'speed': 1500,
      'speed_factor': 1.0,
      'extrude_factor': 1.0,
    },
  };

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
  Map<String, dynamic> get storeData => Map<String, dynamic>.from(_storeData);

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


      // 模拟收到消息
      final recvSize = 64 + _random.nextInt(512);
      _metrics.recordMessageReceived(
          topic: '/status', size: recvSize);

      // 模拟 PUBACK 延迟
      final pubAckDelay =
          Duration(milliseconds: 40 + _random.nextInt(150));
      _metrics.recordPubAckDelay(pubAckDelay);

      // 模拟发送消息（偶尔）
      if (_random.nextDouble() > 0.5) {
        final sendSize = 32 + _random.nextInt(256);
        _metrics.recordMessageSent(
            topic: '/request', size: sendSize);
      }

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

      // 模拟 Store 数据变化
      if (_storeData['print_stats'] is Map) {
        final stats = _storeData['print_stats'] as Map<String, dynamic>;
        stats['progress'] = ((stats['progress'] as double) + 0.002)
            .clamp(0.0, 1.0);
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

  /// 导出完整数据: metadata + store + metrics + events
  Map<String, dynamic> exportAll() {
    return {
      'metadata': {
        'mode': config.mode.name,
        'host': config.host,
        'port': config.port,
        'sn': config.sn,
        'accessCode': config.accessCode,
        'phase': _phase.name,
        'sessionStart': _sessionStart?.toIso8601String(),
        'quality': _quality.name,
      },
      'store': _storeData,
      'metrics': snapshot.toJson(),
      'events': _metrics.events.map((e) => e.toJson()).toList(),
    };
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

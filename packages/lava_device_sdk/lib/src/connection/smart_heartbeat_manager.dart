import 'dart:async';

// ══════════════════════════════════════════════
// Models
// ══════════════════════════════════════════════

/// Heartbeat result returned by the [SmartHeartbeatManager.onSendHeartbeat] callback.
class HeartbeatResult {
  final bool success;
  final Duration? rtt;
  final bool? klippyConnected;
  final String? klippyState;

  const HeartbeatResult({
    required this.success,
    this.rtt,
    this.klippyConnected,
    this.klippyState,
  });
}

/// 心跳状态快照（不可变，供 UI 消费）
class HeartbeatState {
  final bool active;
  final DateTime? lastOk;
  final int failCount;
  final bool isIdle;
  final DateTime? lastComm;
  final DateTime? lastHeartbeatSent;

  const HeartbeatState({
    this.active = false,
    this.lastOk,
    this.failCount = 0,
    this.isIdle = true,
    this.lastComm,
    this.lastHeartbeatSent,
  });

  HeartbeatState copyWith({
    bool? active,
    DateTime? lastOk,
    int? failCount,
    bool? isIdle,
    DateTime? lastComm,
    DateTime? lastHeartbeatSent,
  }) {
    return HeartbeatState(
      active: active ?? this.active,
      lastOk: lastOk ?? this.lastOk,
      failCount: failCount ?? this.failCount,
      isIdle: isIdle ?? this.isIdle,
      lastComm: lastComm ?? this.lastComm,
      lastHeartbeatSent: lastHeartbeatSent ?? this.lastHeartbeatSent,
    );
  }
}

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
  mqttDisconnected,    // Last Will triggered → unreachable
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
  String toString() =>
      'HealthChangeEvent($health, $reason${detail != null ? " detail: $detail" : ""})';
}

// ══════════════════════════════════════════════
// SmartHeartbeatManager — 空闲触发心跳 + 健康评估
// ══════════════════════════════════════════════

/// 统一智能心跳管理器。
///
/// **心跳策略**: 任何通信活动（收发消息/心跳回复）都重置 30s 计时器，
/// 闲置满 30s 才发送心跳，心跳回复也重置计时器。
///
/// **健康评估**: 双信号交叉验证：
///   - 信号1: MQTT Last Will（online/offline）— 检测断连/掉电（TCP 层）
///   - 信号2: 心跳结果（server.info）— 检测僵尸进程（应用层）
///
/// 两个信号的盲区不重叠：
///   - Last Will 单独无法检测僵尸进程（TCP 存活但应用假死）
///   - 心跳单独无法区分 WiFi 断连和僵尸进程
///   - 结合: Last Will=online + 心跳=超时 → 僵尸进程
///
/// ```
/// 时间线示例:
///   T+0s   消息通信 → recordCommunication()，重置空闲计时
///   T+5s   消息通信 → 重置
///   T+10s  检查 → 空闲仅 5s < 30s → 不发送
///   T+20s  检查 → 空闲 15s < 30s → 不发送
///   T+30s  检查 → 空闲 25s < 30s → 不发送
///   T+40s  检查 → 空闲 35s > 30s → 发送心跳
/// ```
///
/// 相比固定 10s 间隔在同样时段内发 4 次心跳，这里只发 1 次。
///
/// Usage:
/// ```dart
/// final hb = SmartHeartbeatManager(
///   onSendHeartbeat: () async {
///     // Send server.info and return the result
///     final response = await transport.send(serverInfoRequest);
///     return HeartbeatResult(
///       success: true,
///       rtt: response.rtt,
///       klippyConnected: response.klippyConnected,
///       klippyState: response.klippyState,
///     );
///   },
/// );
///
/// // Monitor health changes
/// hb.healthStream.listen((event) {
///   switch (event.health) {
///     case DeviceHealth.unreachable: showOffline();
///     case DeviceHealth.degraded: showWarning(event.reason);
///     case DeviceHealth.healthy: showOk();
///   }
/// });
///
/// // Wire MQTT Last Will signals
/// mqttClient.onNotification((msg) {
///   if (msg['server'] == 'online') hb.onMqttOnline();
///   if (msg['server'] == 'offline') hb.onMqttOffline();
/// });
///
/// // Track communication
/// hb.recordCommunication(); // call on every message sent/received
/// ```
class SmartHeartbeatManager {
  /// 无通信持续多久后触发心跳（默认 30s）
  final Duration idleThreshold;

  /// 检查间隔（默认 10s）
  final Duration checkInterval;

  /// 连续心跳失败多少次视为健康降级
  final int maxHeartbeatFailures;

  /// RTT 超过此阈值视为高延迟
  final Duration highLatencyThreshold;

  /// 发送心跳的回调，返回 [HeartbeatResult]。
  /// SmartHeartbeatManager 根据返回结果自动评估健康状态。
  final Future<HeartbeatResult> Function() onSendHeartbeat;

  // ── 通信跟踪 ──

  DateTime? _lastCommunicationTime;
  DateTime? _lastHeartbeatSent;
  DateTime? _lastHeartbeatOk;
  int _hbFailCount = 0;
  Timer? _checkTimer;

  // ── 健康评估状态（来自 DeviceHealthMonitor） ──

  bool _mqttAlive = false;
  Duration? _lastRtt;
  bool _klippyConnected = true;
  DeviceHealth _health = DeviceHealth.unreachable;
  HealthChangeReason _lastReason = HealthChangeReason.unknown;

  // ── 流控制器 ──

  final _stateController = StreamController<HeartbeatState>.broadcast();
  final _healthController = StreamController<HealthChangeEvent>.broadcast();

  SmartHeartbeatManager({
    this.idleThreshold = const Duration(seconds: 30),
    this.checkInterval = const Duration(seconds: 10),
    this.maxHeartbeatFailures = 3,
    this.highLatencyThreshold = const Duration(milliseconds: 400),
    required this.onSendHeartbeat,
  });

  // ── 流 ──

  /// 心跳状态流（供 UI 消费）
  Stream<HeartbeatState> get stateStream => _stateController.stream;

  /// 健康变化事件流。仅在健康状态或原因变化时发出。
  Stream<HealthChangeEvent> get healthStream => _healthController.stream;

  // ── 当前状态 ──

  /// 当前心跳状态快照
  HeartbeatState get currentState => HeartbeatState(
        active: _checkTimer != null,
        lastOk: _lastHeartbeatOk,
        failCount: _hbFailCount,
        isIdle: _isIdle,
        lastComm: _lastCommunicationTime,
        lastHeartbeatSent: _lastHeartbeatSent,
      );

  /// 当前设备健康状态
  DeviceHealth get health => _health;

  /// 当前健康状态的原因
  HealthChangeReason get lastReason => _lastReason;

  bool get _isIdle {
    if (_lastCommunicationTime == null) return true;
    return DateTime.now().difference(_lastCommunicationTime!) > idleThreshold;
  }

  // ── 生命周期 ──

  /// 启动空闲检测循环。
  void start() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(checkInterval, (_) => _checkAndSend());
    _emitState();
  }

  /// 记录通信活动 — 每次收发消息时调用，重置空闲计时器。
  void recordCommunication() {
    _lastCommunicationTime = DateTime.now();
    _emitState();
  }

  /// 停止心跳循环。
  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _emitState();
  }

  void dispose() {
    stop();
    _stateController.close();
    _healthController.close();
  }

  // ── 健康信号输入（来自 DeviceHealthMonitor） ──

  /// MQTT Last Will 报告设备在线。
  void onMqttOnline() {
    _mqttAlive = true;
    _evaluateHealth(HealthChangeReason.restored);
  }

  /// MQTT Last Will 报告设备离线。
  void onMqttOffline() {
    _mqttAlive = false;
    _hbFailCount = 0;
    _lastRtt = null;
    _lastHeartbeatOk = null;
    _evaluateHealth(HealthChangeReason.mqttDisconnected);
  }

  /// 更新 Klipper 连接状态（来自 notify_klippy_state_changed 通知）。
  void onKlippyStateChanged({required bool connected, String? state}) {
    if (!connected && _klippyConnected) {
      _klippyConnected = false;
      _evaluateHealth(HealthChangeReason.klipperDisconnected);
    } else if (connected && !_klippyConnected) {
      _klippyConnected = true;
      _evaluateHealth(HealthChangeReason.restored);
    }
  }

  /// 重置所有状态（手动断连时）。
  void reset() {
    _mqttAlive = false;
    _hbFailCount = 0;
    _lastRtt = null;
    _lastHeartbeatOk = null;
    _klippyConnected = true;
    _health = DeviceHealth.unreachable;
    _lastReason = HealthChangeReason.unknown;
  }

  // ── 内部：心跳发送 ──

  void _checkAndSend() {
    if (_lastCommunicationTime == null ||
        DateTime.now().difference(_lastCommunicationTime!) > idleThreshold) {
      _sendHeartbeat();
    }
  }

  Future<void> _sendHeartbeat() async {
    _lastHeartbeatSent = DateTime.now();
    _emitState();

    try {
      final result = await onSendHeartbeat();
      if (result.success) {
        _lastHeartbeatOk = DateTime.now();
        _hbFailCount = 0;
        _lastRtt = result.rtt;
        if (result.klippyConnected != null) {
          _klippyConnected = result.klippyConnected!;
        }
      } else {
        _hbFailCount++;
      }
      _evaluateHealth(
        result.success ? HealthChangeReason.restored : HealthChangeReason.heartbeatTimeout3x,
      );
    } catch (_) {
      _hbFailCount++;
      _evaluateHealth(HealthChangeReason.heartbeatTimeout3x);
    }

    // 心跳本身算通信，重置空闲计时
    _lastCommunicationTime = DateTime.now();
    _emitState();
  }

  // ── 内部：健康评估（来自 DeviceHealthMonitor） ──

  void _evaluateHealth(HealthChangeReason trigger) {
    DeviceHealth newHealth;
    HealthChangeReason reason = trigger;

    if (!_mqttAlive) {
      // Last Will 触发 → 确定离线
      newHealth = DeviceHealth.unreachable;
      reason = HealthChangeReason.mqttDisconnected;
    } else if (_hbFailCount >= maxHeartbeatFailures && _hbFailCount > 0) {
      // MQTT 存活但心跳持续失败 → 僵尸进程
      newHealth = _lastHeartbeatOk != null
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
      _healthController.add(HealthChangeEvent(
        health: _health,
        reason: reason,
        detail: _healthDetail(),
      ));
    }
  }

  String? _healthDetail() {
    return switch (_health) {
      DeviceHealth.healthy => null,
      DeviceHealth.degraded => 'hbFails=$_hbFailCount/$maxHeartbeatFailures '
          'klippy=${_klippyConnected ? "ok" : "disconnected"} '
          'rtt=${_lastRtt?.inMilliseconds ?? "?"}ms',
      DeviceHealth.unreachable => _mqttAlive
          ? 'zombie (MQTT alive but no response)'
          : 'mqtt disconnected',
    };
  }

  // ── 内部：状态发射 ──

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(currentState);
    }
  }
}

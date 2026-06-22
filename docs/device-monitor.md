# 设备监控模块

> 从 `lava-device-controll` SDK 迁移的连接元数据与事件搜集系统。

## 目录结构

```
lib/features/device_monitor/
├── models/                              ← 纯 Dart 数据模型（无 Flutter 依赖）
│   ├── connection_phase.dart            ConnectionPhase 枚举 (6 状态) + ConnectionEvent
│   ├── connection_config.dart           ConnectionConfig (LAN/WAN 配置)
│   ├── heartbeat_state.dart             HeartbeatState (心跳状态)
│   ├── link_quality.dart                LinkQuality 枚举 + LinkQualityEvent
│   ├── metrics_event.dart               MetricsEventType (13 种) + MetricsEvent
│   └── metrics_snapshot.dart            MetricsSnapshot + ConnectionMetrics 收集器
├── data/
│   └── mock_device_monitor.dart         ChangeNotifier 模拟设备连接行为
└── presentation/
    └── device_monitor_page.dart         Flutter 监控展示页
```

## 架构

```
┌──────────────────────────────────────────────┐
│              DeviceMonitorPage               │  ← Flutter UI
│  连接状态卡 │ 指标行 │ 质量延迟 │ 事件时间线    │
└──────────────────┬───────────────────────────┘
                   │ listen() + eventStream
┌──────────────────▼───────────────────────────┐
│            MockDeviceMonitor                 │  ← ChangeNotifier
│  Timer 驱动的模拟事件流                        │
│  连接生命周期 │ 心跳 95% │ PUBACK 40-190ms     │
└──────────────────┬───────────────────────────┘
                   │ record*()
┌──────────────────▼───────────────────────────┐
│           ConnectionMetrics                  │  ← 事件收集器
│  聚合计数器 + 2000 条环形缓冲事件时间线         │
│  滑动窗口延迟采样 (P50/P95/P99)                │
└──────────────────────────────────────────────┘
```

## 数据模型

### ConnectionPhase（6 状态连接状态机）

```
disconnected ──→ connecting ──→ authorizing ──→ authorized ──→ connected
                                              ↘ failed ←──────────┘
```

| 状态 | 含义 | UI 颜色 |
|------|------|---------|
| `disconnected` | 未连接 | 灰色 |
| `connecting` | TCP/TLS 握手 | 橙色 |
| `authorizing` | 等待设备授权 | 橙色 |
| `authorized` | 授权成功，订阅中 | 橙色 |
| `connected` | 全部就绪 | 绿色 |
| `failed` | 连接/授权失败 | 红色 |

### MetricsEventType（13 种事件）

| 事件 | 说明 |
|------|------|
| `connectAttempt` | 连接尝试 |
| `connectSuccess` | 连接成功 |
| `connectFailure` | 连接失败 |
| `disconnect` | 断开连接 |
| `reconnectAttempt` / `reconnectSuccess` / `reconnectFailure` | 重连相关 |
| `maxBackoffReached` | 退避达到最大值 |
| `qualityChange` | 链路质量变化 |
| `timeoutExtension` | 超时自动延长 |
| `heartbeatFailure` | 心跳失败 |
| `commandTimeout` | 命令超时 |
| `latencySample` | 延迟采样（含 link 标识） |

### MetricsSnapshot（聚合快照）

每次调用 `ConnectionMetrics.snapshot()` 生成的不可变快照，包含：
- **计数器**: 连接/重连/断开/心跳/命令/消息 各项计数
- **成功率**: 可用率、连接成功率、命令成功率、心跳成功率
- **延迟**: PUBACK P50/P95/P99、RTT P50/P95/P99
- **质量**: 当前链路质量 + 退化/恢复次数 + 各质量时长分布
- **事件时间线**: 完整的 MetricsEvent 列表

## PUBACK 与 RTT

### 网络拓扑

```
App ──── Link A ──── MQTT Broker ──── Link B ──── 设备 Moonraker
      (本地网络)                      (设备网络)
```

### PUBACK — Link A 延迟

**定义**: MQTT QoS 1 协议中，App 发送消息后收到 Broker 确认的往返时间。

```
App ── PUBLISH ──▶ Broker
App ◀── PUBACK  ── Broker
     |←── 延迟 ──→|
```

- **测量范围**: 仅 App ↔ Broker 段
- **LAN 正常值**: < 50ms
- **WAN 正常值**: < 200ms
- **代表**: 本地网络质量

### RTT — 全路径延迟

**定义**: 心跳请求从 App 到设备 Moonraker 再返回的完整往返时间。

```
App ──▶ Broker ──▶ 设备 ──▶ Moonraker ──▶ 设备 ──▶ Broker ──▶ App
|←──────────────────────── RTT ─────────────────────────────→|
```

- **测量范围**: 整条链路 + Moonraker 处理
- **正常值**: 80-480ms
- **代表**: 端到端质量

### RTT - PUBACK ≈ Link B（设备侧延迟）

不需要在设备端装探针即可拆出设备侧链路质量：

```
RTT      = Link A + Link B + Moonraker
PUBACK   = Link A
─────────────────────────────────
差值      ≈ Link B + Moonraker  ← 设备侧质量
```

**3 种典型故障诊断**:

| 场景 | PUBACK | RTT | 差值 | 根因 |
|------|--------|-----|------|------|
| App WiFi 差 | 高 (>2s) | 高 (>2s) | 正常 | 本地网络 |
| 设备 4G 差 | 正常 (<200ms) | 高 (>3s) | 高 (>3s) | **设备侧网络（PUBACK 正常是关键盲区）** |
| Klipper 卡死 | 正常 | 超时 | N/A | 设备进程 |

### 百分位延迟（P50/P95/P99）

取排序后滑动窗口的百分位值，而非算术平均：

- **P50**（中位数）: 50% 的请求延迟 ≤ 此值
- **P95**: 95% 的请求延迟 ≤ 此值（常用 SLA 指标）
- **P99**: 99% 的请求延迟 ≤ 此值（尾部延迟）

## Mock 数据行为

`MockDeviceMonitor` 模拟完整设备连接生命周期：

| 行为 | 频率 | 参数 |
|------|------|------|
| 连接握手 | 启动后 1 次 | disconnected → connecting(0s) → authorizing(1s) → authorized(1.8s) → connected(2.4s) |
| 心跳 | 每 10s | 95% 成功率，RTT 80-480ms |
| 消息收发 | 每 2s | 各 +1，含 PUBACK 延迟 40-190ms |
| 命令执行 | 30% 概率 | 92% 成功率，失败时 50% 概率标记超时 |
| 质量波动 | 15% 概率 | 随机切换 good/degraded/poor |

### 延迟滑动窗口

- PUBACK 滑动窗口: 200 条（按每 2s 一条 ≈ 6.6 分钟窗口）
- RTT 滑动窗口: 200 条（按每 10s 一条 ≈ 33 分钟窗口）
- 事件时间线: 2000 条环形缓冲

## 接入真实数据

将 `MockDeviceMonitor` 替换为真实连接：

```dart
// 1. 连接真实设备后，创建 ConnectionMetrics 实例
final metrics = ConnectionMetrics();

// 2. 记录事件
metrics.recordConnectAttempt();
// ... MQTT 连接成功后:
metrics.recordConnectSuccess();

// 3. 在 MQTT publish 回调中记录 PUBACK:
mqtt.onPublished = (msg) {
  final delay = DateTime.now().difference(msg.sentTime);
  metrics.recordPubAckDelay(delay);
};

// 4. 心跳回调:
heartbeat.onResult = (success, rtt) {
  metrics.recordHeartbeat(success, rtt: rtt);
};

// 5. 导出诊断:
void onError() {
  final snap = metrics.snapshot();
  File('crash_metrics.json').writeAsStringSync(snap.toJsonString());
}
```

## 路由

```
/device-monitor → DeviceMonitorPage
```

顶栏标签: `[首页] [预览] [设备控制] [监控]`

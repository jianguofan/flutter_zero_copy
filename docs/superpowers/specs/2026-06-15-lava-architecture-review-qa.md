# ARCHITECTURE.md 审查 Q&A 补充

> 对抗审查结论确认后的答疑记录
>
> 日期: 2026-06-15
> 关联: `2026-06-15-lava-architecture-review.md`

---

## Q1: 连接状态机有哪些状态？各自含义是什么？

原文档只有 3 个连接状态（`connectedOnline` / `connectedOffline` / `disconnected`），缺少所有过渡态和弱网态。修正后为 8 个状态:

| # | 状态 | 含义 | 用户可见表现 |
|---|------|------|-------------|
| 1 | **idle** | 无激活设备，无任何连接 | "未连接任何设备" 空白页 |
| 2 | **connecting** | TCP/TLS 传输层握手进行中 | "正在连接..." spinner |
| 3 | **handshaking** | 传输层已通，正做协议层握手（MQTT CONNECT / auth） | "正在认证..." |
| 4 | **reconnecting** | 断线后自动重连，指数退避计时中 | "正在重连(第3次)..." + 倒计时 |
| 5 | **connected** | 传输层+协议握手全部完成，心跳正常（RTT < 阈值） | 绿色连接图标，数据正常刷新 |
| 6 | **degraded** | 连接未断但心跳延迟超过阈值（弱网/高延迟） | 黄色警告图标 "网络不稳定" |
| 7 | **disconnected** | 连接已断开（主动断开 / App 进后台 / 心跳长时间无响应） | "已断开" 提示 + 自动重连倒计时 |
| 8 | **failed** | 不可恢复错误（认证失败 / 协议不支持 / 超过最大重试次数） | 红色错误提示 + 手动重试按钮 |

### 状态迁移图

```
idle ──(activate)──→ connecting ──(TCP ok)──→ handshaking ──(auth ok)──→ connected
       ↑                   │                       │
       │                   └──(timeout)──────────→ failed
       │
connected ──(心跳超时 × N 次)──→ degraded ──(心跳恢复)──→ connected
    │                         │
    │                         └──(心跳超时 × M 次)──→ disconnected
    │
    └──(App 进入后台)──→ disconnected

disconnected ──(自动重连触发)──→ reconnecting ──→ connecting ──→ ...
reconnecting ──(超过最大重试次数)──→ failed

failed ──(用户点击重试按钮)──→ connecting
```

### 重连策略

| 场景 | 初始退避 | 最大退避 | 退避倍率 | 最大重试 |
|------|---------|---------|---------|---------|
| LAN 重连 | 500ms | 10s | ×1.5 | 5 次 |
| WAN 重连 | 2s | 60s | ×1.5 | 10 次 |
| 低电量模式 | — | — | — | 暂停自动重连 |

每次退避加随机抖动（±15%）避免雷鸣效应。

---

## Q2: 注册/连接的关系是怎样的？修正后如何分工？

### 原文档的问题

原文档中 `IDeviceRegistry` 和 `IDeviceConnection` 都暴露了 `activeDevice`：

```dart
// IDeviceRegistry (行 1495)
DeviceInfo? get activeDevice;          // 元数据
Stream<DeviceInfo?> get activeDeviceStream;
void activate(String id);              // 标记激活

// IDeviceConnection (行 1594)
Device? get activeDevice;              // 运行时实例
Stream<Device?> get activeDeviceStream;
```

`activate(id)` → `activeDeviceStream` 变化 → Provider 的 `ref.listen` 回调触发 `connect(info)` → 这个副作用链被隐藏在 UI 层的 Provider 定义中，调用方不知道 `activate` 只做了"标记+持久化"，真正的连接是 Provider 做的。

这导致：
- 谁拥有完整的"设备激活"状态机？没有人
- `activate` 后连接失败了怎么办？没有显式处理
- 快速切换设备时竞态条件难以调试
- 测试时需要 mock 整个 Provider 链路

### 修正方案: 三分天下 + Mediator

将 "Registry 有 activeDevice" 和 "Connection 有 activeDevice" 两个越权行为都收回。新引入 `IDeviceSession` 作为唯一拥有 "当前激活设备" 概念的组件：

```
┌─────────────────────────────────────────────────────────┐
│ IDeviceRegistry                                         │
│ 职责: 设备列表的持久化 CRUD                              │
│ 不再拥有: activeDevice / activate()                     │
│                                                         │
│ + devices: List<DeviceInfo>                             │
│ + devicesStream: Stream<List<DeviceInfo>>               │
│ + register(DeviceInfo)                                  │
│ + unregister(String id)                                 │
│ + lookup(String id): DeviceInfo?                        │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ IDeviceConnection                                       │
│ 职责: 连接生命周期管理（工厂+实例管理）                    │
│ 不再拥有: activeDevice                                  │
│                                                         │
│ + connect(DeviceInfo): Future<Device>                   │
│ + disconnect(String id): Future<void>                   │
│ + deviceById(String id): Device?                        │
│ + connectionState(String id): Stream<ConnectionStatus>  │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ IDeviceSession (新增 Mediator)                           │
│ 职责: 编排注册表和连接管理器，拥有完整状态机               │
│                                                         │
│ + state: DeviceSessionState  ← sealed class             │
│ + stateStream: Stream<DeviceSessionState>               │
│ + activate(String id): Future<void>   ← 原子操作         │
│ + deactivate(): Future<void>                            │
│ + activeDevice: Device?              ← 统一真相源        │
│ + activeDeviceInfo: DeviceInfo?                         │
└─────────────────────────────────────────────────────────┘
```

### 关键变化

1. **两个接口的 `activeDevice` 全部移除**：Registry 只管列表，Connection 只管连接，都不关心"当前是哪个"
2. **`IDeviceSession` 是唯一的真相源**：所有关于"当前激活设备"的问题只问它
3. **状态机显式化**：

```dart
sealed class DeviceSessionState {}
class DeviceSessionIdle extends DeviceSessionState {}
class DeviceSessionActivating extends DeviceSessionState {
  final DeviceInfo info;
}
class DeviceSessionActive extends DeviceSessionState {
  final IDeviceFacade device;
}
class DeviceSessionError extends DeviceSessionState {
  final DeviceInfo info;
  final Object error;
}
```

4. **UI 层极简化**：不再需要协调两个 Provider，只需 `ref.watch(deviceSessionProvider).state.when(...)` 穷举所有状态

5. **测试友好**：`DeviceSessionImpl` 接受 mock 的 `IDeviceRegistry` + `IDeviceConnection`，状态迁移可纯逻辑验证

---

## Q3: LAN 模式也要用 MQTT（不是 WebSocket）

### 背景

原审查报告基于 Moonraker 官方文档建议 "LAN 场景优先 WebSocket，延迟更低"。但实际项目中的设备固件**仅有 MQTT，没有 WebSocket**。该建议无效，已从 spec 中撤回。

### 实际情况

设备端的通信能力：
- **Moonraker 设备**: 固件仅暴露 MQTT Broker（通过 Moonraker 的 `[mqtt]` 配置）
- **WCP/Orca 设备**: 固件暴露 WebSocket
- **当前没有设备同时支持两种传输层**

### 修正后的连接矩阵

| Protocol | Network | Transport | 具体实现 | 用途 |
|----------|---------|-----------|---------|------|
| moonraker | **LAN** | **MQTT** | `MqttConnection(设备IP, 1883, noTLS)` | LAN 直连 Moonraker 设备 |
| moonraker | **WAN** | **MQTT** | `MqttConnection(云端Broker, 8883, TLS)` | WAN 穿透连接 Moonraker |
| wcp | LAN | WebSocket | `WsConnection(ws://设备IP:端口/wcp)` | LAN 直连 Orca 设备 |
| wcp | WAN | WebSocket | `WsConnection(wss://网关/sn)` | 云端连接 Orca 设备 |

### 架构上的处理

当前的 `IConnection` 接口和 `ConnectionFactory` 工厂链完全不受影响——MQTT 和 WebSocket 只是 `IConnection` 的两种实现，工厂链按 `DeviceInfo.protocol` 自动分发：

```dart
// Moonraker 设备 → MqttConnectionFactory.canHandle() 返回 true → 创建 MqttConnection
// WCP 设备     → WsConnectionFactory.canHandle() 返回 true  → 创建 WsConnection
```

### 如果未来需要 LAN WebSocket

当设备固件增加了 Moonraker WebSocket 支持后，只需：

1. 新建 `WsMoonrakerConnection implements IConnection`（约 50 行）
2. 在 `ConnectionFactoryRegistry` 中注册 `WsMoonrakerConnectionFactory`
3. 调整 `canHandle()` 的匹配逻辑（例如增加 `DeviceInfo.preferredTransport` 字段让用户选择）

其他所有代码（Device、DeviceConnectionImpl、Provider、UI）**零修改**。

### 当前 MQTT LAN 的注意事项

LAN 模式下设备自身作为 MQTT Broker（行 1381），需要确认：
- 设备固件内部运行的 MQTT Broker 资源开销（RAM/CPU）是否可接受
- MQTT Broker 的并发连接数限制（如果未来群控，多台手机同时连一台设备）
- LAN MQTT 的 QoS 建议设置为 QoS 1（至少一次送达），避免丢消息

---

## Q4: 与原文档的核心差异总览

| 维度 | 原 ARCHITECTURE.md | 修正后 |
|------|-------------------|--------|
| 架构支柱 | BFF + 垂直切片 + Clean Architecture（三重标签） | 垂直切片 + Clean Architecture + 适配器模式 + Riverpod |
| BFF 定位 | 顶层架构支柱 | Data 层内部描述性术语 |
| Device 设计 | 两套互不引用、互相矛盾的设计（§2/§9 vs §10） | 统一为 IConnection+IProtocol+Device 骨架，LavaDeviceAdapter 下沉为可选 IConnection 实现 |
| Device 对外暴露 | 具体类 `Device?` 直接暴露给 UI 层 | `IDeviceFacade?` 只读接口，实现细节对 UI 不可见 |
| 注册/连接关系 | 隐式副作用链 + Registry 和 Connection 双重暴露 activeDevice | 引入 IDeviceSession Mediator，Sealed Class 穷举状态机，两个接口各自收回越权职责 |
| 连接状态 | 3 态（connectedOnline/connectedOffline/disconnected） | 8 态（idle/connecting/handshaking/reconnecting/connected/degraded/disconnected/failed） |
| 后台策略 | "保持连接（心跳继续）" | 主动断开 + 状态持久化 + 前台自动恢复；打印中通知设备继续执行 |
| Moonraker 传输层 | 仅 MQTT | 全部走 MQTT（与设备实际能力一致）；WebSocket 仅用于 WCP 设备 |
| 连接工厂扩展 | 硬编码 switch/case（违反开闭原则） | 工厂链 + DI 注册，添加新协议只需新建 2 个类 + 注册 2 行 |
| seqId 并发 | 无保护的 Completer Map | Lock + _safeComplete + 原子 _PendingCommand 结构 |
| Stream 背压 | 无任何处理 | 4 种策略（throttle/debounce/frameAligned/none），按字段类型配置，支持低电量动态切换 |
| Provider 响应 | `ref.watch(provider).getter` 不触发 UI 重建 | 不可变值对象 + StreamProvider |
| 实施路线 | 5 周 | 18 周（MVP 8 周，1-2 开发者） |
| 代码可编译 | 5 处编译错误 | 全部修正（依赖清单已给出） |
| 认证/授权 | 缺失整章 | 需新增（OAuth/JWT 流程、Token 刷新、路由守卫） |
| 错误处理策略 | 缺失（仅有 `catch(e){/* 静默失败 */}`） | 需新增（重试/降级/用户提示/致命 vs 可恢复分类） |
| 移动端约束 | 忽略 iOS 后台限制 | 完整平台适配（iOS Suspend / Android Doze） |

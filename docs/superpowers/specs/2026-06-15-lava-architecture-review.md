# ARCHITECTURE.md 对抗审查报告与修正 Spec

> 对 `/Users/jgfan/code/lava_app/lava-app/ARCHITECTURE.md` 的全量循环对抗审查
>
> 方法论: **方案 B — 4 视角并行审查 + 交叉验证 + 深度修正**
>
> 审查日期: 2026-06-15

---

## 执行摘要

对 Lava App 企业级 Flutter 架构文档（2,607 行）进行了 4 视角独立审查（新人/实施者/审稿人/架构师），交叉验证后确认 **7 个阻塞级问题、12 个重要级问题、6 个建议级问题**。四个问题组（代码可行性/架构矛盾/移动端现实/工程落地）已全部产出修正方案。

核心结论: **文档的架构思想（IConnection×IProtocol 正交设计、垂直切片 + Clean Architecture）是扎实的，但实现层存在编译错误、架构矛盾、移动端约束忽视等问题。修正后是一份可用的生产级架构方案。**

---

## 一、审查统计

| 严重程度 | 数量 | 4 人一致 | 3 人一致 | 2 人一致 |
|----------|------|---------|---------|---------|
| 🔴 阻塞 | 7 | 2 | 3 | 2 |
| 🟡 重要 | 12 | 2 | 4 | 6 |
| 🟢 建议 | 6 | 1 | 3 | 2 |
| **合计** | **25** | **5** | **10** | **10** |

---

## 二、阻塞级问题与修正方案（7 项）

### B1: 全局章节编号系统错位

**问题**: 目录编号 1-16，正文子标题用 2.x/3.x/4.x（偏移-1），§6 内部混入 6.4
**修正**: 全文档统一为目录编号体系。§3 子标题改为 3.1-3.2，§4 改为 4.1-4.2，以此类推。§6 内部统一为 6.4

### B2: 两套 Device Feature 设计矛盾

**问题**: §2/§9 基于 LavaDeviceAdapter 的方案 A vs §10 基于 IConnection+IProtocol+Device 的方案 B，互相无引用，§10 标注"完全重写版"但未声明替代关系

**修正**: 方案 B 为权威方案。方案 A 的 LavaDeviceAdapter 下沉为 `IConnection` 的一个可选实现，仅用于 Moonraker/MQTT 路径。架构关系:
```
  Device (核心运行时) ─→ IConnection ─→ MqttConnection / WsConnection / LavaDeviceAdapter
                     ─→ IProtocol  ─→ MoonrakerProtocol / WcpProtocol
```

### B3: 代码示例多处无法编译

**问题与修正**:

| 子问题 | 根因 | 修正 |
|--------|------|------|
| `BehaviorStreamController` 不存在 | 虚构 API | 使用 `rxdart` 的 `BehaviorSubject<T>.seeded(initialValue)` |
| `SharedPreferences.getString()` 静态调用 | 缺少异步初始化 | 改用 `DeviceRegistryImpl.create()` 静态工厂 + `SharedPreferences.getInstance()` |
| `d.lastSeen = DateTime.now()` 对 final 赋值 | 值对象可变性矛盾 | 添加 `DeviceInfo.copyWith()`，用新实例替换旧实例 |
| `ref.listen()` 在 `build()` 中 | Riverpod 反模式 | 将副作用逻辑移到独立 Provider 或内部状态标志 |
| `ref.watch(provider).getter` 不触发重建 | Riverpod 引用相等检测 | 将状态建模为不可变值对象，每次变化产生新引用 |

**新增依赖**:
```yaml
dependencies:
  rxdart: ^0.27.7
  shared_preferences: ^2.2.0
  freezed_annotation: ^2.4.1
  synchronized: ^3.1.0

dev_dependencies:
  freezed: ^2.4.1
  build_runner: ^2.4.0
```

### B4: Device 聚合根被埋入 Data 层

**问题**: Device 类声明为"Data 层内部类"但 Provider 直接暴露给 UI，违反 Clean Architecture

**修正**: 三层分离:
- **Domain 层**: 新增 `IDeviceFacade`（对 UI 的只读抽象）、`IDeviceCommandService`（命令发送）
- **Data 层**: `DeviceImpl implements IDeviceFacade`（内部实现，封装 IConnection/IProtocol/心跳/seqId）
- **Provider 层**: 仅暴露 `IDeviceFacade?` 而非具体 `Device?`

### B5: iOS 后台连接策略不可行

**问题**: 文档声称"保持连接（心跳继续）"，iOS 约 30 秒即被系统挂起

**修正**: 
- **后台策略**: 非打印中 → 主动断开+持久化状态；打印中 → 通知设备继续执行 G-code → 主动断开
- **前台恢复**: 读持久化 activeDeviceId → 自动重连 → `queryFullState()` 拉取最新状态
- **新增连接状态**: `idle → connecting → handshaking → connected → degraded → disconnected → reconnecting → failed`
- **自动重连**: 指数退避 (1s→30s, ×1.5, 加随机抖动)，LAN 和 WAN 不同策略

### B6: Mermaid 图表嵌套代码块格式错误

**问题**: 行 1909-1959 和行 1963-1998 的 Mermaid 代码块被包裹在多余的 ````` 中，渲染器无法显示
**修正**: 移除多余的 markdown 代码块包裹，保留纯 Mermaid 代码块

### B7: 单设备→多设备群控演进路径不可行

**问题**: `activate()` 语义从"替换"变"追加"是 breaking change，Provider 返回单数不支持多设备
**修正**: 采用 Facade 模式——现有单设备接口**零修改**，新增独立群控层 `DeviceGroup` + `GroupCommandExecutor`，支持三种事务策略（waitAll / failFast / bestEffort）

---

## 三、重要级问题与修正方案（12 项）

### I1: BFF 标签过度化

**修正**: BFF 降级为 Data 层描述性术语。架构支柱重新定义为:
> 垂直切片 + Clean Architecture 依赖反转 + 适配器模式 + Riverpod 响应式状态管理

### I2: 5 周路线图重估

**修正**: 18 周（~4.5 个月）实际计划:

| Phase | 内容 | 时间 |
|-------|------|------|
| Phase 1 | 核心基础设施 + Device Feature | 8 周 |
| Phase 2 | Auth/Project/Discover/Ticket | 6 周 |
| Phase 3 | 性能优化 + 测试 + CI/CD + 上线 | 4 周 |

**MVP** (1-2 开发者): 8 周 — Shared Kernel + Device(Moonraker/LAN单设备) + Auth(用户名密码) + 两个页面 + 基础 CI

### I3: DeviceRepositoryImpl 重复 3 次

**修正**: 保留 §2.5 版本为权威实现（3 个数据源），§4.3 和 §2.7 从简引用

### I4: 缺失认证/授权章节

**修正**: 新增完整 Auth Feature 章节，覆盖: OAuth/JWT 认证流程、Token 刷新+安全存储、路由守卫、授权模型（RBAC）

### I5: 缺失错误处理策略

**修正**: 新增错误处理章节，覆盖:
- 网络异常: 重试策略（指数退避 + 最大次数）、降级 UI、用户提示
- MQTT 断连: 自动重连 + 状态通知
- Provider 错误传播: `AsyncValue.error` + `ref.invalidate`
- 致命错误 vs 可恢复错误的分类体系

### I6: IDeviceRegistry/IDeviceConnection 职责边界模糊

**修正**: 保持接口分离，引入 `IDeviceSession` Mediator:
- `IDeviceRegistry`: 纯设备 CRUD（移除 activeDevice 概念）
- `IDeviceConnection`: 纯连接工厂 + 生命周期（移除 activeDevice 概念）
- `IDeviceSession`: 新引入的 Mediator，统一管理"激活→连接→状态"的完整状态机

```dart
sealed class DeviceSessionState {}
class DeviceSessionIdle extends DeviceSessionState {}
class DeviceSessionActivating extends DeviceSessionState { DeviceInfo info; }
class DeviceSessionActive extends DeviceSessionState { IDeviceFacade device; }
class DeviceSessionError extends DeviceSessionState { DeviceInfo info; Object error; }
```

### I7: seqId+Completer 存在 race condition

**修正**: 引入 `Lock`（synchronized 包）+ `_isClosed` 标志 + `_safeComplete()` / `_safeCompleteError()` 包装方法。将 `Completer` 和 `Timer` 绑定为 `_PendingCommand` 原子单元。

### I8: Riverpod vs Bloc 对比不客观

**修正**: 补充 Bloc 在设备状态机场景的优势分析。建议核心设备控制模块可选择性使用 Bloc，简单 CRUD 模块使用 Riverpod。

### I9: 3 处目录结构互不一致

**修正**: 统一为 §10.10 的结构（以 IConnection+IProtocol+Device 为权威骨架），§5 模板和 §11 全局目录保持一致。明确标注 `lib/shared/device/` 路径。

### I10: Moonraker-over-MQTT 组合

**确认: Moonraker 原生支持 MQTT**（通过 `[mqtt]` 配置节）。

> **⛔ 审查勘误**: 原审查建议 "LAN 场景优先 WebSocket"，但项目实际设备端**仅有 MQTT，没有 WebSocket**。该建议无效，已撤回。

**修正后的连接矩阵（按实际设备能力）**:

| Protocol | Network | Transport | 实现 | 用途 |
|----------|---------|-----------|------|------|
| moonraker | **lan** | **mqtt** | MqttConnection(设备IP, 1883, noTLS) | LAN 直连 Moonraker |
| moonraker | **wan** | **mqtt** | MqttConnection(云端Broker, 8883, TLS) | WAN 穿透 Moonraker |
| wcp | lan | ws | WsConnection(ws://设备IP/wcp) | LAN 直连 Orca |
| wcp | wan | ws | WsConnection(wss://网关/sn) | 云端连接 Orca |

**注意**: WebSocket 仅用于 WCP 协议设备（Orca）。Moonraker 设备 LAN 和 WAN 均走 MQTT。后续如果 Moonraker 设备固件增加了 WebSocket，只需实现 `WsMoonrakerConnection implements IConnection` 然后注册到工厂链即可，不修改任何现有代码。

### I11: 硬编码工厂违反开闭原则

**修正**: 引入 **工厂链（Chain of Responsibility）** 模式:

```dart
abstract class ConnectionFactory {
  bool canHandle(DeviceInfo info);
  IConnection create(DeviceInfo info);
}

abstract class ProtocolFactory {
  bool canHandle(DeviceInfo info);
  IProtocol create(DeviceInfo info);
}
```

添加新协议（如 gRPC）只需: 新建 2 个类 + DI 注册处加 2 行。`DeviceConnectionImpl` 等核心文件**零修改**。

### I12: Stream 背压处理缺失

**修正**: 在 `deviceFieldProvider` 中加入可配置背压策略:

| 策略 | 适用字段 |
|------|---------|
| `throttle(200ms)` | 温度、风扇速度 |
| `throttle(1s)` | 打印进度 |
| `debounce(500ms)` | 最终稳定值 |
| `frameAligned` | 实时曲线、轴位置 |
| `none` | 报警、连接状态 |

支持动态配置切换（低电量模式/高性能模式）。

---

## 四、修正后的核心架构

### 4.1 层级关系（修正后）

```
┌──────────────────────────────────────────┐
│ UI Layer (Presentation)                  │
│ 依赖: IDeviceFacade, IDeviceSession      │
├──────────────────────────────────────────┤
│ Domain Layer (Shared Kernel)             │
│ IDeviceFacade, IDeviceRegistry,          │
│ IDeviceConnection, IDeviceSession,       │
│ IConnection, IProtocol, DeviceInfo       │
├──────────────────────────────────────────┤
│ Data Layer                               │
│ DeviceImpl (implements IDeviceFacade)    │
│ DeviceConnectionImpl, DeviceRegistryImpl │
│ DeviceSessionImpl (Mediator)             │
│ ConnectionFactoryRegistry (工厂链)        │
│ MqttConnection, WsConnection,            │
│ LavaDeviceAdapter (可选 SDK 快捷方式)     │
│ MoonrakerProtocol, WcpProtocol           │
├──────────────────────────────────────────┤
│ Provider Layer (Riverpod)                │
│ 8 个 Provider + 背压配置                  │
│ 暴露: IDeviceFacade? (非 Device?)         │
└──────────────────────────────────────────┘
```

### 4.2 核心接口关系（修正后）

```
IDeviceRegistry     ← 设备列表 CRUD（纯持久化，无 activeDevice）
IDeviceConnection   ← 连接生命周期（纯连接工厂，无 activeDevice）
IDeviceSession      ← 新增 Mediator（拥有 complete 状态机）
  ├── DeviceSessionIdle
  ├── DeviceSessionActivating
  ├── DeviceSessionActive(device: IDeviceFacade)
  └── DeviceSessionError

IDeviceFacade       ← UI 层只读抽象
  ├── info: DeviceInfo
  ├── currentStatus: ConnectionStatus
  ├── statusStream: Stream<ConnectionStatus>
  ├── messageStream: Stream<DeviceMessage>
  └── fieldStream<T>(key): Stream<T>

IConnection         ← 传输层抽象
IProtocol           ← 协议层抽象

DeviceImpl          ← Data 层内部实现（持有 IConnection + IProtocol + 心跳 + seqId）
```

### 4.3 连接生命周期（修正后）

```
idle ──(activate)──→ connecting ──(TCP ok)──→ handshaking ──(auth ok)──→ connected
                           │                      │
                           └──(timeout)──────────→ failed
                           
connected ──(心跳失败×N)──→ degraded ──(恢复)──→ connected
         │                │
         │                └──(心跳失败×M)──→ disconnected
         │
         └──(App进后台)──→ disconnected

disconnected ──(自动重连)──→ reconnecting ──→ connecting ──→ ...
reconnecting ──(超过最大重试)──→ failed

failed ──(用户手动重试)──→ connecting
```

- LAN 重连: 500ms 起点, ×1.5 退避, 最大 10s, 最多 5 次
- WAN 重连: 2s 起点, ×1.5 退避, 最大 60s, 最多 10 次
- 低电量模式: 暂停自动重连

---

## 五、修正后的实施路线图

### 总体时间线

| Phase | 内容 | 时间 | 累计 |
|-------|------|------|------|
| Phase 1 | 核心基础设施 + Device Feature | 8 周 | 8 周 |
| Phase 2 | Auth/Project/Discover/Ticket | 6 周 | 14 周 |
| Phase 3 | 性能优化 + 测试 + CI/CD + 上线 | 4 周 | 18 周 |
| **总计** | | **18 周 (~4.5 月)** | |

### Phase 1 里程碑

| M# | 交付物 | 时间 |
|----|--------|------|
| 1.1 | Shared Kernel (DI/Router/Http/Storage/Logger/Config/Theme/EventBus) | 1.5 周 |
| 1.2 | Shared Kernel 测试 (>80%) | 0.5 周 |
| 1.3 | Device Domain 层 (IDeviceFacade/IDeviceSession/IConnection/IProtocol…) | 1 周 |
| 1.4 | Device Domain 测试 (100%) | 0.5 周 |
| 1.5 | Device Data 层 — 连接 (MqttConnection/WsConnection/Protocol/Device) | 1.5 周 |
| 1.6 | Device Data 层 — 适配器+持久化 (DeviceRegistryImpl/DeviceConnectionImpl/DeviceSessionImpl) | 1 周 |
| 1.7 | Device Data 层测试 (>70%) | 0.5 周 |
| 1.8 | Device Application 层 (8 Providers + 背压配置) | 1 周 |
| 1.9 | Device Application 层测试 (>80%) | 0.5 周 |
| 1.10 | Device Presentation 层 (4 Pages + Widgets) | 1 周 |

### MVP (1-2 开发者, 8 周)

- ✅ Shared Kernel
- ✅ Device Feature (Moonraker/LAN 单设备)
- ✅ Auth Feature (用户名密码)
- ✅ Device List Page + Device Detail Page
- ✅ 基础 CI (lint + test)
- ❌ WCP/WAN/Discover/Ticket/性能优化/E2E/群控

### Phase 2-3 详见完整分析报告

---

## 六、新增依赖清单

```yaml
dependencies:
  rxdart: ^0.27.7              # BehaviorSubject 替代虚构的 BehaviorStreamController
  shared_preferences: ^2.2.0   # 本地持久化
  freezed_annotation: ^2.4.1   # 不可变数据类
  synchronized: ^3.1.0         # seqId+Completer 并发保护
  connectivity_plus: ^6.0.0    # 网络变化监听

dev_dependencies:
  freezed: ^2.4.1
  build_runner: ^2.4.0
  riverpod_generator: ^2.4.0
  json_serializable: ^6.7.0

# 可选（Bloc 共存方案）
# flutter_bloc: ^8.1.0
```

---

## 七、与原文档的差异总结

| 维度 | 原 ARCHITECTURE.md | 修正后 |
|------|-------------------|--------|
| 架构支柱 | BFF + 垂直切片 + Clean Architecture（三重标签） | 垂直切片 + Clean Architecture + 适配器模式 + Riverpod |
| BFF 定位 | 顶层架构支柱 | Data 层内部描述性术语 |
| Device 设计 | 两套矛盾方案 | 统一为 IConnection+IProtocol+Device |
| Device 对外暴露 | `Device?` 直接暴露 | `IDeviceFacade?` 接口 |
| 注册/连接 | 隐式副作用链 + 双重 activeDevice | IDeviceSession Mediator + 显式状态机 |
| 连接状态 | 3 态（online/offline/disconnected） | 8 态（含 connecting/reconnecting/handshaking/degraded） |
| 后台策略 | "保持连接（心跳继续）" | 主动断开 + 持久化 + 前台自动恢复 |
| Moonraker 传输 | 仅 MQTT | Moonraker 全部走 MQTT（设备端无 WebSocket）；WCP 走 WebSocket |
| 工厂扩展 | 硬编码 switch | 工厂链 + DI 注册，开闭原则 |
| seqId 并发 | 无保护的 Completer Map | Lock + _safeComplete + _PendingCommand 原子单元 |
| Stream 背压 | 无 | 4 种策略（throttle/debounce/frameAligned/none），可动态配置 |
| Provider 响应 | `ref.watch().getter` 不触发重建 | 不可变值对象 + `StreamProvider` |
| 实施路线 | 5 周 | 18 周（4.5 月），含 MVP 8 周 |
| 代码可编译 | 5 处编译错误 | 全部修正 |
| 认证/授权 | 缺失 | 新增完整章节 |
| 错误处理 | 缺失（仅有 `catch(e){/*静默*/}`） | 新增完整策略 |
| 移动端约束 | 忽略 iOS 后台限制 | 包含完整平台适配 |
| 跨平台差异 | 未讨论 | 新增 Web/桌面端讨论（MQTT over WS、FFI 编译） |

---

## 八、后续行动建议

1. **立即执行**: 修正 B1（编号）、B3（编译错误）、B6（Mermaid 格式）——纯文档/代码修正，低风险
2. **Phase 1 前执行**: 修正 B2（统一 Device 设计）、B4（Device 分层）、I6（Session Mediator）、I11（工厂链）——架构重构，影响范围大但可控
3. **Phase 1 中实现**: B5（后台策略）、I7（seqId 并发）、I12（Stream 背压）——与 Device Feature 实施同步进行
4. **Phase 2 前补充**: I4（认证章节）、I5（错误处理）、C++ FFI 绑定代码
5. **持续维护**: 将 Mermaid 序列图按主题拆分（成功路径 + 异常路径分开）
6. **新建文档**: 设备 Schema 版本管理策略、CI/CD 配置指南、术语表

---

> 本报告由 4 视角并行审查（新人/实施者/审稿人/架构师）→ 交叉验证 → 深度分析生成。
> 完整分析（含全部修正代码）见各 Agent 输出。

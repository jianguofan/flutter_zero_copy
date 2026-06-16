# Lava App Architecture Review — Corrected Requirements

> 来源: `/Users/jgfan/code/lava_app/lava-app/ARCHITECTURE.md` 循环对抗审查
> 审查方法: 4 视角并行 (新人/实施者/审稿人/架构师) → 交叉验证 → 深度修正
> 关联文档: `docs/superpowers/specs/2026-06-15-lava-architecture-review.md`

---

## ADDED Requirements

### Requirement: Device 聚合根分层隔离

Device 核心运行时对象 SHALL 通过接口与 UI 层隔离，不得将 Data 层内部实现类直接暴露给 Provider/UI。

#### Scenario: UI 层依赖抽象
- **WHEN** UI 层通过 Riverpod Provider 访问当前活跃设备
- **THEN** Provider 暴露 `IDeviceFacade?` 接口而非具体 `Device?` 类
- **AND** `IDeviceFacade` 定义在 Domain 层，仅暴露只读操作（`statusStream`、`messageStream`、`fieldStream<T>()`）
- **AND** 命令发送通过独立的 `IDeviceCommandService` 接口暴露

#### Scenario: Data 层内部实现
- **WHEN** Device 类需要管理 IConnection、IProtocol、心跳、seqId 匹配等实现细节
- **THEN** `DeviceImpl` 在 Data 层实现 `IDeviceFacade` 接口
- **AND** `DeviceImpl` 不对外导出（通过 `library` 的 `export` 控制可见性）
- **AND** 更换协议实现时 UI 层和 Domain 层不受影响

---

### Requirement: 统一设备通信架构

Device Feature 的通信抽象 SHALL 以 IConnection + IProtocol + Device 为唯一权威骨架，LavaDeviceAdapter 降级为 IConnection 的可选实现。

#### Scenario: 传输层与协议层正交
- **WHEN** 需要支持新的设备协议或传输方式
- **THEN** `IConnection` 接口抽象传输层（open/close/send/messageStream/statusStream）
- **AND** `IProtocol` 接口抽象序列化层（serialize/deserialize）
- **AND** 两者通过工厂链独立注册，支持 N×M 种组合
- **AND** `Device` 类持有 IConnection + IProtocol 完成消息收发和 seqId 匹配

#### Scenario: SDK 适配器作为可选快捷方式
- **WHEN** lava-device-controll SDK 已封装 MQTT 连接和状态管理能力
- **THEN** `LavaDeviceAdapter implements IConnection` 替代手工 `MqttConnection` 用于 Moonraker/MQTT 路径
- **AND** SDK 适配器对上层完全透明——上层只看到 IConnection 接口
- **AND** 如果 SDK 不可用，架构回退到手工 MqttConnection + MoonrakerProtocol 路径

---

### Requirement: 设备会话状态机（IDeviceSession）

设备激活和连接管理 SHALL 通过独立的 IDeviceSession Mediator 编排，取代分散在 IDeviceRegistry 和 IDeviceConnection 中的隐式副作用链。

#### Scenario: 接口职责分离
- **WHEN** 管理设备生命周期
- **THEN** `IDeviceRegistry` 仅负责设备列表 CRUD 和持久化，不暴露 `activeDevice` 概念
- **AND** `IDeviceConnection` 仅负责连接创建/销毁，不暴露 `activeDevice` 概念
- **AND** `IDeviceSession` 作为 Mediator 持有 Registry 和 Connection 引用，统一编排"激活→连接→状态通知"全流程

#### Scenario: 激活是原子操作
- **WHEN** 用户点击激活某设备
- **THEN** `IDeviceSession.activate(id)` 内部执行 lookup → connect → 状态迁移
- **AND** 调用方无需知道内部有"标记激活"和"建立连接"两个步骤
- **AND** 连接失败时自动回退持久化的 activeDeviceId

#### Scenario: 状态机穷举
- **WHEN** UI 层消费设备会话状态
- **THEN** `DeviceSessionState` 使用 Sealed Class 穷举所有状态: Idle / Activating / Active / Error
- **AND** UI 通过 `.when()` 模式匹配强制处理每种状态
- **AND** 新增状态时编译器检查所有调用处

---

### Requirement: 完整连接状态机（8 态）

设备连接状态 SHALL 覆盖从空闲到失败的全部过渡态，原 3 态（online/offline/disconnected）不足以表达真实的移动端连接生命周期。

#### Scenario: 过渡态可见
- **WHEN** 用户发起连接
- **THEN** 状态按 `idle → connecting → handshaking → connected` 迁移
- **AND** UI 在 connecting 阶段显示 spinner
- **AND** UI 在 handshaking 阶段显示认证进度
- **AND** 任何阶段超时则迁移到 `failed`

#### Scenario: 弱网和断连
- **WHEN** 心跳延迟超过阈值但连接未断
- **THEN** 状态迁移到 `degraded`，UI 显示黄色弱网警告
- **WHEN** 心跳连续失败超过 M 次
- **THEN** 状态迁移到 `disconnected`，触发自动重连

#### Scenario: 自动重连
- **WHEN** 连接非用户主动断开
- **THEN** 状态迁移到 `reconnecting`，按指数退避策略重试
- **AND** LAN 重连: 500ms 起点, ×1.5, 最大 10s, 最多 5 次
- **AND** WAN 重连: 2s 起点, ×1.5, 最大 60s, 最多 10 次
- **AND** 超过最大重试次数后迁移到 `failed`, 用户可手动重试

---

### Requirement: 移动端后台正确处理

App 进入后台时 SHALL 主动断开设备连接并持久化状态，而非尝试保持连接（iOS 不允许，Android 不可靠）。

#### Scenario: 非打印中进入后台
- **WHEN** App 进入后台且无活跃打印任务
- **THEN** 主动调用 `connection.close()` 断开 MQTT 连接
- **AND** 持久化 `activeDeviceId` 到 SharedPreferences
- **AND** 取消心跳定时器
- **AND** 在 iOS `beginBackgroundTask` 窗口（~30s）内完成以上步骤

#### Scenario: 打印中进入后台
- **WHEN** App 进入后台且有活跃打印任务
- **THEN** 向设备发送"继续执行已下发 G-code"指令
- **AND** 持久化当前打印状态（jobId、已发 G-code 行号、文件进度）
- **AND** 主动断开连接
- **AND** 发布本地推送通知告知用户打印仍在进行

#### Scenario: 前台恢复
- **WHEN** App 回到前台
- **THEN** 读取持久化的 `activeDeviceId`，自动触发重连
- **AND** 连接成功后调用 `queryFullState()` 拉取最新设备状态
- **AND** 检查是否有未完成的打印任务，恢复监控 UI

---

### Requirement: 连接工厂开闭原则

添加新传输协议或新设备协议 SHALL 通过工厂链注册完成，不修改现有核心代码。

#### Scenario: 工厂链注册
- **WHEN** 系统需要为 DeviceInfo 创建 IConnection 和 IProtocol
- **THEN** `ConnectionFactoryRegistry` 按注册顺序遍历所有 `ConnectionFactory`
- **AND** 首个 `canHandle(DeviceInfo)` 返回 true 的工厂负责创建
- **AND** `ProtocolFactoryRegistry` 同理独立匹配
- **AND** 两个注册表通过 `DeviceConnectionFactory` 组合

#### Scenario: 添加新协议零侵入
- **WHEN** 需要支持新协议（如 gRPC）
- **THEN** 只需: (1) 新建 `GrpcConnectionFactory` + `GrpcConnection` (2) 新建 `GrpcProtocolFactory` + `GrpcProtocol` (3) DI 注册处加 2 行
- **AND** `DeviceConnectionImpl`、`DeviceImpl`、所有现有 Factory 零修改
- **AND** 编译时保证类型安全——所有 Factory 返回 IConnection/IProtocol 接口

---

### Requirement: seqId 请求-响应匹配并发安全

Device 类的 seqId + Completer 匹配机制 SHALL 使用 Lock 保护 `_pendingCompleters` Map 的并发访问，防止竞态。

#### Scenario: timeout 与消息到达互斥
- **WHEN** 命令的 timeout 回调和消息响应近乎同时触发
- **THEN** 两者通过 `Lock.synchronized()` 互斥访问 `_pendingCompleters` Map
- **AND** 先执行者从 Map 中移除 `_PendingCommand` 条目
- **AND** 后执行者发现 entry 为 null 则安全跳过
- **AND** `_safeComplete()` 检查 `completer.isCompleted` 防止双重完成

#### Scenario: close 安全清理
- **WHEN** Device 正在关闭且仍有 pending commands
- **THEN** `close()` 在锁内遍历所有 pending completers
- **AND** 先取消每个 entry 的 timeout Timer（防止 Timer 回调在锁外再次操作 Map）
- **AND** 再调用 `_safeCompleteError()` 完成所有 completer
- **AND** 设置 `_isClosed = true` 阻止新命令注册

---

### Requirement: Stream 背压按字段类型可配置

高频 MQTT 数据流的 UI 绑定 SHALL 支持按字段类型配置背压策略，防止 UI 渲染跟不上消息速率。

#### Scenario: 字段级策略匹配
- **WHEN** Provider 订阅设备字段实时数据
- **THEN** 温度字段使用 `throttle(200ms)`
- **AND** 打印进度字段使用 `throttle(1s)`
- **AND** 风扇速度字段使用 `debounce(500ms)`
- **AND** 轴位置字段使用 `frameAligned`（与帧渲染同步）
- **AND** 报警字段使用 `none`（立即响应）

#### Scenario: 动态策略切换
- **WHEN** 设备电量低或用户切换低功耗模式
- **THEN** `BackpressureConfig` 全局放宽所有 throttle/debounce 窗口
- **AND** 降低 CPU 唤醒频率以省电
- **AND** 切换过程不影响已建立的 Stream 订阅

---

### Requirement: Provider 状态不可变

所有 Riverpod Provider 暴露的状态 SHALL 为不可变值对象，每次变化产生新引用以触发 Riverpod 的引用相等检测。

#### Scenario: Registry 状态触发 UI 重建
- **WHEN** DeviceRegistry 的设备列表或 activeDeviceId 变化
- **THEN** state 赋值为新的 `RegistryState` 实例（通过 `copyWith` 创建）
- **AND** Riverpod 检测到引用变化后通知所有 `ref.watch()` 依赖方
- **AND** 不依赖 `ref.watch(provider).getter` 这种无效监听模式

#### Scenario: build 方法为纯函数
- **WHEN** Riverpod Notifier 的 build() 方法被调用
- **THEN** build() 仅根据输入计算输出，不在内部注册 `ref.listen()` 等副作用
- **AND** 副作用（如连接/断开）通过独立 Provider 或内部状态标志管理
- **AND** build() 多次调用不会导致 listener 泄漏

---

### Requirement: LAN MQTT 连接矩阵（按设备实际能力）

设备连接矩阵 SHALL 基于设备固件实际通信能力选择传输层，当前 Moonraker 设备仅支持 MQTT。

#### Scenario: Moonraker 设备连接
- **WHEN** 连接 Moonraker 协议设备（LAN 或 WAN）
- **THEN** 使用 `MqttConnection`（LAN: 设备IP, 1883, noTLS / WAN: 云端Broker, 8883, TLS）
- **AND** 配合 `MoonrakerProtocol`（JSON-RPC 序列化）

#### Scenario: WCP 设备连接
- **WHEN** 连接 WCP 协议设备
- **THEN** 使用 `WsConnection`（LAN: ws://设备IP/wcp / WAN: wss://网关/sn）
- **AND** 配合 `WcpProtocol`（Binary 序列化）

#### Scenario: 未来扩展
- **WHEN** 设备固件增加新的传输层（如 Moonraker WebSocket）
- **THEN** 仅需实现新的 `IConnection` 子类并注册到工厂链
- **AND** 不影响现有 MQTT 路径

---

## MODIFIED Requirements

### Requirement: 实施路线图（原 §14 5 周 → 修正为 18 周）

<!-- 原 ARCHITECTURE.md §14 的 5 周计划被 4/4 审查者一致认为不现实 -->

#### Scenario: Phase 1 — 核心基础设施 + Device Feature (8 周)
- **WHEN** 开始实施 Lava App 架构
- **THEN** Week 1-2: Shared Kernel（DI/Router/Http/Storage/Logger/Config/Theme/EventBus）
- **AND** Week 2-3: Device Domain 层（接口定义 + 100% 测试覆盖）
- **AND** Week 3-6: Device Data 层（MqttConnection + MoonrakerProtocol + Device + Registry/Connection/Session 实现）
- **AND** Week 6-7: Device Application 层（8 个 Provider + 背压配置 + 80% 测试覆盖）
- **AND** Week 7-8: Device Presentation 层（4 个页面 + Widget 组件）

#### Scenario: MVP (1-2 开发者, 8 周)
- **WHEN** 资源受限需要快速交付
- **THEN** 包含: Shared Kernel + Device(Moonraker/LAN 单设备) + Auth(用户名密码) + List/Detail 页面 + 基础 CI
- **AND** 不包含: WCP/WAN/Discover/Ticket/性能优化/E2E/群控

---

## 术语对照

| 原文档用语 | 修正用语 | 理由 |
|-----------|---------|------|
| BFF 模式 (架构支柱) | Data 层适配策略 (描述性术语) | BFF 与垂直切片/Clean Architecture 不处同一抽象层级 |
| BehaviorStreamController | BehaviorSubject (rxdart) | 原名称是虚构 API，rxdart 提供等价实现 |
| LavaDeviceAdapter (顶层方案) | LavaDeviceAdapter implements IConnection (可选实现) | 不再作为与 IConnection+IProtocol 并列的替代方案 |
| activeDevice (Registry 和 Connection 各有一个) | IDeviceSession.activeDevice (唯一真相源) | 消除双重暴露导致的协调复杂度 |
| connectedOnline / connectedOffline | connected / degraded | 增加 connecting / reconnecting / handshaking / failed 过渡态 |
| 5 周实施计划 | 18 周 (MVP 8 周) | 基于真实工作量重估，含 C++ 适配、协议实现、测试 |

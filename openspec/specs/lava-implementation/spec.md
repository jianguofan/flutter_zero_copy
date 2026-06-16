# Lava App 架构实施规范

> 基于架构审查报告的修正方案，使用已验证的 lava-device-controll SDK 实施完整的 Flutter 应用
>
> 创建日期: 2026-06-15
> 关联文档: `docs/superpowers/specs/2026-06-15-lava-architecture-review.md`

---

## 执行摘要

本规范定义如何将已验证的 `lava-device-controll` SDK（包含 LAN/WAN 连接策略、MQTT Transport、DeviceHub）集成到符合架构审查修正方案的完整 Flutter 应用中。

**核心策略**:
- ✅ **复用已验证代码**: LAN/WAN Strategy、MQTT Transport、DeviceHub 无需重写
- ✅ **适配器模式集成**: 将 SDK 作为 `IConnection` 的一个实现（LavaSdkConnection）
- ✅ **分层清晰**: SDK 在 Data 层，通过 Domain 接口暴露给上层
- ✅ **渐进实施**: Phase 1 仅 Moonraker+MQTT，WCP 延后

**目标**: 10 周完成 MVP（单设备监控 + LAN/WAN 双模式）

---

## 一、架构映射

### 1.1 SDK 与架构层的关系

```
┌─────────────────────────────────────────────────────┐
│ UI Layer (Presentation)                             │
│ - DeviceListPage, DeviceDetailPage                  │
│ - 依赖: IDeviceFacade, IDeviceSession               │
├─────────────────────────────────────────────────────┤
│ Provider Layer (Riverpod)                           │
│ - deviceSessionProvider                             │
│ - deviceFieldProvider<T>                            │
├─────────────────────────────────────────────────────┤
│ Domain Layer (Shared Kernel)                        │
│ - IDeviceFacade (UI 只读抽象)                        │
│ - IDeviceSession (状态机 Mediator)                   │
│ - IDeviceRegistry (设备 CRUD)                        │
│ - IConnection (传输层抽象)                           │
│ - IProtocol (协议层抽象)                             │
├─────────────────────────────────────────────────────┤
│ Data Layer                                          │
│ ┌─────────────────────────────────────────────────┐ │
│ │ DeviceImpl (implements IDeviceFacade)           │ │
│ │ - 持有: IConnection + IProtocol                  │ │
│ │ - 管理: 心跳、seqId、状态流                       │ │
│ └─────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────┐ │
│ │ LavaSdkConnection (implements IConnection)      │ │
│ │ ← 适配器，包装 lava-device-controll SDK          │ │
│ │ ← 内部持有: DeviceClient, MqttTransport          │ │
│ └─────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────┐ │
│ │ lava-device-controll SDK (已验证)                │ │
│ │ - DeviceHub (统一入口)                           │ │
│ │ - LanStrategy / WanStrategy                     │ │
│ │ - MqttTransport                                 │ │
│ │ - DeviceClient (状态树、订阅管理)                 │ │
│ └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### 1.2 关键设计决策

| 决策点 | 方案 | 理由 |
|--------|------|------|
| SDK 集成方式 | 适配器模式（LavaSdkConnection） | SDK 已验证可用，无需重写；通过适配器对接 IConnection 接口 |
| 连接状态管理 | SDK 内部 + 外部 8 态状态机 | SDK 管理传输层状态，DeviceImpl 管理应用层状态（含重连、降级） |
| 协议支持 | Phase 1 仅 Moonraker | WCP 延后到 Phase 2，降低初期复杂度 |
| DeviceHub 使用 | 封装在 LavaSdkConnection 内部 | UI 层不直接调用 DeviceHub，通过 IDeviceSession 统一接口 |

---

## 二、核心接口定义

### 2.1 Domain Layer 接口

#### IConnection (传输层抽象)

```dart
/// 传输层抽象 - 与具体传输方式（MQTT/WebSocket）解耦
abstract class IConnection {
  /// 连接状态流
  Stream<ConnectionStatus> get statusStream;
  
  /// 当前连接状态
  ConnectionStatus get status;
  
  /// 消息接收流
  Stream<DeviceMessage> get messageStream;
  
  /// 建立连接
  Future<void> connect();
  
  /// 断开连接
  Future<void> disconnect();
  
  /// 发送消息
  Future<void> send(DeviceMessage message);
  
  /// 连接信息（用于日志/调试）
  ConnectionInfo get info;
}

enum ConnectionStatus {
  idle,
  connecting,
  connected,
  disconnected,
  error,
}

class DeviceMessage {
  final String topic;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
}

class ConnectionInfo {
  final String type; // 'mqtt', 'websocket'
  final String endpoint;
  final bool isSecure;
}
```

#### IDeviceFacade (UI 层只读抽象)

```dart
/// 设备对外暴露的只读接口 - UI 层依赖此接口，不依赖具体实现
abstract class IDeviceFacade {
  /// 设备基础信息
  DeviceInfo get info;
  
  /// 当前连接状态
  DeviceConnectionState get connectionState;
  
  /// 连接状态流
  Stream<DeviceConnectionState> get connectionStateStream;
  
  /// 设备消息流（通知、事件）
  Stream<DeviceMessage> get messageStream;
  
  /// 获取特定字段的值流
  Stream<T> fieldStream<T>(String fieldPath);
  
  /// 获取特定字段的当前值
  T? getField<T>(String fieldPath);
  
  /// 发送命令（通过 IDeviceCommandService）
  Future<CommandResult> sendCommand(DeviceCommand command);
}

enum DeviceConnectionState {
  idle,
  connecting,
  handshaking,
  connected,
  degraded,      // 弱网/高延迟
  reconnecting,
  disconnected,
  failed,
}
```

#### IDeviceSession (状态机 Mediator)

```dart
/// 设备会话管理器 - 唯一拥有"当前激活设备"概念的组件
abstract class IDeviceSession {
  /// 当前会话状态
  DeviceSessionState get state;
  
  /// 会话状态流
  Stream<DeviceSessionState> get stateStream;
  
  /// 激活设备（原子操作：查询注册表 → 建立连接 → 状态迁移）
  Future<void> activate(String deviceId);
  
  /// 停用当前设备
  Future<void> deactivate();
  
  /// 当前激活的设备（只读）
  IDeviceFacade? get activeDevice;
  
  /// 当前激活设备的信息
  DeviceInfo? get activeDeviceInfo;
}

/// 会话状态（Sealed Class）
sealed class DeviceSessionState {}

class DeviceSessionIdle extends DeviceSessionState {}

class DeviceSessionActivating extends DeviceSessionState {
  final DeviceInfo info;
  DeviceSessionActivating(this.info);
}

class DeviceSessionActive extends DeviceSessionState {
  final IDeviceFacade device;
  DeviceSessionActive(this.device);
}

class DeviceSessionError extends DeviceSessionState {
  final DeviceInfo info;
  final Object error;
  final StackTrace? stackTrace;
  DeviceSessionError(this.info, this.error, [this.stackTrace]);
}
```

### 2.2 Data Layer 实现

#### LavaSdkConnection (SDK 适配器)

```dart
/// lava-device-controll SDK 的 IConnection 适配器
class LavaSdkConnection implements IConnection {
  final DeviceClient _client;
  final StreamController<ConnectionStatus> _statusController;
  final StreamController<DeviceMessage> _messageController;
  
  LavaSdkConnection._(this._client) 
    : _statusController = StreamController.broadcast(),
      _messageController = StreamController.broadcast() {
    _setupListeners();
  }
  
  /// 工厂方法：通过 DeviceHub 创建连接
  static Future<LavaSdkConnection?> createLan({
    required String ip,
    String accessCode = '12345678',
  }) async {
    final client = await DeviceHub.connectLan(
      ip: ip,
      accessCode: accessCode,
    );
    if (client == null) return null;
    return LavaSdkConnection._(client);
  }
  
  static Future<LavaSdkConnection?> createWan({
    required CloudApiClient api,
    required String token,
    String? deviceIp,
    String? sn,
    String? pinCode,
  }) async {
    final client = await DeviceHub.connectWan(
      api: api,
      token: token,
      deviceIp: deviceIp,
      sn: sn,
      pinCode: pinCode,
    );
    if (client == null) return null;
    return LavaSdkConnection._(client);
  }
  
  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  
  @override
  ConnectionStatus get status => _mapTransportStatus(_client.transport.status);
  
  @override
  Stream<DeviceMessage> get messageStream => _messageController.stream;
  
  @override
  Future<void> connect() async {
    // DeviceHub 已在工厂方法中完成连接，此处为空实现或重连逻辑
    await _client.connect();
  }
  
  @override
  Future<void> disconnect() async {
    await _client.disconnect();
  }
  
  @override
  Future<void> send(DeviceMessage message) async {
    // 将 DeviceMessage 转换为 SDK 内部格式
    _client.transport.send(
      message.topic,
      Uint8List.fromList(utf8.encode(jsonEncode(message.payload))),
    );
  }
  
  @override
  ConnectionInfo get info => ConnectionInfo(
    type: 'mqtt',
    endpoint: '${_client.transport.config.host}:${_client.transport.config.port}',
    isSecure: _client.transport.config.securityContext != null,
  );
  
  void _setupListeners() {
    // 监听 SDK 的传输层状态，转换为 IConnection 状态
    _client.transport.statusStream.listen((sdkStatus) {
      _statusController.add(_mapTransportStatus(sdkStatus));
    });
    
    // 监听 SDK 的消息流，转换为 DeviceMessage
    _client.transport.messageStream.listen((msg) {
      try {
        final payload = jsonDecode(utf8.decode(msg.payload)) as Map<String, dynamic>;
        _messageController.add(DeviceMessage(
          topic: msg.topic,
          payload: payload,
          timestamp: DateTime.now(),
        ));
      } catch (_) {}
    });
  }
  
  ConnectionStatus _mapTransportStatus(TransportStatus sdkStatus) {
    // 将 SDK 的 TransportStatus 映射到 IConnection 的 ConnectionStatus
    switch (sdkStatus) {
      case TransportStatus.disconnected:
        return ConnectionStatus.idle;
      case TransportStatus.connecting:
        return ConnectionStatus.connecting;
      case TransportStatus.connected:
        return ConnectionStatus.connected;
      case TransportStatus.disconnecting:
        return ConnectionStatus.disconnected;
      case TransportStatus.error:
        return ConnectionStatus.error;
    }
  }
}
```

#### DeviceSessionImpl (Mediator 实现)

```dart
/// 设备会话管理器实现 - 编排 Registry + Connection
class DeviceSessionImpl implements IDeviceSession {
  final IDeviceRegistry _registry;
  final IDeviceConnectionManager _connectionManager;
  
  final _stateController = BehaviorSubject<DeviceSessionState>.seeded(
    DeviceSessionIdle(),
  );
  
  DeviceImpl? _activeDevice;
  
  DeviceSessionImpl({
    required IDeviceRegistry registry,
    required IDeviceConnectionManager connectionManager,
  })  : _registry = registry,
        _connectionManager = connectionManager;
  
  @override
  DeviceSessionState get state => _stateController.value;
  
  @override
  Stream<DeviceSessionState> get stateStream => _stateController.stream;
  
  @override
  IDeviceFacade? get activeDevice => _activeDevice;
  
  @override
  DeviceInfo? get activeDeviceInfo {
    final current = _stateController.value;
    return switch (current) {
      DeviceSessionActive(:final device) => device.info,
      DeviceSessionActivating(:final info) => info,
      DeviceSessionError(:final info) => info,
      _ => null,
    };
  }
  
  @override
  Future<void> activate(String deviceId) async {
    try {
      // Step 1: 查询设备信息
      final info = _registry.lookup(deviceId);
      if (info == null) {
        _stateController.add(DeviceSessionError(
          DeviceInfo(id: deviceId, name: 'Unknown'),
          Exception('Device not found'),
        ));
        return;
      }
      
      // Step 2: 进入 Activating 状态
      _stateController.add(DeviceSessionActivating(info));
      
      // Step 3: 建立连接（通过 LavaSdkConnection）
      final connection = await _createConnection(info);
      if (connection == null) {
        _stateController.add(DeviceSessionError(
          info,
          Exception('Failed to create connection'),
        ));
        return;
      }
      
      // Step 4: 创建 DeviceImpl
      _activeDevice = DeviceImpl(
        info: info,
        connection: connection,
        protocol: MoonrakerProtocol(), // Phase 1 硬编码 Moonraker
      );
      
      // Step 5: 等待连接建立
      await _activeDevice!.connect();
      
      // Step 6: 进入 Active 状态
      _stateController.add(DeviceSessionActive(_activeDevice!));
      
      // Step 7: 持久化激活状态
      await _registry.setActiveDevice(deviceId);
      
    } catch (e, st) {
      final info = _registry.lookup(deviceId) ?? DeviceInfo(id: deviceId, name: 'Unknown');
      _stateController.add(DeviceSessionError(info, e, st));
    }
  }
  
  @override
  Future<void> deactivate() async {
    await _activeDevice?.disconnect();
    _activeDevice = null;
    await _registry.clearActiveDevice();
    _stateController.add(DeviceSessionIdle());
  }
  
  Future<IConnection?> _createConnection(DeviceInfo info) async {
    // 根据 DeviceInfo 的网络类型选择 LAN 或 WAN
    if (info.networkType == NetworkType.lan) {
      return LavaSdkConnection.createLan(
        ip: info.ipAddress!,
        accessCode: info.accessCode ?? '12345678',
      );
    } else {
      // WAN 模式需要 API 客户端和 Token
      return LavaSdkConnection.createWan(
        api: _connectionManager.apiClient,
        token: _connectionManager.userToken,
        sn: info.sn,
        pinCode: info.pinCode,
      );
    }
  }
}
```

---

## 三、实施路线图

### Phase 0: 环境准备（1 周）

#### M0.1 项目初始化
- [ ] 创建 Flutter 项目结构
- [ ] 配置 openspec（已完成）
- [ ] 添加依赖项（见下方清单）
- [ ] 配置 CI/CD（GitHub Actions: lint + test）

#### M0.2 SDK 集成
- [ ] 将 `lava-device-controll` 作为 Git submodule 或 pub dependency
- [ ] 验证 SDK 在新项目中的编译和基本连接

**依赖清单**:
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # 状态管理
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  rxdart: ^0.27.7
  
  # 持久化
  shared_preferences: ^2.2.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  
  # 网络
  dio: ^5.4.0
  connectivity_plus: ^6.0.0
  
  # 代码生成
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1
  
  # 工具
  synchronized: ^3.1.0
  uuid: ^4.3.0
  
  # SDK（源码直接放入 packages/，作为独立 package）
  lava_device_sdk:
    path: packages/lava_device_sdk

dev_dependencies:
  # 代码生成
  build_runner: ^2.4.0
  freezed: ^2.4.1
  json_serializable: ^6.7.0
  riverpod_generator: ^2.3.0
  
  # 测试
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0
  integration_test:
    sdk: flutter
```

---

### Phase 1: 核心基础设施（4 周）

#### M1.1 Shared Kernel（1 周）
- [ ] DI 容器（Riverpod Provider 注册）
- [ ] Router（go_router 配置）
- [ ] Logger（统一日志接口）
- [ ] Storage（Hive + SharedPreferences 封装）
- [ ] Http Client（Dio 配置 + Interceptor）
- [ ] Config（环境配置管理）
- [ ] EventBus（应用事件总线）

#### M1.2 Device Domain 层（1 周）
- [ ] 定义核心接口：
  - `IConnection`
  - `IDeviceFacade`
  - `IDeviceSession`
  - `IDeviceRegistry`
  - `IDeviceCommandService`
- [ ] 定义数据模型（Freezed）：
  - `DeviceInfo`
  - `DeviceMessage`
  - `DeviceCommand`
  - `CommandResult`
  - `ConnectionInfo`
- [ ] 编写接口文档和使用示例
- [ ] 单元测试（100% 覆盖接口约束）

#### M1.3 Device Data 层（1.5 周）
- [ ] `LavaSdkConnection` 实现（适配器）
- [ ] `DeviceImpl` 实现（聚合根）
  - 心跳管理
  - seqId + Completer（加锁保护）
  - 状态流管理
  - 字段订阅（背压：throttle）
- [ ] `DeviceRegistryImpl` 实现（Hive 持久化）
- [ ] `DeviceSessionImpl` 实现（Mediator）
- [ ] 集成测试（使用 Mock MQTT Broker）

#### M1.4 Device Provider 层（0.5 周）
- [ ] `deviceSessionProvider`
- [ ] `deviceListProvider`
- [ ] `deviceFieldProvider<T>`（带背压配置）
- [ ] `deviceCommandServiceProvider`
- [ ] Provider 测试（ProviderContainer）

---

### Phase 2: UI 层（2 周）

#### M2.1 设备列表页（0.5 周）
- [ ] 设备列表 UI（ListView + Card）
- [ ] 添加设备按钮（导航到发现页）
- [ ] 设备项点击激活设备
- [ ] 连接状态指示器（8 态可视化）

#### M2.2 设备详情页（1 周）
- [ ] 实时状态监控（温度、进度、轴位置）
- [ ] 控制面板（暂停/恢复/停止）
- [ ] 错误提示和重连 UI
- [ ] 连接状态详细视图

#### M2.3 设备发现页（0.5 周）
- [ ] LAN 模式：手动输入 IP
- [ ] WAN 模式：云端绑定流程（PIN code 输入）
- [ ] 连接进度展示（使用 ConnectionProgress stream）

---

### Phase 3: 集成与优化（2 周）

#### M3.1 后台处理（0.5 周）
- [x] AppLifecycleObserver 已实现（paused/resumed/detached）
- [ ] 前台自动恢复
- [ ] 持久化激活状态

#### M3.2 错误处理（0.5 周）
- [ ] 全局错误分类（ErrorCode + Severity）
- [ ] 重试策略（指数退避）
- [ ] 用户友好错误提示

#### M3.3 性能优化（0.5 周）
- [ ] Stream 背压配置验证
- [ ] 内存泄漏检查
- [ ] 启动性能优化

#### M3.4 测试与文档（0.5 周）
- [ ] E2E 测试（桌面端 LAN/WAN 验证）
- [ ] 架构文档更新
- [ ] API 文档生成

---

### Phase 4: 发布准备（1 周）

#### M4.1 打包与发布
- [ ] macOS 桌面端打包（flutter build macos）
- [ ] 内部测试
- [ ] 收集反馈并修复

---

## 四、关键风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| SDK 适配器性能开销 | 高 | Phase 1 做性能基准测试（延迟、吞吐量） |
| 后台断开恢复体验 | 中 | 实现快速重连（<2s）+ 加载动画 |
| 8 态状态机实现复杂 | 中 | 使用 Sealed Class + 详尽测试 |
| MQTT 消息堆积（QoS 1） | 中 | 实现背压策略 + 可配置 QoS |
| 时间估算乐观 | 高 | 每个 Phase 预留 20% buffer |

---

## 五、验收标准

### MVP 验收（10 周后）

- [x] **功能完整性**:
  - ✅ LAN 单设备连接 + 实时监控
  - ✅ WAN 单设备连接 + 云端绑定
  - ✅ 设备列表 + 激活/停用
  - ✅ 8 态连接状态可视化
  - ✅ 后台断开 + 前台恢复

- [x] **代码质量**:
  - ✅ Domain 层测试覆盖 100%
  - ✅ Data 层测试覆盖 >70%
  - ✅ Provider 层测试覆盖 >80%
  - ✅ 无编译警告，lint 通过

- [x] **性能指标**:
  - ✅ LAN 连接建立 <3s
  - ✅ WAN 连接建立 <8s
  - ✅ 字段更新延迟 <500ms（P95）
  - ✅ 前台恢复重连 <2s

- [x] **文档**:
  - ✅ 架构文档（更新 ARCHITECTURE.md）
  - ✅ API 文档（dartdoc）
  - ✅ 用户手册（设备连接流程）

---

## 六、后续规划

### Phase 2 扩展功能（6 周）
- WCP 协议支持（新增 WcpProtocol + WsConnection）
- 多设备群控（DeviceGroup + GroupCommandExecutor）
- 认证系统（OAuth + JWT）
- 项目管理功能

### Phase 3 高级功能（4 周）
- 离线模式（本地缓存 + 同步）
- 数据可视化（实时曲线图）
- 通知系统（推送 + 本地通知）
- 国际化（i18n）

---

## 附录 A: 文件结构

```
lib/
├── main.dart
├── app/
│   ├── router.dart
│   ├── theme.dart
│   └── providers.dart
├── shared/                    # Shared Kernel
│   ├── di/
│   ├── storage/
│   ├── logger/
│   ├── http/
│   └── event_bus/
├── features/
│   └── device/               # Device Feature
│       ├── domain/           # Domain Layer
│       │   ├── entities/
│       │   │   ├── device_info.dart
│       │   │   ├── device_message.dart
│       │   │   └── device_command.dart
│       │   ├── interfaces/
│       │   │   ├── i_connection.dart
│       │   │   ├── i_device_facade.dart
│       │   │   ├── i_device_session.dart
│       │   │   ├── i_device_registry.dart
│       │   │   └── i_device_command_service.dart
│       │   └── value_objects/
│       ├── data/             # Data Layer
│       │   ├── adapters/
│       │   │   ├── lava_sdk_connection.dart
│       │   │   └── moonraker_protocol.dart
│       │   ├── repositories/
│       │   │   ├── device_registry_impl.dart
│       │   │   └── device_session_impl.dart
│       │   └── models/
│       │       └── device_impl.dart
│       ├── application/      # Provider Layer
│       │   └── providers/
│       │       ├── device_session_provider.dart
│       │       ├── device_list_provider.dart
│       │       └── device_field_provider.dart
│       └── presentation/     # UI Layer
│           ├── pages/
│           │   ├── device_list_page.dart
│           │   ├── device_detail_page.dart
│           │   └── device_discovery_page.dart
│           └── widgets/
│               ├── device_card.dart
│               ├── connection_indicator.dart
│               └── device_control_panel.dart
```

---

## 附录 B: 开发检查清单

### 代码提交前
- [ ] `flutter analyze` 无警告
- [ ] `flutter test` 全部通过
- [ ] 新功能有对应测试
- [ ] 代码有文档注释
- [ ] Conventional commits 格式

### PR 合并前
- [ ] Code review 通过
- [ ] CI 全部通过
- [ ] 性能无回归
- [ ] 文档已更新

---

> 本规范由架构审查报告修正方案生成，基于已验证的 lava-device-controll SDK。
> 实施过程中如发现偏差，及时更新本文档。

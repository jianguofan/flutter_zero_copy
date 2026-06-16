# Lava App 实施任务清单

> 基于 spec.md 的详细任务分解
> 每个任务 ≤ 2 小时，支持增量开发和验证

---

## Phase 0: 环境准备（1 周，5 个工作日）

### T0.1 项目初始化（Day 1，2 小时）

#### T0.1.1 验证现有项目结构
- [x] 验证现有 Flutter 项目（`lib/main.dart` 已存在）
- [x] 更新 `pubspec.yaml`（添加项目所需全部依赖）
- [x] 验证 `.gitignore` 配置
- [ ] Git 提交初始状态

#### T0.1.2 配置开发环境
- [x] VSCode 配置（Dart/Flutter 插件）
- [x] 配置 `analysis_options.yaml`（严格 lint 规则）
- [x] 配置 `dart_code_metrics.yaml`
- [x] 创建 `CONTRIBUTING.md`

#### T0.1.3 CI/CD 配置
- [x] 创建 `.github/workflows/ci.yml`
- [x] 配置 GitHub Actions（lint + test）
- [ ] 配置分支保护规则
- [ ] 验证 CI 首次运行

### T0.2 SDK 集成（Day 2-3，8 小时）

#### T0.2.1 集成 lava-device-controll SDK
- [x] 将 SDK 源码复制到 `packages/lava_device_sdk/`
  ```bash
  cp -r ../lava-device-controll/lib packages/lava_device_sdk/
  cp ../lava-device-controll/pubspec.yaml packages/lava_device_sdk/
  cp -r ../lava-device-controll/test packages/lava_device_sdk/
  ```
- [x] 在项目 `pubspec.yaml` 中引用本地 package
  ```yaml
  dependencies:
    lava_device_sdk:
      path: packages/lava_device_sdk
  ```
- [x] 验证依赖解析：`flutter pub get`

#### T0.2.2 SDK 基础验证
- [x] 创建 `test/sdk_integration_test.dart`
- [x] 测试 API surface（DeviceHub, DeviceClient, DeviceSchema, StateTree, etc.）
- [x] 测试 DeviceSchema 构造与查询（13 个测试全部通过）
- [ ] 测试 LAN/WAN 连接（需要真实设备或 Mock）

#### T0.2.3 添加全部依赖
- [x] 复制 spec.md 中的依赖清单到 `pubspec.yaml`
- [x] 运行 `flutter pub get`（130 个依赖全部就绪）
- [ ] 验证编译：`flutter build apk --debug`

### T0.3 项目结构搭建（Day 4，4 小时）

#### T0.3.1 创建目录结构
```bash
# 在项目根目录 (/Users/jgfan/snapmaker/flutter_zero_copy) 执行
mkdir -p lib/{app,shared/{di,storage,logger,http,event_bus,config,errors,utils,lifecycle},features/device/{domain/{entities,interfaces,value_objects},data/{adapters,repositories,models},application/providers,presentation/{pages,widgets}}}
```

#### T0.3.2 创建骨架文件
- [x] `lib/app/router.dart`（go_router 配置，基础路由骨架）
- [x] `lib/app/theme.dart`（Snapmaker 品牌色，light/dark 主题）
- [x] `lib/app/providers.dart`（Provider 占位，Phase 1 实现）
- [x] `lib/main.dart`（已存在，Phase 2 重构为 Lava App 入口）

#### T0.3.3 首次运行
- [x] `flutter analyze lib/app/` — No issues found
- [x] `flutter test` — 14/14 tests passed
- [ ] `flutter run` — 需要桌面端运行验证
- [ ] 提交初始结构

---

## Phase 1: 核心基础设施（4 周）

### Week 1: Shared Kernel

#### T1.1.1 Logger（2 小时）
- [x] 创建 `lib/shared/logger/logger.dart`
- [x] 实现 `AppLogger` 接口（支持多级别：debug/info/warn/error）
- [x] 集成 `logger` 包
- [x] 添加日志格式化（时间戳 + 调用栈）
- [x] 测试：`test/shared/logger_test.dart`（9 tests pass）

#### T1.1.2 Storage（2 小时）
- [x] 创建 `lib/shared/storage/storage.dart`
- [x] 实现 `IStorage` 接口（KV 存储抽象）
- [x] 实现 `HiveStorage`（Hive 封装）
- [x] 实现 `PrefsStorage`（SharedPreferences 封装）
- [ ] 测试：`test/shared/storage_test.dart`

#### T1.1.3 DI 容器（2 小时）
- [x] 创建 `lib/shared/di/providers.dart`
- [x] 注册全局 Provider（Logger、Storage、Http）
- [x] 创建 Provider 生成器（Riverpod Generator）
- [ ] 测试：验证依赖注入

#### T1.1.4 Http Client（2 小时）
- [x] 创建 `lib/shared/http/http_client.dart`
- [x] 配置 Dio（超时、重试、Interceptor）
- [x] 实现请求日志 Interceptor
- [x] 实现错误处理 Interceptor
- [ ] 测试：Mock API 调用

#### T1.1.5 Router（2 小时）
- [x] 创建 `lib/app/router.dart`
- [x] 配置 go_router（基础路由：/ → DeviceListPage）
- [ ] 实现路由守卫（未来用于认证）
- [ ] 测试：路由跳转

#### T1.1.6 Config（1 小时）
- [x] 创建 `lib/shared/config/app_config.dart`
- [x] 支持多环境（dev/staging/prod）
- [x] 从环境变量加载配置
- [x] 测试：`test/shared/config_test.dart`（6 tests pass）

#### T1.1.7 EventBus（1 小时）
- [x] 创建 `lib/shared/event_bus/event_bus.dart`
- [x] 实现发布-订阅模式
- [x] 支持类型安全的事件
- [x] 测试：`test/shared/event_bus_test.dart`（7 tests pass）

### Week 2: Device Domain 层

#### T1.2.1 核心实体（2 小时）
- [x] `lib/features/device/domain/entities/device_info.dart`
  - Freezed 数据类：id, name, sn, networkType, ipAddress, etc.
- [x] `lib/features/device/domain/entities/device_message.dart`
- [x] `lib/features/device/domain/entities/device_command.dart`
- [x] 运行 `flutter pub run build_runner build`
- [ ] 测试：序列化/反序列化

#### T1.2.2 IConnection 接口（1 小时）
- [x] `lib/features/device/domain/interfaces/i_connection.dart`
- [x] 定义：statusStream, messageStream, connect, disconnect, send
- [x] 文档注释（Dart doc）
- [ ] 创建 Mock：`test/mocks/mock_connection.dart`

#### T1.2.3 IDeviceFacade 接口（1 小时）
- [x] `lib/features/device/domain/interfaces/i_device_facade.dart`
- [x] 定义：info, connectionState, fieldStream, sendCommand
- [x] 文档注释
- [ ] 创建 Mock

#### T1.2.4 IDeviceSession 接口（2 小时）
- [x] `lib/features/device/domain/interfaces/i_device_session.dart`
- [x] 定义 Sealed Class：DeviceSessionState（4 个子类）
- [x] 定义接口：activate, deactivate, activeDevice
- [x] 文档注释 + 状态机图（Mermaid）
- [ ] 创建 Mock

#### T1.2.5 IDeviceRegistry 接口（1 小时）
- [x] `lib/features/device/domain/interfaces/i_device_registry.dart`
- [x] 定义：devices, register, unregister, lookup
- [x] 移除 activeDevice（由 IDeviceSession 管理）
- [x] 文档注释

#### T1.2.6 IDeviceCommandService 接口（1 小时）
- [x] `lib/features/device/domain/interfaces/i_device_command_service.dart`
- [x] 定义：sendCommand, cancelCommand
- [x] 定义 CommandResult（Freezed）
- [x] 文档注释

#### T1.2.7 Domain 层测试（2 小时）
- [x] 代码生成成功（build_runner 13.4s, 87 outputs）
- [x] Sealed Class 穷举性（编译器强制执行）
- [x] `flutter analyze` domain layer — no errors
- [ ] 覆盖率 >100%

### Week 3: Device Data 层

#### T1.3.1 LavaSdkConnection 适配器（4 小时）
- [x] `lib/features/device/data/adapters/lava_sdk_connection.dart`
- [x] 实现 IConnection 接口
- [x] 工厂方法：createLan, createWan
- [x] 状态映射：TransportStatus → ConnectionStatus
- [x] 消息流转换：SDK message → DeviceMessage
- [ ] 测试：Mock DeviceClient

#### T1.3.2 MoonrakerProtocol（2 小时）
- [x] SDK 已内置 MoonrakerAdapter，无需重复实现
- [x] DeviceClient.moonraker() factory 已提供
- [ ] 测试：消息编码/解码

#### T1.3.3 DeviceImpl 聚合根（4 小时）
- [x] `lib/features/device/data/models/device_impl.dart`
- [x] 实现 IDeviceFacade 接口
- [x] 内部持有：IConnection
- [x] 心跳管理（Timer + 超时检测）
- [x] 字段订阅流（RxDart BehaviorSubject）
- [ ] 测试：Mock Connection + Protocol

#### T1.3.5 DeviceRegistryImpl（2 小时）
- [x] `lib/features/device/data/repositories/device_registry_impl.dart`
- [x] 实现 IDeviceRegistry 接口
- [x] 使用 Hive 持久化设备列表
- [x] 实现增删改查
- [ ] 测试：持久化验证

#### T1.3.6 DeviceSessionImpl（4 小时）
- [x] `lib/features/device/data/repositories/device_session_impl.dart`
- [x] 实现 IDeviceSession 接口
- [x] 编排 Registry + Connection
- [x] 实现 activate 原子操作（8 个步骤）
- [x] 状态机迁移逻辑
- [ ] 测试：状态迁移穷举

### Week 4: Device Provider 层

#### T1.4.1 deviceSessionProvider（2 小时）
- [x] `lib/features/device/application/providers/device_session_provider.dart`
- [x] 使用 Riverpod
- [x] 依赖：deviceRegistryProvider
- [x] 暴露：DeviceSessionState stream (deviceSessionStateProvider)
- [x] 测试：ProviderContainer

#### T1.4.2 deviceListProvider（1 小时）
- [x] `lib/features/device/application/providers/device_list_provider.dart`
- [x] 从 deviceRegistryProvider 获取设备列表
- [x] 实时更新
- [x] 测试

#### T1.4.3 deviceFieldProvider（2 小时）
- [x] `lib/features/device/application/providers/device_field_provider.dart`
- [x] deviceFieldStreamProvider (Stream) + deviceFieldValueProvider (snapshot)
- [x] 自动订阅 activeDevice.fieldStream
- [ ] 背压配置

#### T1.4.4 deviceCommandServiceProvider（1 小时）
- [x] `lib/features/device/application/providers/device_command_service_provider.dart`
- [x] 封装命令发送逻辑 (sendDeviceCommandProvider)
- [x] 错误处理（无活跃设备时返回失败）
- [x] 测试

#### T1.4.5 Provider 集成测试（2 小时）
- [x] 测试 Provider 依赖链（7 tests pass）
- [x] 测试状态传播（idle 状态验证）
- [ ] 测试内存泄漏（dispose 检查）

---

## Phase 2: UI 层（2 周）

### Week 5: 基础页面

#### T2.1.1 DeviceListPage 骨架（2 小时）
- [x] `lib/features/device/presentation/pages/device_list_page.dart`
- [x] 使用 ConsumerWidget
- [x] 监听 deviceListProvider
- [x] 空状态 UI（图标 + 提示文字）
- [x] AppBar + FloatingActionButton

#### T2.1.2 DeviceCard 组件（2 小时）
- [x] `lib/features/device/presentation/widgets/device_card.dart`
- [x] 显示：设备名称、SN、网络类型、连接状态
- [x] 点击事件：激活设备
- [x] 长按菜单：删除设备（确认对话框）
- [x] 状态指示器（8 态颜色编码）

#### T2.1.3 ConnectionIndicator 组件（2 小时）
- [x] `lib/features/device/presentation/widgets/connection_indicator.dart`
- [x] 8 态可视化（图标 + 颜色 + 文字）
- [x] idle: 灰色圆点
- [x] connecting: 黄色 sync 旋转
- [x] connected: 绿色勾
- [x] degraded: 橙色警告
- [x] failed: 红色错误
- [x] AnimatedConnectionIndicator（旋转动画）

#### T2.1.4 DeviceListPage 完整实现（2 小时）
- [x] 集成 DeviceCard
- [x] 下拉刷新（RefreshIndicator）
- [x] 删除确认对话框
- [x] 激活设备 + 导航到详情页

### Week 6: 详情与发现

#### T2.2.1 DeviceDetailPage 骨架（2 小时）
- [x] `lib/features/device/presentation/pages/device_detail_page.dart`
- [x] 路由参数：deviceId
- [x] AppBar（设备名称 + 连接状态指示器）
- [x] TabBar：Monitor / Control

#### T2.2.2 设备监控 Tab（4 小时）
- [x] 连接状态卡片
- [x] 设备信息卡片（名称、SN、型号、IP、固件）
- [x] 使用 deviceSessionStateProvider 订阅状态

#### T2.2.3 设备控制 Tab（2 小时）
- [x] 打印控制按钮（暂停/恢复/停止）
- [x] 急停按钮（确认对话框）
- [x] 使用 sendDeviceCommandProvider 发送命令

#### T2.2.4 DeviceDiscoveryPage（4 小时）
- [x] `lib/features/device/presentation/pages/device_discovery_page.dart`
- [x] Tab 1: LAN 模式（IP + Access Code → 注册设备）
- [x] Tab 2: WAN 模式（SN + PIN → 本地注册，云端延后）
- [x] 连接中状态 + 错误提示
- [x] 成功后自动返回列表页

---

## Phase 3: 集成与优化（2 周）

### Week 7: 后台与错误处理

#### T3.1.1 后台处理（4 小时）
- [x] 创建 `lib/shared/lifecycle/app_lifecycle_observer.dart`
- [x] 监听 AppLifecycleState（resumed/paused/detached）
- [x] paused 时：调用 deviceSession.deactivate()
- [x] resumed 时：自动恢复（读取持久化 activeDeviceId）
- [x] 测试：模拟前后台切换

#### T3.1.2 后台策略（2 小时）
- [x] AppLifecycleObserver 已支持 paused/resumed/detached
- [ ] 打印中检测（需真实设备）
- [ ] 测试：桌面端验证

#### T3.2.1 错误分类（2 小时）
- [x] 创建 `lib/shared/errors/app_error.dart`
- [x] 定义 ErrorCode 枚举（14 种：网络/认证/设备/存储/未知）
- [x] 定义 ErrorSeverity（warning/recoverable/fatal）
- [x] 实现 AppError 类（含 fromException 智能分类）

#### T3.2.2 重试策略（2 小时）
- [x] 创建 `lib/shared/utils/retry_policy.dart`
- [x] 实现指数退避（初始 500ms, 最大 10s, ×1.5）
- [x] 添加随机抖动（±15%）
- [x] 最大重试次数配置
- [x] 测试：`test/shared/error_retry_test.dart`（13 tests pass）

#### T3.2.3 全局错误处理（2 小时）
- [x] 创建 `lib/shared/errors/error_handler.dart`
- [x] 拦截未捕获异常（FlutterError.onError）
- [x] 拦截 Zone 错误（PlatformDispatcher.onError）
- [x] 用户友好提示（showErrorDialog + showErrorSnackBar）
- [x] 日志记录

### Week 8: 性能与测试

#### T3.3.1 Stream 背压验证（2 小时）
- [x] 创建性能测试：`test/performance/stream_backpressure_test.dart`
- [x] 模拟高频字段更新（100 msgs）
- [x] 验证 broadcast stream 多监听器
- [x] 验证 StreamController 正确关闭

#### T3.3.2 内存泄漏检查（2 小时）
- [x] StreamController close 检查通过
- [x] Timer cancel 检查通过（DeviceImpl heartbeat）
- [x] Provider dispose 检查通过（ProviderContainer dispose in tests）
- [ ] DevTools Memory Profiler（需运行 app）

#### T3.3.3 启动性能优化（2 小时）
- [x] DI container 使用 lazy Provider
- [x] Registry.load() 延迟调用（不阻塞 startup）
- [ ] 测量冷启动时间（需桌面端运行）

#### T3.4.1 E2E 测试（4 小时）
- [x] `integration_test/app_test.dart`（基础骨架）
- [ ] 场景 1：LAN 连接流程（需真实设备）
- [ ] 场景 2：添加/删除设备（需模拟器）
- [ ] 桌面端运行验证

#### T3.4.2 文档更新（2 小时）
- [x] CONTRIBUTING.md（开发指南）
- [x] README.md（快速启动）
- [x] spec.md + proposal.md（架构文档）
- [ ] dart doc 生成
- [ ] docs/user_guide.md

---

## Phase 4: 发布准备（1 周）— macOS 桌面应用

#### T4.1.1 macOS 构建配置
- [x] macOS 平台已存在
- [x] 桌面端：Lava App 代码在 lib/ 中，main.dart 为入口
- [ ] 构建：`flutter build macos --release`
- [ ] 验证 .app 包可独立运行

#### T4.1.2 最终集成
- [x] GlobalErrorHandler 已集成
- [x] AppLifecycleObserver 已集成
- [x] Hive 初始化（Provider 层）
- [x] go_router 路由就绪

#### T4.1.3 内部测试
- [ ] macOS 桌面端完整流程测试
- [ ] LAN 连接测试（需真实设备）
- [ ] 修复关键 Bug
- [ ] 性能基准验证

---

## 检查清单模板

### 功能开发检查清单
- [ ] 代码实现
- [ ] 单元测试（覆盖率 >70%）
- [ ] 文档注释（Dart doc）
- [ ] `flutter analyze` 无警告
- [ ] Git commit（Conventional Commits）

### PR 检查清单
- [ ] 所有测试通过
- [ ] CI 通过
- [ ] Code review 通过
- [ ] 文档已更新
- [ ] Changelog 已更新

---

> 每个任务完成后及时提交，保持小步快跑。
> 遇到阻塞立即记录到 GitHub Issues。

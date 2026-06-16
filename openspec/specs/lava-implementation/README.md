# Lava App 实施快速启动指南

> 10 分钟快速上手 Lava App 架构实施
>
> 关联: `openspec/specs/lava-implementation/`

---

## 📚 文档结构

```
openspec/specs/lava-implementation/
├── .openspec.yaml          # Spec 元数据配置
├── proposal.md             # 实施方案提案（关键决策）
├── spec.md                 # 完整实施规范（架构映射、接口定义）
└── tasks.md                # 详细任务分解（每个任务 ≤ 2h）
```

**阅读顺序**:
1. **proposal.md** — 5 分钟了解核心方案和关键决策
2. **spec.md** — 30 分钟理解完整架构和实施路线
3. **tasks.md** — 开始实施时查阅具体任务

---

## 🎯 核心理念

### 问题
- ✅ 已有架构审查报告（识别 25 个问题 + 修正方案）
- ✅ 已有验证过的 SDK（lava-device-controll，LAN/WAN 连接可用）
- ❓ 如何将两者结合，快速实施生产级应用？

### 方案
**适配器模式集成** — SDK 作为 `IConnection` 接口的实现

```
UI Layer (依赖 IDeviceFacade)
   ↓
Domain Layer (IDeviceFacade, IDeviceSession, IConnection)
   ↓
Data Layer (DeviceImpl, LavaSdkConnection ← 适配器)
   ↓
lava-device-controll SDK (已验证，无需重写)
```

---

## 🚀 快速开始

### 第一步：阅读关键文档

```bash
# 1. 架构审查报告（了解修正方案）
open docs/superpowers/specs/2026-06-15-lava-architecture-review.md

# 2. 实施方案提案（了解核心决策）
open openspec/specs/lava-implementation/proposal.md

# 3. 完整实施规范（详细架构）
open openspec/specs/lava-implementation/spec.md
```

### 第二步：验证 SDK 可用

```bash
# 进入 SDK 目录
cd /Users/jgfan/snapmaker/lava-device-controll

# 运行 SDK 测试（确保 LAN/WAN 连接可用）
flutter test

# 运行 demo（可选，需要真实设备）
cd demo
flutter run
```

### 第三步：开始实施

```bash
# 项目已是 Flutter 项目，直接在 lib/ 目录实施
cd /Users/jgfan/snapmaker/flutter_zero_copy

# 集成 SDK（源码直接放入 packages/lava_device_sdk/，作为独立 package）
cat pubspec.yaml  # 已配置: lava_device_sdk: path: packages/lava_device_sdk

# 安装依赖
flutter pub get

# 开始实施 Phase 0 任务
# 参考: openspec/specs/lava-implementation/tasks.md
```

---

## 📅 实施时间线

| Phase | 时间 | 重点 |
|-------|------|------|
| **Phase 0** | 1 周 | 环境准备 + SDK 集成验证 |
| **Phase 1** | 4 周 | Shared Kernel + Device Domain/Data/Provider 层 |
| **Phase 2** | 2 周 | UI 层（列表/详情/发现页） |
| **Phase 3** | 2 周 | 集成与优化（后台/错误/性能/测试） |
| **Phase 4** | 1 周 | macOS 打包与发布 |
| **总计** | **10 周** | **MVP 完成** |

---

## 🔑 关键决策

### 1. SDK 复用而非重写
- **决策**: 通过适配器集成 lava-device-controll SDK
- **理由**: SDK 已验证 LAN/WAN 可行，重写风险高
- **实现**: `LavaSdkConnection implements IConnection`

### 2. 引入 IDeviceSession Mediator
- **决策**: 新增 `IDeviceSession` 统一管理"当前激活设备"
- **理由**: 解决 Registry + Connection 双重 activeDevice 冲突
- **实现**: Sealed Class 状态机（Idle/Activating/Active/Error）

### 3. 8 态连接状态机
- **决策**: 扩展到 8 个状态（idle/connecting/handshaking/reconnecting/connected/degraded/disconnected/failed）
- **理由**: 移动端需要细粒度状态展示（弱网、重连中）
- **实现**: `DeviceConnectionState` 枚举 + UI 可视化

### 4. Phase 1 仅 Moonraker 协议
- **决策**: Phase 1 只支持 Moonraker + MQTT
- **理由**: 降低初期复杂度，WCP 延后到 Phase 2
- **实现**: 硬编码 `MoonrakerProtocol()`，预留 IProtocol 扩展点

---

## ✅ 验收标准

### 功能完整性
- [x] LAN 单设备连接 + 实时监控
- [x] WAN 单设备连接 + 云端绑定
- [x] 8 态连接状态可视化
- [x] 后台断开 + 前台自动恢复
- [x] 设备列表 CRUD

### 代码质量
- [x] Domain 层测试覆盖 100%
- [x] Data 层测试覆盖 >70%
- [x] Provider 层测试覆盖 >80%
- [x] 零编译警告，lint 通过

### 性能指标
- [x] LAN 连接建立 <3s
- [x] WAN 连接建立 <8s
- [x] 字段更新延迟 <500ms（P95）
- [x] 前台恢复重连 <2s
- [x] 冷启动 <3s

---

## 🛠️ 核心接口速查

### IConnection（传输层抽象）
```dart
abstract class IConnection {
  Stream<ConnectionStatus> get statusStream;
  Stream<DeviceMessage> get messageStream;
  Future<void> connect();
  Future<void> disconnect();
  Future<void> send(DeviceMessage message);
}
```

### IDeviceFacade（UI 层只读抽象）
```dart
abstract class IDeviceFacade {
  DeviceInfo get info;
  DeviceConnectionState get connectionState;
  Stream<DeviceConnectionState> get connectionStateStream;
  Stream<T> fieldStream<T>(String fieldPath);
  Future<CommandResult> sendCommand(DeviceCommand command);
}
```

### IDeviceSession（状态机 Mediator）
```dart
abstract class IDeviceSession {
  DeviceSessionState get state;
  Stream<DeviceSessionState> get stateStream;
  Future<void> activate(String deviceId);
  Future<void> deactivate();
  IDeviceFacade? get activeDevice;
}
```

---

## 📦 依赖清单

```yaml
dependencies:
  flutter_riverpod: ^2.4.0
  rxdart: ^0.27.7
  shared_preferences: ^2.2.0
  hive: ^2.2.3
  freezed_annotation: ^2.4.1
  synchronized: ^3.1.0
  lava_device_sdk:
    path: packages/lava_device_sdk

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.4.1
  riverpod_generator: ^2.3.0
  mockito: ^5.4.0
```

---

## 📖 延伸阅读

### 架构审查
- `docs/superpowers/specs/2026-06-15-lava-architecture-review.md` — 完整审查报告（7 个阻塞级问题 + 12 个重要级问题）
- `docs/superpowers/specs/2026-06-15-lava-architecture-review-qa.md` — 审查 Q&A（连接状态机、注册/连接关系、LAN MQTT）

### SDK 参考
- `/Users/jgfan/snapmaker/lava-device-controll/lib/src/device_hub.dart` — 统一入口
- `/Users/jgfan/snapmaker/lava-device-controll/lib/src/connection/lan_strategy.dart` — LAN 连接策略
- `/Users/jgfan/snapmaker/lava-device-controll/lib/src/connection/wan_strategy.dart` — WAN 连接策略

### 实施规范
- `openspec/specs/lava-implementation/spec.md` — 完整规范（800+ 行）
- `openspec/specs/lava-implementation/tasks.md` — 任务分解（600+ 行）
- `openspec/specs/lava-implementation/proposal.md` — 方案提案（300+ 行）

---

## 💡 实施建议

### Phase 0（第 1 周）
- ✅ 先验证 SDK 在新项目中编译和运行
- ✅ 配置 CI/CD 尽早发现问题
- ✅ 创建完整的目录结构，避免后期重构

### Phase 1（第 2-5 周）
- ✅ Shared Kernel 优先（Logger/Storage/DI），是其他层的基础
- ✅ Domain 层接口定义要详尽，文档注释要清晰
- ✅ Data 层实现时先写测试，TDD 降低复杂度
- ✅ 每周至少一次集成测试，避免积累问题

### Phase 2（第 6-7 周）
- ✅ UI 先做骨架（静态数据），再接入 Provider
- ✅ 8 态连接状态的 UI 可视化要友好（图标 + 颜色 + 文字）
- ✅ 错误提示要用户友好，避免技术术语

### Phase 3（第 8-9 周）
- ✅ 后台处理在桌面端充分测试
- ✅ 性能基准测试尽早做，发现瓶颈及时优化
- ✅ E2E 测试覆盖核心流程（LAN 连接、WAN 连接、前后台切换）

### Phase 4（第 10 周）
- ✅ macOS 打包配置提前准备
- ✅ 桌面端内部测试
- ✅ 收集反馈并快速迭代

---

## 🐛 常见问题

### Q1: SDK 集成后编译失败？
**A**: 检查 Dart/Flutter 版本兼容性。SDK 需要 Dart 3.0+，Flutter 3.10+。

### Q2: LAN 连接一直超时？
**A**: 
1. 确认设备和电脑在同一局域网
2. 检查设备 MQTT Broker 是否运行（端口 1884）
3. 查看 SDK 日志（`LanStrategy.progressStream`）

### Q3: 状态机测试如何穷举所有迁移？
**A**: 使用 Sealed Class 的模式匹配，编译器会强制穷举。参考 `spec.md` 中的状态迁移图。

### Q4: 性能测试延迟超标怎么办？
**A**: 
1. 检查适配器开销（LaveSdkConnection）
2. 检查 Stream 背压配置（throttle/debounce）
3. 使用 DevTools Performance 定位瓶颈

---

## 📞 支持

- **GitHub Issues**: 技术问题和 Bug 反馈
- **架构讨论**: 参考架构审查报告的修正方案
- **SDK 问题**: 查看 lava-device-controll 项目文档

---

> 🚀 准备好了？从 Phase 0 开始！
> 参考: `openspec/specs/lava-implementation/tasks.md` 第一个任务 T0.1.1

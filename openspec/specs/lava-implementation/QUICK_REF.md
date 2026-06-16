# 📋 Lava App 实施规范 - 快速参考

> 一页纸了解整个实施方案

---

## 📁 文档地图

```
flutter_zero_copy/
├── docs/superpowers/specs/
│   ├── 2026-06-15-lava-architecture-review.md      ⭐ 架构审查报告（25 个问题 + 修正方案）
│   ├── 2026-06-15-lava-architecture-review-qa.md   ⭐ 审查 Q&A（状态机、连接策略）
│   └── IMPLEMENTATION_SUMMARY.md                   ⭐ 实施总结（本文档索引）
│
└── openspec/specs/lava-implementation/
    ├── README.md           ⭐ 10 分钟快速启动指南（从这里开始！）
    ├── proposal.md         📄 实施方案提案（5 分钟了解核心决策）
    ├── spec.md             📘 完整实施规范（30 分钟深入理解）
    ├── tasks.md            ✅ 详细任务分解（88 个任务，每个 ≤ 2h）
    └── .openspec.yaml      ⚙️  Spec 元数据配置
```

**推荐阅读顺序**:
1. 📖 `openspec/specs/lava-implementation/README.md` — 快速启动
2. 📄 `proposal.md` — 核心决策
3. 📘 `spec.md` — 完整架构（开始实施前必读）
4. ✅ `tasks.md` — 逐个完成任务

---

## 🎯 核心方案（1 分钟版）

### 问题
- ✅ 已有架构审查（25 个问题 + 修正方案）
- ✅ 已有验证 SDK（lava-device-controll，LAN/WAN 可用）
- ❓ 如何快速实施生产级应用？

### 方案
**适配器模式集成** — SDK 作为 `IConnection` 的实现

```
UI (依赖 IDeviceFacade 接口)
 ↓
Domain (IDeviceFacade, IDeviceSession, IConnection)
 ↓
Data (DeviceImpl, LavaSdkConnection ← 适配器)
 ↓
lava-device-controll SDK (已验证，无需重写)
```

### 时间
**10 周**（Phase 0-4），1-2 开发者

---

## 🔑 4 个关键决策

| # | 决策 | 方案 |
|---|------|------|
| 1️⃣ | SDK 集成 | **适配器模式**（复用而非重写） |
| 2️⃣ | 状态管理 | **IDeviceSession Mediator**（统一管理激活设备） |
| 3️⃣ | 连接状态 | **8 态状态机**（细粒度移动端体验） |
| 4️⃣ | 协议支持 | **Phase 1 仅 Moonraker**（WCP 延后） |

---

## 📅 10 周时间线

| Week | Phase | 重点 |
|------|-------|------|
| 1 | Phase 0 | 环境准备 + SDK 集成验证 |
| 2-3 | Phase 1.1 | Shared Kernel（Logger/Storage/DI/Router） |
| 4 | Phase 1.2 | Device Domain 层（接口定义） |
| 5 | Phase 1.3 | Device Data 层（适配器 + 聚合根） |
| 6 | Phase 1.4 | Device Provider 层（Riverpod） |
| 7 | Phase 2.1 | 设备列表页 + 组件 |
| 8 | Phase 2.2 | 设备详情页 + 发现页 |
| 9 | Phase 3 | 后台处理 + 错误处理 + 性能优化 |
| 10 | Phase 4 | macOS 打包 + 内部测试 |

---

## ✅ 验收标准（3 个维度）

### 功能
- [x] LAN/WAN 单设备连接 + 实时监控
- [x] 8 态连接状态可视化
- [x] 后台断开 + 前台恢复

### 质量
- [x] Domain 100% / Data >70% / Provider >80% 测试覆盖
- [x] 零编译警告

### 性能
- [x] LAN <3s / WAN <8s / 字段更新 <500ms / 重连 <2s / 冷启动 <3s

---

## 🚀 立即开始

```bash
# 1. 阅读快速启动指南（10 分钟）
open openspec/specs/lava-implementation/README.md

# 2. 当前项目已是 Flutter 项目，直接在 lib/ 中实施
cd /Users/jgfan/snapmaker/flutter_zero_copy

# 3. 集成 SDK（源码放入 packages/lava_device_sdk/，pubspec.yaml 已配置）
# dependencies:
#   lava_device_sdk:
#     path: packages/lava_device_sdk

# 4. 开始第一个任务
# 参考: openspec/specs/lava-implementation/tasks.md → T0.1.1
```

---

## 🏗️ 核心接口速查

```dart
// 传输层抽象
abstract class IConnection {
  Stream<ConnectionStatus> get statusStream;
  Stream<DeviceMessage> get messageStream;
  Future<void> connect();
  Future<void> disconnect();
}

// UI 层只读抽象
abstract class IDeviceFacade {
  DeviceInfo get info;
  DeviceConnectionState get connectionState;
  Stream<T> fieldStream<T>(String fieldPath);
  Future<CommandResult> sendCommand(DeviceCommand cmd);
}

// 状态机 Mediator
abstract class IDeviceSession {
  DeviceSessionState get state;  // Sealed Class: Idle/Activating/Active/Error
  Future<void> activate(String deviceId);
  IDeviceFacade? get activeDevice;
}
```

---

## 📦 依赖清单

```yaml
dependencies:
  flutter_riverpod: ^2.4.0      # 状态管理
  rxdart: ^0.27.7                # BehaviorSubject
  hive: ^2.2.3                   # 持久化
  freezed_annotation: ^2.4.1     # 不可变数据类
  synchronized: ^3.1.0           # 并发保护
  lava_device_sdk:               # 已验证 SDK（源码在 packages/）
    path: packages/lava_device_sdk
```

---

## 📞 支持

- **快速启动**: `openspec/specs/lava-implementation/README.md`
- **架构疑问**: `docs/superpowers/specs/2026-06-15-lava-architecture-review-qa.md`
- **任务执行**: `openspec/specs/lava-implementation/tasks.md`
- **问题反馈**: GitHub Issues（标签：`implementation`）

---

> ⚡ **TL;DR**: 从 `README.md` 开始 → 读 `proposal.md` 了解决策 → 按 `tasks.md` 实施 → 10 周完成 MVP

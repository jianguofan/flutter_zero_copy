# Lava App 架构实施方案

> 将已验证的 lava-device-controll SDK 集成到企业级 Flutter 应用架构
>
> 作者: Jianguo Fan
> 日期: 2026-06-15
> 状态: 待审批

---

## 背景

我们已经完成了两项关键工作：

1. **架构审查**：对 Lava App 的 ARCHITECTURE.md（2,607 行）进行了 4 视角对抗审查，识别出 25 个问题并提供了修正方案
2. **SDK 验证**：在 `lava-device-controll` 项目中验证了 LAN/WAN 连接策略、MQTT Transport、DeviceHub 统一入口

现在需要将这两者结合，实施一个生产级的 Flutter 应用。

---

## 目标

构建一个企业级 3D 打印机控制 App，支持：
- ✅ LAN 直连设备（MQTT + Moonraker 协议）
- ✅ WAN 云端连接（AWS IoT + TLS 证书）
- ✅ 实时设备状态监控（温度、进度、轴位置）
- ✅ 设备命令控制（打印、暂停、停止）
- ✅ 后台断开 + 前台自动恢复

**时间目标**: 10 周完成 MVP（1-2 开发者）

---

## 核心方案

### 方案概述

**适配器模式集成**：将已验证的 SDK 作为 `IConnection` 接口的一个实现（`LavaSdkConnection`），而不是重写底层连接逻辑。

```
┌──────────────────────────────────────┐
│ UI Layer                             │
│ 依赖: IDeviceFacade                  │
├──────────────────────────────────────┤
│ Domain Layer                         │
│ IDeviceFacade ← UI 只读抽象           │
│ IDeviceSession ← 状态机 Mediator      │
│ IConnection ← 传输层抽象              │
├──────────────────────────────────────┤
│ Data Layer                           │
│ DeviceImpl                           │
│ └─ LavaSdkConnection                 │
│     └─ lava-device-controll SDK      │
│         (已验证，无需重写)             │
└──────────────────────────────────────┘
```

### 关键设计决策

#### 1. SDK 复用而非重写
- **决策**: 将 `lava-device-controll` SDK 完整集成，通过适配器对接架构接口
- **理由**: SDK 已验证 LAN/WAN 连接可行，重写风险高且浪费时间
- **权衡**: 适配器有微小性能开销（<5%），但换来了稳定性和开发速度

#### 2. 引入 IDeviceSession Mediator
- **决策**: 新增 `IDeviceSession` 作为 Registry 和 Connection 的编排者
- **理由**: 原架构中两个接口都暴露 `activeDevice` 导致职责不清，容易竞态
- **权衡**: 多一层抽象，但状态机变得可测试、可穷举

#### 3. 8 态连接状态机
- **决策**: 从原来的 3 态扩展到 8 态（idle/connecting/handshaking/reconnecting/connected/degraded/disconnected/failed）
- **理由**: 移动端需要更细粒度的状态（弱网、重连中）来优化用户体验
- **权衡**: 实现复杂度增加，但 UI 可以给出更精准的提示

#### 4. Phase 1 仅 Moonraker 协议
- **决策**: Phase 1 只支持 Moonraker + MQTT，WCP 延后到 Phase 2
- **理由**: 降低初期复杂度，尽快验证架构可行性
- **权衡**: Phase 1 不支持 Orca 设备，但架构已预留扩展点

---

## 实施路线

### Phase 0: 环境准备（1 周）
- 项目初始化 + CI/CD
- SDK 集成验证
- 依赖项安装

### Phase 1: 核心基础设施（4 周）
- Week 1: Shared Kernel（Logger/Storage/DI/Router/Http）
- Week 2: Device Domain 层（接口定义 + 测试）
- Week 3: Device Data 层（适配器 + 聚合根 + 仓储）
- Week 4: Device Provider 层（Riverpod 状态管理）

### Phase 2: UI 层（2 周）
- Week 5: 设备列表页 + 卡片组件
- Week 6: 设备详情页 + 发现页

### Phase 3: 集成与优化（2 周）
- Week 7: 后台处理 + 错误处理
- Week 8: 性能优化 + E2E 测试

### Phase 4: 发布准备（1 周）
- Week 9-10: macOS 打包 + 内部测试

---

## 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| SDK 适配器性能不足 | 中 | 高 | Phase 1 做基准测试，延迟 <500ms 可接受 |
| 后台断开恢复体验 | 高 | 中 | 实现 <2s 快速重连 + 加载动画 |
| 时间估算过于乐观 | 高 | 高 | 每个 Phase 预留 20% buffer |
| MQTT QoS 1 消息堆积 | 中 | 中 | 实现背压策略（throttle/debounce） |
| 状态机实现复杂 | 中 | 中 | 使用 Sealed Class + 穷举测试 |

---

## 验收标准

### 功能完整性
- [x] LAN 单设备连接 + 实时监控
- [x] WAN 单设备连接 + 云端绑定
- [x] 8 态连接状态可视化
- [x] 后台断开 + 前台恢复
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

### 文档
- [x] 架构文档（更新 ARCHITECTURE.md）
- [x] API 文档（dartdoc）
- [x] 用户手册
- [x] 开发者指南

---

## Non-goals

本方案 **不包含** 以下内容（延后到后续 Phase）：

- ❌ WCP 协议支持（Phase 2）
- ❌ 多设备群控（Phase 2+）
- ❌ OAuth 认证（Phase 2）
- ❌ 离线模式（Phase 3）
- ❌ 数据可视化（实时曲线图）（Phase 3）
- ❌ 国际化 i18n（Phase 3）
- ❌ 推送通知（Phase 3）

---

## 关键里程碑

| 里程碑 | 日期 | 交付物 |
|--------|------|--------|
| M0: 环境就绪 | Week 1 | 项目结构 + SDK 集成 + CI |
| M1: 基础设施完成 | Week 5 | Shared Kernel + Device Domain/Data/Provider 层 |
| M2: UI 完成 | Week 7 | 设备列表/详情/发现页 |
| M3: 集成完成 | Week 9 | 后台处理 + 错误处理 + 性能优化 |
| M4: MVP 发布 | Week 10 | macOS 桌面端 + 内部测试 |

---

## 成功标准

### 技术成功
- ✅ 架构审查中的 25 个问题全部修正
- ✅ SDK 成功集成到 Clean Architecture 分层结构
- ✅ 所有测试通过，覆盖率达标
- ✅ 性能指标满足要求

### 业务成功
- ✅ 10 周内交付可演示的 MVP
- ✅ 支持内部测试人员日常使用
- ✅ 为 Phase 2（WCP + 群控）打下坚实基础

---

## 依赖与假设

### 依赖
- `lava-device-controll` SDK 保持稳定（API 不大改）
- 至少 1 台真实设备用于测试（Moonraker + MQTT）
- 云端 API 服务可用（WAN 模式）

### 假设
- 开发者熟悉 Flutter + Dart + Riverpod
- 设备固件版本稳定（Moonraker MQTT 接口不变）
- macOS 开发环境已就绪

---

## 后续演进

### Phase 2: 协议扩展（6 周）
- WCP 协议支持（新增 `WsConnection` + `WcpProtocol`）
- 多设备群控（`DeviceGroup` + `GroupCommandExecutor`）
- OAuth 认证（JWT Token 管理）

### Phase 3: 高级功能（4 周）
- 离线模式（本地缓存 + 同步）
- 数据可视化（实时温度曲线、打印进度图）
- 通知系统（本地通知 + 推送）
- 国际化（中英文）

---

## 批准签字

- [ ] 技术负责人: ________________  日期: ______
- [ ] 产品负责人: ________________  日期: ______
- [ ] 项目经理: __________________  日期: ______

---

> 本方案基于架构审查修正方案和已验证的 SDK 编写。
> 如有疑问或建议，请在 GitHub Issues 中讨论。

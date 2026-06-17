# 架构审查文档索引

> 本目录包含设备架构的完整审查报告、代码审查规则和自动化工具

---

## 📚 文档列表

### 核心文档

| 文档 | 用途 | 读者 | 优先级 |
|------|------|------|--------|
| [**EXECUTIVE_SUMMARY.md**](./EXECUTIVE_SUMMARY.md) | 执行摘要，快速了解核心发现 | 所有人 | 🔴 必读 |
| [**DEVICE_ARCHITECTURE.md**](./DEVICE_ARCHITECTURE.md) | 设备架构设计文档 | 架构师、高级开发 | 🟢 参考 |
| [**ARCHITECTURE_REVIEW.md**](./ARCHITECTURE_REVIEW.md) | 完整审查报告 (50+ 页) | 架构师、Tech Lead | 🟡 深入 |
| [**CODE_REVIEW_RULES.md**](./CODE_REVIEW_RULES.md) | 代码审查规则手册 | 所有开发者 | 🔴 必读 |

---

## 🚀 快速开始

### 5 分钟了解核心问题

```bash
# 1. 阅读执行摘要
open docs/architecture/EXECUTIVE_SUMMARY.md

# 2. 运行自动化检查
bash tools/check_architecture.sh
bash tools/check_docs_sync.sh

# 3. 查看当前违规
# - LAYER-01: UI 层直接导入 SDK (2 处)
# - ARCH-01: DeviceMetadataStore 不存在
```

### 30 分钟掌握审查规则

1. 阅读 [CODE_REVIEW_RULES.md](./CODE_REVIEW_RULES.md) 的前 3 部分:
   - 第一部分: 分层规则 (LAYER)
   - 第二部分: 订阅管理规则 (SUB)
   - 第三部分: Provider 规则 (PROV)

2. 在 PR 审查时引用规则 ID:
   ```
   ❌ 违反 LAYER-01: UI 层不得直接导入 SDK
   请参考: docs/architecture/CODE_REVIEW_RULES.md#layer-01
   ```

---

## 🎯 核心发现 (TL;DR)

### 架构成熟度: 6.8/10 (及格但需改进)

| 🔴 严重问题 | 🟡 中等问题 | 🟢 优点 |
|-----------|-----------|--------|
| 文档与代码不一致 | Provider 职责有重叠 | 分层概念清晰 |
| UI 层绕过架构分层 | 缺少订阅规范 | Provider 数量合理 |
| | | 订阅使用克制 |

### 自动化检查结果

```bash
✅ 通过: 11/15 检查项 (73%)
❌ 失败: 1 处架构违规
⚠️  警告: 3 处文档不同步
```

---

## 📋 待办事项

### 本周 (P0 - 必须修复)

- [ ] **修复 LAYER-01 违规**: 删除 UI 层中的 SDK import (2 处)
  - `lib/pages/devices/my_devices_page.dart`
  - `lib/pages/devices/widgets/add_device_dialog.dart`
  
- [ ] **更新架构文档**: 删除 DeviceMetadataStore 相关章节
  - 或者实现它 (需 2-3 天)

- [ ] **迁移状态管理**: 将 `DeviceManagerService` 迁移到 Riverpod

### 本月 (P1 - 应该修复)

- [ ] 删除冗余 Provider (`deviceCountProvider`, `deviceFieldValueProvider`)
- [ ] 补充订阅规范文档
- [ ] 将自动化检查加入 CI/CD

### 后续 (P2 - 可以优化)

- [ ] 添加架构测试
- [ ] 优化字段订阅机制
- [ ] 补充更多 Lint 规则

---

## 🔧 自动化工具

### 架构规则检查

```bash
# 运行所有检查
bash tools/check_architecture.sh

# 检查项:
# - LAYER-01: UI 层不得直接导入 SDK
# - LAYER-03: Provider 不得导入 Flutter UI
# - LAYER-04: 数据层不得导入 Riverpod
# - SUB-01: Timer 必须取消
# - SUB-02: addListener/removeListener 配对
# - SUB-03: StreamSubscription 必须取消
# - PROV-01: Provider 命名约定
```

### 文档同步检查

```bash
# 检查文档与代码一致性
bash tools/check_docs_sync.sh

# 检查项:
# - 文档声明的类是否存在
# - 文档声明的 Provider 是否实现
# - 新增 Provider 是否记录
```

### 集成到 CI

```yaml
# .github/workflows/architecture.yml
name: Architecture Checks
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: bash tools/check_architecture.sh
      - run: bash tools/check_docs_sync.sh
```

---

## 📖 代码审查规则速查

### 分层规则 (LAYER)

| ID | 规则 | 严重性 |
|----|------|--------|
| LAYER-01 | UI 层不得直接导入 SDK | 🔴 |
| LAYER-02 | UI 层不得直接实例化 Service | 🟡 |
| LAYER-03 | Provider 不得导入 Flutter UI | 🟡 |
| LAYER-04 | 数据层不得导入 Riverpod | 🔴 |

### 订阅规则 (SUB)

| ID | 规则 | 严重性 |
|----|------|--------|
| SUB-01 | Timer 必须在 dispose 中取消 | 🔴 |
| SUB-02 | addListener 必须配对 removeListener | 🔴 |
| SUB-03 | StreamSubscription 必须取消 | 🔴 |
| SUB-04 | 单个 Widget 订阅字段 ≤ 5 个 | 🟡 |
| SUB-05 | 优先使用 ref.watch 而非 StreamBuilder | 🟢 |

### Provider 规则 (PROV)

| ID | 规则 | 严重性 |
|----|------|--------|
| PROV-01 | Provider 命名必须以 Provider 结尾 | 🟡 |
| PROV-02 | Provider 不得包含业务逻辑 | 🟡 |
| PROV-03 | 避免 Provider 循环依赖 | 🔴 |
| PROV-04 | Family Provider 必须文档说明参数 | 🟢 |

### 架构一致性 (ARCH)

| ID | 规则 | 严重性 |
|----|------|--------|
| ARCH-01 | 文档声明的类必须存在 | 🔴 |
| ARCH-02 | 核心类职责必须与文档一致 | 🟡 |
| ARCH-03 | 新增 Provider 必须更新文档 | 🟢 |

**完整规则**: [CODE_REVIEW_RULES.md](./CODE_REVIEW_RULES.md)

---

## 💬 FAQ

### Q: 为什么 Provider 数量不算多？

A: 10 个核心 Provider 符合单一职责原则，每个 Provider 职责明确。真正的问题是**职责重叠** (如 `deviceFieldValueProvider` 冗余) 和**缺少规范**。

### Q: 订阅会不会泄漏？

A: 当前代码中订阅管理良好 ✅ (Timer、Listener 都正确取消)。但缺少**代码审查规范**，未来可能退化。

### Q: DeviceMetadataStore 应该实现吗？

A: **方案 A** (推荐): 先删除文档中的相关章节，让文档与代码一致。Store 可以作为下个迭代的重构目标。

**方案 B**: 立即实现 (需 2-3 天)，但要评估 ROI。

### Q: 如何在 PR 中引用规则？

A: 使用规则 ID:
```
❌ 违反 LAYER-01: UI 层不得直接导入 SDK
请参考: docs/architecture/CODE_REVIEW_RULES.md#layer-01
```

### Q: 自动化检查能覆盖所有规则吗？

A: 不能。35+ 条规则中:
- ✅ 7 条可自动化检查 (Lint + 脚本)
- 🔧 5 条可工具辅助
- 👁️ 23 条需人工审查

**最佳实践**: 自动化检查 + 人工审查 + 定期架构审查

---

## 🎓 学习路径

### 初级开发 (Junior Developer)

1. ✅ 阅读 [EXECUTIVE_SUMMARY.md](./EXECUTIVE_SUMMARY.md) (15 分钟)
2. ✅ 学习分层规则 (LAYER-01~05)
3. ✅ 学习订阅规则 (SUB-01~03)
4. ⏭️ 在 PR 中实践

### 中级开发 (Mid-Level Developer)

1. ✅ 完整阅读 [CODE_REVIEW_RULES.md](./CODE_REVIEW_RULES.md) (1 小时)
2. ✅ 学习如何审查他人 PR
3. ✅ 贡献新的 Lint 规则
4. ⏭️ 参与架构审查会议

### 高级开发/架构师 (Senior/Architect)

1. ✅ 深入阅读 [ARCHITECTURE_REVIEW.md](./ARCHITECTURE_REVIEW.md) (2-3 小时)
2. ✅ 评估架构重构方案
3. ✅ 制定架构演进路线图
4. ⏭️ 主持架构审查会议

---

## 📞 联系方式

- **架构问题**: 联系架构团队
- **工具问题**: 提交 Issue
- **规则建议**: 提交 PR 更新 CODE_REVIEW_RULES.md

---

## 📈 持续改进

### 每周
- [ ] 运行自动化检查
- [ ] 修复新发现的违规

### 每月
- [ ] 架构审查会议
- [ ] 更新代码审查规则
- [ ] 评估架构退化

### 每季度
- [ ] 全面架构审查
- [ ] 更新架构文档
- [ ] 评估新技术方案

---

**最后更新**: 2026-06-17  
**下次审查**: 2026-07-17

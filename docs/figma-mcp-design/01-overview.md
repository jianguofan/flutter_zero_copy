# Figma → Flutter MCP Server 设计方案

> 版本: v1.0
> 日期: 2026-06-22
> 状态: 设计阶段

---

## 一、问题定义

使用 Figma MCP 工具生成 Flutter UI 时，还原质量差。根因：

1. **布局模型差异**：Figma 是绝对定位 + Auto Layout，Flutter 是约束传递
2. **像素 vs 逻辑像素**：Figma 画布固定像素，Flutter 需要响应式
3. **设计意图丢失**：Figma API 返回几何数据，不返回「标题/正文/主色」等语义
4. **组件映射缺失**：Figma Component ≠ Flutter Widget，需要建立映射层
5. **LLM 直译惯用**：生成的代码是 Figma JSON 的字面翻译，不 idiomatic

## 二、核心思路

### 2.1 Figma → HTML 可以高质量还原的原因

Figma 和 HTML/CSS 共享同一套布局模型：

| Figma 概念 | CSS 等价 | 关系 |
|-----------|---------|------|
| Auto Layout | Flexbox | 同构 |
| Absolute Position | `position: absolute` | 同构 |
| Text | Web 字体渲染 | 同一引擎 |
| Fills/Strokes/Effects | `background`/`border`/`box-shadow` | 直接映射 |
| Figma 本身 | Canvas + HTML 构建 | Web 技术栈 |

**Figma → HTML 基本是同构映射，不需要翻译，只需要转写。**

### 2.2 Figma → Flutter 存在语义鸿沟

Flutter 的渲染引擎是 Skia/Impeller，布局模型是约束传递，和 Figma 没有同构关系。

**解决方案：建立组件库作为语义桥梁。**

```
Figma 组件  ←→  组件元数据 (TS)  ←→  Flutter 组件实现 (Dart)
                      │
                 MCP Server 匹配引擎
```

## 三、系统形态 & 职责边界

- **类型**：MCP Server（TypeScript/Node.js）
- **调用方**：Claude Code / IDE 通过 MCP 协议调用
- **组件库存储**：和 Flutter 项目在同一 Git 仓库，TS 元数据和 Dart 实现在同一 PR

### MCP Server 负责（样式 & 骨架）

| 职责 | 说明 |
|------|------|
| 结构化 Figma 数据 | 拉取节点树，解析布局和样式 |
| 通用组件匹配 | 匹配 AppButton、AppCard 等跨页面通用组件 |
| 设计令牌提取 | 颜色/字号/间距 → `tokens.dart` |
| 生成 UI 骨架 | Widget 树结构 + 样式属性 + 令牌引用 |
| 后处理验证 | 硬编码检测、响应式检查、导入验证 |

### MCP Server 不碰（留给开发者）

| 不碰 | 说明 |
|------|------|
| 数据绑定 | `temp` 从哪个 Provider 拿 — 不生成 |
| 业务逻辑 | `onTap` 回调里写什么 — 不生成 |
| 状态管理连线 | Riverpod / ViewModel 的初始化 — 不生成 |
| 页面专属 Widget | 只用一次的组件不进库，MCP 生成骨架，你填数据 |

### LLM 职责

- 理解 Figma 设计意图（页面结构、交互模式）
- 匹配通用组件（优先引用已有组件）
- 生成惯用 Dart 骨架代码（响应式、令牌引用）
- 标注 TODO 数据绑定位置（开发者后续填入）

## 四、架构概览

```
Figma API
   │
   ▼
┌──────────────────────────────────────────────────────────┐
│  阶段 1: MCP Server — 智能预处理                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │ • 拉取 Figma JSON，解析节点树                        │  │
│  │ • 提取设计令牌（颜色/字号/间距 → Dart 代码）          │  │
│  │ • 通用组件匹配（仅匹配跨页面复用的 base 组件）         │  │
│  │ • 页面专属区域 → 标注为「骨架生成」，不注册           │  │
│  │ • 生成「增强上下文」：布局描述 + 令牌 + 组件候选       │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────┬───────────────────────────────────┘
                       │  增强上下文
                       ▼
┌──────────────────────────────────────────────────────────┐
│  阶段 2: LLM — 生成 UI 骨架                               │
│  ┌────────────────────────────────────────────────────┐  │
│  │ • 理解设计意图（页面结构、交互模式）                  │  │
│  │ • 通用组件 → 直接生成组件调用代码                     │  │
│  │ • 页面专属区域 → 生成 Container/Row/Column 骨架       │  │
│  │ • 引用设计令牌，避免硬编码                            │  │
│  │ • 数据绑定处标注 // TODO: 绑定数据源                  │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────┬───────────────────────────────────┘
                       │  UI 骨架代码（样式完整，数据留空）
                       ▼
┌──────────────────────────────────────────────────────────┐
│  阶段 3: MCP Server — 后处理 & 验证                       │
│  ┌────────────────────────────────────────────────────┐  │
│  │ • 语法检查 (dart analyze)                            │  │
│  │ • 硬编码检测（颜色/字号/间距的魔法数字）              │  │
│  │ • 响应式检查（固定像素值）                            │  │
│  │ • 导入完整性验证                                      │  │
│  │ • 综合评分 (0-100) + 修正指引                        │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────┬───────────────────────────────────┘
                       │  验证通过的 UI 骨架
                       ▼
              ┌─────────────────┐
              │  开发者          │  ← 填数据绑定、业务逻辑
              │  • 连 Riverpod   │
              │  • 写 onTap 回调 │
              │  • 接 ViewModel  │
              └─────────────────┘
```

## 五、关键设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| IR 中间表示层 | ❌ 不做 | 目标只有 Flutter，IR 多一层就多一层精度损失 |
| 仓库策略 | 同仓库 | TS 元数据和 Dart 实现在同一 PR，不会不同步 |
| 组件库格式 | 纯 TypeScript | 全栈 TS，类型安全，编辑器补全 |
| MCP Server 语言 | TypeScript/Node.js | MCP 官方 SDK 最成熟 |
| 组件定义 | TS 对象字面量 | 不用 YAML/JSON，直接类型约束 |
| MCP 产出物 | UI 骨架，非完整应用 | 样式 + 布局 + 令牌引用；数据绑定和业务逻辑留给开发者 |
| 组件库范围 | 仅通用 base 组件 | 跨页面复用的才注册；页面专属 Widget 不进库，直接生成骨架 |

### 产出物示例

MCP 生成的代码长这样：

```dart
// 由 MCP 生成 — UI 骨架 + 样式完整
class DeviceControlPage extends StatelessWidget {
  const DeviceControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,          // ← 令牌引用
      child: Row(
        children: [
          Container(
            width: 262,                     // ← Figma 尺寸（后续改为响应式）
            color: AppColors.surface,
            child: Column(
              children: [
                AppButton(                   // ← 匹配到通用组件
                  label: '设备控制',
                  variant: AppButtonVariant.primary,
                  onTap: () {},             // TODO: 绑定业务逻辑
                ),
                // ... 其他骨架
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

开发者拿到后做的事：
- `onTap: () {}` → 填入实际导航/操作逻辑
- 页面专属区域的 Container/Row/Column → 替换为实际业务 Widget
- 固定 `width: 262` → 改为 `LayoutBuilder` 或 `ConstrainedBox`
- 接入 Riverpod provider

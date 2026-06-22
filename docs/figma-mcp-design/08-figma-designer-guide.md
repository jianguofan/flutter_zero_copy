# Section 8: Figma 设计师规范

## 8.1 为什么要规范

MCP Server 做 Figma → Flutter 转换时，**设计师的 Figma 文件质量直接决定转换质量**。

| 设计师做法 | 转换效果 |
|-----------|---------|
| 用 Figma Component + 规范命名 | 匹配率 80-95%，直接生成组件调用代码 |
| 裸 Frame + 随意命名 | 匹配率 20-40%，生成一坨 Container |
| 使用 Figma Color/Text Styles | 令牌直接用设计师命名，100% 准确 |
| 逐元素手调颜色 | 靠聚类算法猜语义，名字可能不对 |

## 8.2 五条硬规则

### 规则 1：必须用 Figma Component

```
✅ 正确：
  创建 Component "Button/Primary"
  所有按钮都用它的 Instance

❌ 错误：
  画一个 Frame → 放 Rectangle + Text → 看起来像按钮但不是
```

**原因**：Component Instance 有 `componentId`，MCP 可以直接拿到名称去匹配。裸 Frame 只能靠视觉特征猜。

### 规则 2：组件命名用 `类别/变体` 层级

```
✅ Button/Primary
✅ Button/Secondary
✅ Card/Device
✅ Card/Project
✅ Input/Text
✅ Input/Number
✅ Dialog/Confirm
✅ TabBar/Standard

❌ button1, button2, 按钮
❌ Frame 123, Group 456
❌ Rectangle 789
```

**命名即文档**。MCP 的匹配引擎用名称做第一轮召回，名称越规范，匹配越准。

### 规则 3：用 Auto Layout，不要拖拽自由定位

```
✅ Frame 设为 Auto Layout (Horizontal / Vertical)
✅ 用 padding 和 gap (itemSpacing) 控制间距
✅ 用 Hug / Fill 控制尺寸自适应

❌ 子元素用鼠标随意拖动定位
❌ 用 x/y 坐标手动布局
```

**原因**：Auto Layout 可以直接映射为 Flutter Row/Column。绝对定位需要 LLM 推断布局意图，准确率大幅下降。

### 规则 4：颜色和文字用 Figma Styles

```
✅ Color Styles:
   primary/500    →  #00D4AA
   primary/300    →  #33DDBB
   text/primary   →  #E0E0E0
   text/secondary →  #888888
   bg/dark        →  #1A1A2E
   bg/surface     →  #16213E

✅ Text Styles:
   heading/large  →  fontSize: 24, weight: 600
   heading/medium →  fontSize: 20, weight: 600
   body/large     →  fontSize: 16, weight: 400
   body/medium    →  fontSize: 14, weight: 400
   label/small    →  fontSize: 12, weight: 400

❌ 每个元素手动调色值
❌ 每个文字单独改字号
```

**原因**：Figma Styles 通过 API 返回名称，令牌提取直接使用设计师的命名。手动调色的 hex 值需要聚类算法猜语义，名字不保证准确。

### 规则 5：控制字号+字重组合数量

```
✅ 一套设计稿用 5-6 个 Typography token
✅ 每个 token 出现 ≥3 次

❌ 一套设计稿出现 12 种不同的字号
❌ 某些字号只用了一次
```

**原因**：出现次数 < 3 的字号不会被提取为令牌，会被当作一次性样式硬编码到代码里。

## 8.3 推荐工作流

### 方案：Figma 模板文件

最好的落地方式是给设计师一个 **Figma 模板文件**，预置了：

```
📁 Template.fig
├── 🎨 Color Styles (已命名)
│   ├── primary/500
│   ├── text/primary
│   ├── bg/dark
│   └── ...
├── 🔤 Text Styles (已命名)
│   ├── heading/large
│   ├── body/medium
│   └── ...
└── 🧩 Components (示范)
    ├── Button/Primary
    ├── Button/Secondary
    ├── Card/Default
    └── Input/Text
```

设计师基于模板开工，天然符合所有规范。不需要背规则。

### 组件分层命名建议

```
Button/           → 按钮类
  Primary
  Secondary
  Outline
  Ghost

Card/             → 卡片类
  Default
  Elevated
  Outlined

Input/            → 输入类
  Text
  Number
  Search

Dialog/           → 对话框类
  Confirm
  Alert
  BottomSheet

Tab/              → 标签类
  Standard
  Underlined
```

## 8.4 现有文件的渐进改进

不需要一次性重构整个 Figma 文件。按页面逐步改：

1. **新建页面时**：严格按规范
2. **修改旧页面时**：顺手把用到的元素改为 Component
3. **发现裸 Frame 被多处使用时**：提为 Component，命名，替换所有 Instance

## 8.5 和开发者协作

```
设计师                         开发者
───────                        ──────
创建 Figma Component ──────→ MCP 匹配引擎匹配到
                                   │
                                   ▼
                              如果匹配成功 → 直接生成组件调用
                              如果匹配失败 → 评估是否值得注册
                                   │
                                   ├─ 值得：写 .ts 映射 + 通知设计师命名要规范
                                   └─ 不值得：当页面专属处理
```

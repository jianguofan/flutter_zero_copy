# Section 3: 组件匹配引擎

## 3.1 整体流水线

```
Figma Node
    │
    ▼
┌──────────────┐
│ 1. 类型分类   │  判断节点类型：Component Instance / Frame / Text / Rectangle / Group
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ 2. 候选召回   │  从组件注册表粗筛候选集（名称通配 + 类型过滤）
└──────┬───────┘
       │  候选集 (通常 2-5 个)
       ▼
┌──────────────┐
│ 3. 多维打分   │  对每个候选：名称分 (0.35) + 结构分 (0.40) + 样式分 (0.25)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ 4. 决策       │  最高分 > 0.65 → 匹配成功；否则 → fallback
└──────┬───────┘
       │
       ├── matched → 输出组件名 + 推荐的 props 值
       └── unmatched → 输出「最接近的组件」+ 手写提示
```

## 3.2 类型分类

```typescript
// matcher.ts

type FigmaNodeType = 'COMPONENT_INSTANCE' | 'FRAME' | 'TEXT' | 'RECTANGLE' | 'VECTOR' | 'GROUP';

interface ClassifiedNode {
  nodeId: string;
  nodeName: string;
  type: FigmaNodeType;

  // Component Instance 专属
  componentName?: string;        // e.g. "Button/Primary"
  componentId?: string;
  variantProperties?: Record<string, string>;  // e.g. { variant: "primary", size: "medium" }

  // 结构特征
  childCount: number;
  hasText: boolean;
  hasIcon: boolean;
  layoutMode?: 'HORIZONTAL' | 'VERTICAL' | 'NONE';

  // 样式特征
  fills: Fill[];
  cornerRadius: number;
  hasShadow: boolean;
  width: number;
  height: number;
  textContent?: string;      // 仅 TEXT 类型
  fontSize?: number;         // 仅 TEXT 类型
  fontWeight?: number;       // 仅 TEXT 类型
}
```

**Component Instance 是匹配率最高的**——Figma 里用了「Button/Primary」组件，名称可以直接匹配。

## 3.3 候选召回

用名称做第一轮粗筛，支持通配符：

```typescript
function recallCandidates(
  node: ClassifiedNode,
  registry: ComponentDefinition[]
): ComponentDefinition[] {
  let candidates: ComponentDefinition[] = [];

  // 策略 1：精确名称匹配（Figma Component Instance）
  if (node.componentName) {
    const exact = registry.filter(c =>
      c.figmaMatch.componentNames.some(pattern =>
        matchGlob(pattern, node.componentName!)
      )
    );
    if (exact.length > 0) return exact;
  }

  // 策略 2：节点名称拆词匹配（Frame 没绑定 Component 的情况）
  const nodeTokens = tokenize(node.nodeName);  // "DeviceCard" → ["device", "card"]
  candidates = registry.filter(c => {
    const componentTokens = tokenize(c.name);
    return jaccardSimilarity(nodeTokens, componentTokens) > 0.4;
  });

  // 策略 3：按视觉特征召回（同布局方向、同子节点数级别）
  if (candidates.length === 0) {
    candidates = registry.filter(c => {
      const f = c.figmaMatch.visualFeatures;
      if (node.layoutMode === 'HORIZONTAL' && f.minChildren && f.minChildren > 1) return true;
      if (node.layoutMode === 'VERTICAL' && f.hasText) return true;
      if (f.borderRadius?.some(r => Math.abs(r - node.cornerRadius) < 4)) return true;
      return false;
    });
  }

  return candidates.slice(0, 5);  // 最多 5 个候选
}
```

## 3.4 多维打分

```typescript
interface MatchScore {
  nameScore: number;      // 0-1 名称相似度（权重 0.35）
  structureScore: number; // 0-1 结构相似度（权重 0.40）
  styleScore: number;     // 0-1 样式相似度（权重 0.25）
  total: number;          // 加权总分
}

function scoreCandidate(node: ClassifiedNode, component: ComponentDefinition): MatchScore {
  const f = component.figmaMatch.visualFeatures;

  // ── 名称分 (0.35) ──
  const nameScore = node.componentName
    ? computeGlobScore(node.componentName, component.figmaMatch.componentNames)
    : diceCoefficient(tokenize(node.nodeName), tokenize(component.name));

  // ── 结构分 (0.40) ──
  let structureScore = 0;
  // 子节点数在范围内 → +0.3
  if (node.childCount && f.minChildren && f.maxChildren) {
    if (node.childCount >= f.minChildren && node.childCount <= f.maxChildren)
      structureScore += 0.3;
  }
  if (f.hasText === node.hasText) structureScore += 0.3;
  if (f.hasIcon === 'always' && node.hasIcon) structureScore += 0.2;
  if (f.hasIcon === 'never' && !node.hasIcon) structureScore += 0.2;
  if (f.hasIcon === 'optional') structureScore += 0.2;  // optional 不扣分
  // Figma Variant 属性匹配
  if (node.variantProperties) {
    const matchedProps = component.props.filter(p =>
      p.type === 'enum' && node.variantProperties![p.name]
    ).length;
    const totalVariantKeys = Object.keys(node.variantProperties).length;
    structureScore += (matchedProps / Math.max(totalVariantKeys, 1)) * 0.2;
  }

  // ── 样式分 (0.25) ──
  let styleScore = 0;
  if (f.borderRadius) {
    if (f.borderRadius.some(r => Math.abs(r - node.cornerRadius) <= 2))
      styleScore += 0.5;
  }
  if (node.hasShadow && component.props.some(p => p.name === 'elevation'))
    styleScore += 0.3;
  if (node.fills.length === 1 && node.fills[0].type === 'SOLID') {
    if (component.props.some(p => p.name === 'color' || p.name === 'backgroundColor'))
      styleScore += 0.2;
  }

  return {
    nameScore,
    structureScore,
    styleScore,
    total: nameScore * 0.35 + structureScore * 0.40 + styleScore * 0.25,
  };
}
```

## 3.5 决策与 Fallback

```typescript
const MATCH_THRESHOLD = 0.65;

function decide(node: ClassifiedNode, candidates: ComponentDefinition[]): MatchResult {
  if (candidates.length === 0) {
    return { nodeId: node.nodeId, matched: false, fallback: createGenericFallback(node) };
  }

  const scored = candidates
    .map(c => ({ component: c, score: scoreCandidate(node, c) }))
    .sort((a, b) => b.score.total - a.score.total);

  const best = scored[0];

  if (best.score.total >= MATCH_THRESHOLD) {
    return {
      nodeId: node.nodeId,
      matched: true,
      component: best.component,
      score: best.score,
      recommendedProps: deriveProps(node, best.component),
    };
  }

  return {
    nodeId: node.nodeId,
    matched: false,
    fallback: {
      closestComponent: best.component,
      similarity: best.score.total,
      reason: `总分 ${best.score.total.toFixed(2)} < 阈值 ${MATCH_THRESHOLD}`,
      manualHint: buildManualHint(node, best.component),
    },
  };
}
```

## 3.6 Props 值推导

匹配到组件后，自动从 Figma 数据推导 Flutter props 值：

```typescript
function deriveProps(node: ClassifiedNode, component: ComponentDefinition): Record<string, any> {
  const props: Record<string, any> = {};

  for (const prop of component.props) {
    switch (prop.name) {
      case 'variant':
        if (node.variantProperties?.variant) props.variant = node.variantProperties.variant;
        break;
      case 'size':
        if (node.variantProperties?.size) props.size = node.variantProperties.size;
        break;
      case 'label':
        if (node.textContent) props.label = node.textContent;
        break;
      case 'elevation':
        if (node.hasShadow) props.elevation = 2;
        break;
      case 'width':
        props.width = node.width;
        break;
      case 'height':
        props.height = node.height;
        break;
    }
  }

  return props;
}
```

**示例**：

```
Figma: Button/Primary Instance, variant=primary, text="确 定"

deriveProps 输出:
{ label: "确定", variant: "primary", size: "medium" }

LLM 生成:
AppButton(
  label: '确定',
  variant: AppButtonVariant.primary,
  size: AppButtonSize.medium,
  onTap: () {},     // LLM 自己填
)
```

## 3.7 Fallback 提示

没匹配到的节点，给 LLM 提供充足的上下文：

```typescript
function buildManualHint(node: ClassifiedNode, closest: ComponentDefinition): string {
  return `
## 节点 "${node.nodeName}" 未匹配到已有组件

### 视觉特征
- 类型: ${node.type}
- 尺寸: ${node.width}×${node.height}
- 布局: ${node.layoutMode === 'HORIZONTAL' ? 'Row' : node.layoutMode === 'VERTICAL' ? 'Column' : '自由布局'}
- 子节点数: ${node.childCount}
- 包含文字: ${node.hasText ? '是' : '否'}
- 包含图标: ${node.hasIcon ? '是' : '否'}
- 圆角: ${node.cornerRadius}px
- 阴影: ${node.hasShadow ? '有' : '无'}

### 最接近的已有组件
- ${closest.name} (相似度 ${Math.round(closest.figmaMatch.minSimilarity * 100)}%)
- 所需参数: ${closest.props.filter(p => p.required).map(p => p.name).join(', ')}

### 生成建议
1. 如果是简单布局容器 → 直接用 Row/Column + Container
2. 如果是可复用模式 → 考虑新增到 component-library/business/
3. 参考下方 Figma 节点详情中的完整样式数据
`;
}
```

## 3.8 匹配范围限定

**匹配引擎只匹配 base 通用组件。** 页面专属区域（如 CameraPanel、PrintTaskView）不参与匹配，直接走骨架生成路径。

```typescript
// matcher.ts — 匹配前先过滤：只有 base 组件参与匹配
function matchNode(node: ClassifiedNode, registry: ComponentDefinition[]): MatchResult {
  // 只匹配通用 base 组件
  const baseComponents = registry.filter(c => c.category === 'base');

  if (baseComponents.length === 0) {
    return {
      nodeId: node.nodeId,
      matched: false,
      fallback: {
        reason: '页面专属区域，不在通用组件库中',
        manualHint: 'LLM 生成 Container/Row/Column 骨架，开发者替换为实际业务 Widget',
      },
    };
  }

  // ... 后续候选召回 + 打分逻辑不变
}
```

## 3.9 目标指标

Component Instance 的匹配率取决于 Figma 设计师用了多少已注册的通用组件。

| 场景 | 典型匹配率 |
|------|-----------|
| Figma 中大量使用 Component Instance + 通用组件已注册 | 80-95% |
| Figma 中大部分是裸 Frame | 20-40% |
| 页面专属业务组件（不进库） | 0%（预期行为，走骨架生成） |

**覆盖率不是 100% 才是正常状态。** 页面专属组件被正确标记为 unmatched → LLM 生成骨架 → 开发者填充，这是设计意图。

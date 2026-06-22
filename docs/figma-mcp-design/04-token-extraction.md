# Section 4: 设计令牌提取算法

## 4.1 整体流程

完全确定性模块——统计聚类 + 启发式规则，输出可直接保存到 Flutter 项目的 Dart 文件。

```
Figma 节点树（全量遍历）
    │
    ├──→ 收集所有 fills[].color        ──→ 颜色量化 + 聚类  ──→ AppColors
    ├──→ 收集所有 TEXT.fontSize        ──→ 字号 ±1px 聚类   ──→ AppTypography
    ├──→ 收集所有 AutoLayout gap/padding ─→ 间距 ±1px 聚类  ──→ AppSpacing
    └──→ 收集所有 cornerRadius         ──→ 圆角 ±1px 聚类   ──→ AppRadius
                                              │
                                              ▼
                                    tokens.dart（可直接保存）
```

## 4.2 颜色令牌提取

### 数据结构

```typescript
interface ColorEntry {
  hex: string;           // "#00D4AA"
  r: number; g: number; b: number;
  opacity: number;
  source: string;        // "fill" | "stroke" | "effect" | "text"
  nodeType: string;      // "FRAME" | "TEXT" | "RECTANGLE"
  usageCount: number;
  areaRatio?: number;    // 在画布中的面积占比（越大越可能是背景色）
}

interface ExtractedColor {
  name: string;          // e.g. "primaryCyan"
  hex: string;
  usageCount: number;
  semanticRole: 'primary' | 'background' | 'surface' | 'text' | 'border' | 'accent' | 'unknown';
}
```

### 聚类算法

```typescript
function extractColors(nodes: FigmaNode[]): ExtractedColor[] {
  const entries = collectColorEntries(nodes);  // 全量收集

  // 步骤 1：量化到 16 进制，容忍 ±2 的 RGB 通道差异
  const quantized = quantizeColors(entries, { tolerance: 2 });
  // #00D4AB vs #00D4AA → 合并为 #00D4AA

  // 步骤 2：按出现次数排序，只保留出现 ≥3 次的颜色
  const frequent = quantized.filter(c => c.usageCount >= 3);

  // 步骤 3：语义角色推断 + 命名
  return frequent.map(c => ({
    hex: c.hex,
    usageCount: c.usageCount,
    semanticRole: inferColorRole(c, entries.length),
    name: generateColorName(c),
  }));
}
```

### 语义角色推断规则

```typescript
function inferColorRole(c: ColorEntry, totalEntries: number): ExtractedColor['semanticRole'] {
  // 面积最大的填充色 → 背景色
  if (c.source === 'fill' && c.nodeType === 'FRAME' && c.areaRatio && c.areaRatio > 0.3) {
    return 'background';
  }
  // 出现在文字节点上的 → 文字色
  if (c.nodeType === 'TEXT') {
    return 'text';
  }
  // 出现在 stroke 上的 → 边框色
  if (c.source === 'stroke') {
    return 'border';
  }
  // 色相偏暖（橙/红）且饱和度高 → accent
  if (isWarmColor(c) && saturation(c) > 0.5) {
    return 'accent';
  }
  // 出现频率最高的非背景填充色 → 主色
  if (c.usageCount / totalEntries > 0.1) {
    return 'primary';
  }
  // Frame 填充但不是背景 → surface
  if (c.nodeType === 'FRAME' && c.source === 'fill') {
    return 'surface';
  }
  return 'unknown';
}
```

### 命名生成

```
role=primary     → primaryCyan (附加色相描述)
role=background  → backgroundDark / backgroundLight（按亮度）
role=text        → textPrimary / textSecondary（最暗的是 primary）
role=surface     → surfaceCard / surfacePanel
role=border      → borderDefault
role=accent      → accentOrange
```

## 4.3 字号令牌提取

### 数据结构

```typescript
interface FontEntry {
  fontSize: number;
  fontWeight: number;
  lineHeight: number;    // lineHeightPx / fontSize
  fontFamily: string;
  usageCount: number;
  contexts: string[];    // 如 ["PageTitle", "CardTitle", "Body"]
}
```

### 聚类逻辑

```typescript
function extractTypography(nodes: FigmaNode[]): ExtractedTypography[] {
  const textNodes = findTextNodes(nodes);
  const entries: FontEntry[] = [];

  for (const node of textNodes) {
    const existing = entries.find(e =>
      Math.abs(e.fontSize - node.style.fontSize) <= 1 &&  // 20px vs 19px → 合并
      e.fontWeight === node.style.fontWeight
    );
    if (existing) {
      existing.usageCount++;
      existing.contexts.push(node.name);
    } else {
      entries.push({
        fontSize: node.style.fontSize,
        fontWeight: node.style.fontWeight,
        lineHeight: node.style.lineHeightPx / node.style.fontSize,
        fontFamily: node.style.fontFamily,
        usageCount: 1,
        contexts: [node.name],
      });
    }
  }

  // 出现 ≥2 次才视为令牌
  return entries.filter(e => e.usageCount >= 2).map(e => ({
    name: inferTypeName(e),
    fontSize: e.fontSize,
    fontWeight: e.fontWeight,
    lineHeight: e.lineHeight,
    usageCount: e.usageCount,
  }));
}
```

### 语义命名推断（参考 Material Design 3 命名习惯）

```typescript
function inferTypeName(e: FontEntry): string {
  const contexts = e.contexts.join(' ').toLowerCase();

  if ((contexts.includes('headline') || contexts.includes('title')) && e.fontSize >= 24)
    return 'headlineLarge';
  if (contexts.includes('headline') && e.fontSize >= 20)
    return 'headlineMedium';
  if (contexts.includes('title') && e.fontSize >= 18)
    return 'titleLarge';
  if (contexts.includes('title'))
    return 'titleMedium';
  if (contexts.includes('body') || contexts.includes('content'))
    return e.fontSize >= 14 ? 'bodyLarge' : 'bodyMedium';
  if (contexts.includes('label') || contexts.includes('caption'))
    return e.fontSize >= 12 ? 'labelLarge' : 'labelSmall';

  // Fallback：按字号大小排序
  if (e.fontSize >= 24) return 'headlineLarge';
  if (e.fontSize >= 20) return 'headlineMedium';
  if (e.fontSize >= 16) return 'titleMedium';
  if (e.fontSize >= 14) return 'bodyLarge';
  if (e.fontSize >= 12) return 'bodyMedium';
  return 'labelSmall';
}
```

## 4.4 间距令牌提取

```typescript
function extractSpacing(nodes: FigmaNode[]): ExtractedSpacing[] {
  const entries = collectSpacingEntries(nodes);
  // 来源: AutoLayout.itemSpacing, paddingTop/Bottom/Left/Right

  // 聚类：公差 ±1px
  const clusters = clusterByValue(entries, 1);

  // 同一值出现 ≥3 次
  const frequent = clusters.filter(c => c.usageCount >= 3);

  // 按值从小到大排序，分配名字
  frequent.sort((a, b) => a.value - b.value);

  const names = ['xs', 'sm', 'md', 'lg', 'xl', 'xxl'];
  return frequent.slice(0, 6).map((c, i) => ({
    name: names[i],
    value: c.value,
    usageCount: c.usageCount,
  }));
}
```

**典型输出**：

| name | value | usageCount | 含义 |
|------|-------|------------|------|
| xs | 4 | 8 | 紧凑间距 |
| sm | 6 | 34 | 默认组件间距 |
| md | 12 | 15 | 区块内间距 |
| lg | 24 | 7 | 区块间距 |

## 4.5 圆角令牌提取

```typescript
function extractBorderRadius(nodes: FigmaNode[]): ExtractedRadius[] {
  const entries = collectCornerRadii(nodes);
  const clusters = clusterByValue(entries, 1);
  const frequent = clusters.filter(c => c.usageCount >= 2);
  frequent.sort((a, b) => a.value - b.value);
  return frequent.map((c, i) => ({
    name: ['sm', 'md', 'lg', 'xl'][i] || `r${c.value}`,
    value: c.value,
    usageCount: c.usageCount,
  }));
}
```

## 4.6 输出：直接可用的 Dart 代码

```typescript
function generateDartTokens(
  colors: ExtractedColor[],
  typography: ExtractedTypography[],
  spacing: ExtractedSpacing[],
  radius: ExtractedRadius[],
): string {
  return `// 此文件由 figma-flutter-mcp 自动生成（figma_extract_tokens）
// ⚠️ 请勿手动编辑，如需修改请在 Figma 中更新设计稿后重新提取
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
${colors.map(c => `  /// ${c.semanticRole} — 使用 ${c.usageCount} 次
  static const ${c.name} = Color(0xFF${c.hex.replace('#', '')});
`).join('\n')}
}

class AppTypography {
  AppTypography._();
${typography.map(t => `  /// 使用 ${t.usageCount} 次
  static const ${t.name} = TextStyle(
    fontSize: ${t.fontSize},
    fontWeight: FontWeight.w${Math.round(t.fontWeight / 100)}00,
    height: ${t.lineHeight.toFixed(2)},
  );
`).join('\n')}
}

class AppSpacing {
  AppSpacing._();
${spacing.map(s => `  /// 使用 ${s.usageCount} 次
  static const double ${s.name} = ${s.value}.0;
`).join('\n')}
}

class AppRadius {
  AppRadius._();
${radius.map(r => `  /// 使用 ${r.usageCount} 次
  static const double ${r.name} = ${r.value}.0;
`).join('\n')}
}
`;
}
```

## 4.7 和 Figma Styles API 的关系

如果设计师使用了 Figma 官方的 Styles 系统（Color Styles / Text Styles），优先使用：

```typescript
async function extractTokensWithStyles(fileKey: string, token: string) {
  // 方法 1：Figma Styles API（权威数据源）
  const styles = await figmaApi.getFileStyles(fileKey);  // GET /v1/files/:key/styles

  // 方法 2：遍历节点统计（补充未用 Styles 的值）
  const extracted = extractFromNodes(nodes);

  // 合并策略：
  // - Figma Styles 中有定义的 → 优先使用，名称直接用设计师的命名（最准）
  // - Figma Styles 中没有的 → 用聚类算法补充（次优但可用）
  return mergeTokens(styles, extracted);
}
```

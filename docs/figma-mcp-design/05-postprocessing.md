# Section 5: 后处理 & 验证

## 5.1 验证流水线

```
生成的 Dart 代码
    │
    ├──→ 5.2 语法检查     dart analyze 调用，阻塞，必须零错误
    ├──→ 5.3 硬编码检测   扫描颜色/字号/间距的魔法数字
    ├──→ 5.4 响应式检查   检测固定像素宽高
    ├──→ 5.5 导入检查     验证组件引用有对应 import
    ├──→ 5.6 令牌使用分析  哪些令牌被引用了，哪些闲置了
    └──→ 5.7 综合评分     加权计算 → 质量报告
              │
              ▼
        验证报告 → 反馈给 LLM 修正 → 再次验证 → 通过（分数 ≥ 85）
```

## 5.2 语法检查

调 `dart analyze` 做编译级验证：

```typescript
import { execSync } from 'child_process';

interface SyntaxResult {
  ok: boolean;
  errors: Array<{
    severity: 'error' | 'warning' | 'info';
    file: string;
    line: number;
    col: number;
    message: string;
    code: string;
  }>;
}

function validateSyntax(code: string, projectPath: string): SyntaxResult {
  // 写入临时文件
  const tmpDir = path.join(projectPath, '.figma-flutter-tmp');
  const tmpFile = path.join(tmpDir, '_generated.dart');
  fs.mkdirSync(tmpDir, { recursive: true });
  fs.writeFileSync(tmpFile, code);

  // 跑 dart analyze
  try {
    execSync(`cd ${projectPath} && dart analyze ${tmpFile} 2>&1`, {
      encoding: 'utf-8',
      timeout: 30000,
    });
    return { ok: true, errors: [] };
  } catch (e: any) {
    const errors = parseDartAnalyzeOutput(e.stdout || e.stderr);
    return { ok: errors.filter(e => e.severity === 'error').length === 0, errors };
  }
}
```

**为什么用 `dart analyze` 而不用 `dart format`？**
- `dart format` 只做格式化，不检查语义错误
- `dart analyze` 会发现：类型不匹配、缺少 import、未定义变量、override 错误等

## 5.3 硬编码检测

**这是最能提升代码质量的一项检查**。生成的代码最大的问题就是把 Figma 的像素值、颜色值直接写死。

### 数据结构

```typescript
interface HardcodedIssue {
  type: 'HARDCODED_COLOR' | 'HARDCODED_SIZE' | 'HARDCODED_SPACING' | 'HARDCODED_RADIUS' | 'HARDCODED_TYPOGRAPHY';
  line: number;
  col: number;
  snippet: string;         // 原始代码片段
  value: string;           // 检测到的值
  suggestion: string;      // 建议替换为
  severity: 'error' | 'warning';
}
```

### 检测规则表

```typescript
const HARDCODED_RULES = [
  // 规则 1：硬编码颜色值
  {
    pattern: /Color\(0x[0-9A-Fa-f]{8}\)/g,
    type: 'HARDCODED_COLOR',
    severity: 'error',
    getSuggestion: (match: string) => {
      const hex = match.match(/0x([0-9A-Fa-f]{8})/)![1];
      const token = findTokenByColor(hex);
      return token
        ? `替换为 AppColors.${token.name}`
        : `将此颜色添加到 AppColors 类中`;
    },
  },

  // 规则 2：固定宽高 > 50px（小于 50 可能是图标尺寸，允许）
  {
    pattern: /width:\s*(\d{2,})/g,
    type: 'HARDCODED_SIZE',
    severity: 'warning',
    getSuggestion: (_, value) => {
      const num = parseInt(value);
      return num > 50
        ? `建议改用 LayoutBuilder / MediaQuery / ConstrainedBox 或 AppSizing 常量`
        : null;
    },
  },

  // 规则 3：SizedBox 中的魔法间距（排除 0）
  {
    pattern: /SizedBox\((?:width|height):\s*([1-9]\d*)\)/g,
    type: 'HARDCODED_SPACING',
    severity: 'warning',
    getSuggestion: (_, value) => {
      const spacing = findTokenBySpacing(parseInt(value));
      return spacing ? `替换为 AppSpacing.${spacing.name}` : null;
    },
  },

  // 规则 4：EdgeInsets 中的魔法数字（排除 0）
  {
    pattern: /EdgeInsets\.(?:all|only|symmetric|fromLTRB)\([^)]*?([1-9]\d*)[^)]*?\)/g,
    type: 'HARDCODED_SPACING',
    severity: 'warning',
    getSuggestion: (match: string) => {
      const nums = match.match(/\d+/g)?.filter(n => n !== '0');
      if (!nums) return null;
      return `检查间距值 [${nums.join(', ')}]，建议使用 AppSpacing 常量`;
    },
  },

  // 规则 5：硬编码圆角
  {
    pattern: /BorderRadius\.(?:circular|only)\([^)]*?([1-9]\d*)[^)]*?\)/g,
    type: 'HARDCODED_RADIUS',
    severity: 'warning',
    getSuggestion: (_, value) => {
      const radius = findTokenByRadius(parseInt(value));
      return radius ? `替换为 AppRadius.${radius.name}` : null;
    },
  },

  // 规则 6：内联 TextStyle
  {
    pattern: /TextStyle\([^)]*fontSize:\s*(\d+)[^)]*\)/g,
    type: 'HARDCODED_TYPOGRAPHY',
    severity: 'warning',
    getSuggestion: (_, fontSize) => {
      const type = findTokenByFontSize(parseInt(fontSize));
      return type ? `替换为 AppTypography.${type.name}` : null;
    },
  },
];
```

**关键设计**：检测到硬编码值时，不光是报错，而是**主动查找匹配的令牌并给出替换建议**。LLM 拿到这些建议后可以一键修正。

## 5.4 响应式检查

Figma 设计稿是固定画布，Flutter 代码必须是响应式的。

```typescript
interface ResponsiveIssue {
  line: number;
  snippet: string;
  figmaValue: number;
  figmaCanvasSize: number;
  suggestion: string;
}

function checkResponsive(
  code: string,
  figmaCanvas: { width: number; height: number }
): ResponsiveIssue[] {
  const issues: ResponsiveIssue[] = [];

  // 检查 Container(width: N, ...) — N 超过画布宽度的 12%
  const widthPattern = /Container\([^)]*\bwidth:\s*(\d+)[^)]*\)/g;
  let match;
  while ((match = widthPattern.exec(code)) !== null) {
    const value = parseInt(match[1]);
    const ratio = value / figmaCanvas.width;
    if (ratio > 0.12) {
      issues.push({
        line: getLineNumber(code, match.index),
        snippet: match[0],
        figmaValue: value,
        figmaCanvasSize: figmaCanvas.width,
        suggestion: `宽度 ${value} 占画布 ${Math.round(ratio * 100)}%，建议：
  - 侧边栏：用 ConstrainedBox(minWidth: ${value}, maxWidth: ${Math.round(value * 1.2)})
  - 内容区：用 Expanded(flex: ${Math.round(ratio * 100)}) 或 MediaQuery
  - 使用 LayoutBuilder 根据可用空间动态调整`,
      });
    }
  }

  return issues;
}
```

**为什么阈值是 12%？** 1440px 画布上，`width: 24`（1.7%）可能是图标尺寸，不需要响应式。`width: 262`（18.2%）是 Sidebar，需要响应式处理。

## 5.5 导入完整性检查

```typescript
function checkImports(code: string, componentRegistry: ComponentDefinition[]): ImportIssue[] {
  const issues: ImportIssue[] = [];

  for (const component of componentRegistry) {
    const className = component.flutter.className;
    const classUsed = new RegExp(`\\b${className}\\b`).test(code);
    const importPresent = code.includes(component.flutter.importPath);

    if (classUsed && !importPresent) {
      issues.push({
        className,
        suggestedImport: `import '${component.flutter.importPath}';`,
        line: findFirstUsageLine(code, className),
      });
    }
  }

  // 检查设计令牌的 import
  const tokenImports = [
    { className: 'AppColors',     importPath: 'package:flutter_zero_copy/design/tokens.dart' },
    { className: 'AppTypography', importPath: 'package:flutter_zero_copy/design/tokens.dart' },
    { className: 'AppSpacing',    importPath: 'package:flutter_zero_copy/design/tokens.dart' },
    { className: 'AppRadius',     importPath: 'package:flutter_zero_copy/design/tokens.dart' },
  ];

  for (const token of tokenImports) {
    if (new RegExp(`\\b${token.className}\\.`).test(code) && !code.includes(token.importPath)) {
      issues.push({
        className: token.className,
        suggestedImport: `import '${token.importPath}';`,
        line: 1,
      });
    }
  }

  return issues;
}
```

## 5.6 令牌使用分析

```typescript
interface TokenUsageReport {
  used: Array<{ name: string; value: string; usageLocations: number }>;
  unused: Array<{ name: string; value: string }>;
  missingReferences: Array<{ value: string; shouldBe: string }>;
}

function analyzeTokenUsage(
  code: string,
  tokens: { colors: ExtractedColor[]; typography: ExtractedTypography[]; spacing: ExtractedSpacing[]; radius: ExtractedRadius[] }
): TokenUsageReport {
  const colorUsage = tokens.colors.map(c => ({
    name: c.name,
    value: c.hex,
    used: code.includes(`AppColors.${c.name}`),
  }));

  const spacingUsage = tokens.spacing.map(s => ({
    name: s.name,
    value: `${s.value}px`,
    used: code.includes(`AppSpacing.${s.name}`),
  }));

  // 反查：代码中的颜色值有没有对应的令牌但未引用？
  const missingRefs: Array<{ value: string; shouldBe: string }> = [];
  const colorInCode = [...code.matchAll(/Color\(0x([0-9A-Fa-f]{8})\)/g)];
  for (const match of colorInCode) {
    const hex = match[1];
    const token = tokens.colors.find(c => c.hex === `#${hex.substring(2)}`);
    if (token && !code.includes(`AppColors.${token.name}`)) {
      missingRefs.push({ value: `0x${hex}`, shouldBe: `AppColors.${token.name}` });
    }
  }

  return {
    used: [...colorUsage.filter(c => c.used), ...spacingUsage.filter(s => s.used)],
    unused: [...colorUsage.filter(c => !c.used), ...spacingUsage.filter(s => !s.used)],
    missingReferences: missingRefs,
  };
}
```

## 5.7 综合评分

```typescript
interface QualityReport {
  totalScore: number;       // 0-100
  syntaxOk: boolean;
  breakdown: {
    syntax: number;          // 40 分 — 编译是否通过
    tokenCompliance: number; // 25 分 — 是否正确使用设计令牌
    responsiveness: number;  // 15 分 — 是否有固定尺寸问题
    componentUsage: number;  // 10 分 — 组件库覆盖率
    codeStyle: number;       // 10 分 — 代码规范
  };
  issues: {
    errors: ValidationIssue[];   // 必须修复
    warnings: ValidationIssue[]; // 建议修复
    info: ValidationIssue[];     // 可选优化
  };
  fixGuide: string;
}

function computeQualityReport(
  syntax: SyntaxResult,
  hardcoded: HardcodedIssue[],
  responsive: ResponsiveIssue[],
  imports: ImportIssue[],
  tokenUsage: TokenUsageReport,
): QualityReport {
  // 语法错误 → 直接扣光 40 分
  const syntaxScore = syntax.ok
    ? 40
    : Math.max(0, 40 - syntax.errors.filter(e => e.severity === 'error').length * 10);

  // 令牌合规：每个硬编码 -5，每个未用令牌 -1
  const tokenScore = Math.max(0, 25
    - hardcoded.filter(h => h.severity === 'error').length * 5
    - tokenUsage.missingReferences.length * 3
    - tokenUsage.unused.length * 1
  );

  // 响应式：每个固定宽度 -5
  const responseScore = Math.max(0, 15 - responsive.length * 5);

  // 组件使用：缺 import 每个 -2
  const componentScore = Math.max(0, 10 - imports.length * 2);

  // 代码风格：基础分
  const styleScore = 10;

  const totalScore = syntaxScore + tokenScore + responseScore + componentScore + styleScore;

  // 按严重程度排序
  const allIssues = [
    ...syntax.errors.map(e => ({ ...e, category: 'syntax', priority: 1 })),
    ...hardcoded.filter(h => h.severity === 'error').map(h => ({ ...h, category: 'token', priority: 1 })),
    ...hardcoded.filter(h => h.severity === 'warning').map(h => ({ ...h, category: 'token', priority: 2 })),
    ...responsive.map(r => ({ ...r, category: 'responsive', priority: 2 })),
    ...imports.map(i => ({ ...i, category: 'import', priority: 1 })),
  ].sort((a, b) => a.priority - b.priority);

  return {
    totalScore,
    syntaxOk: syntax.ok,
    breakdown: { syntax: syntaxScore, tokenCompliance: tokenScore, responsiveness: responseScore, componentUsage: componentScore, codeStyle: styleScore },
    issues: {
      errors: allIssues.filter(i => i.priority === 1),
      warnings: allIssues.filter(i => i.priority === 2),
      info: allIssues.filter(i => i.priority >= 3),
    },
    fixGuide: generateFixGuide(allIssues, totalScore),
  };
}
```

## 5.8 修正指引

验证的最终输出是给 LLM 的修正指令，让 LLM 按优先级逐条修复：

```typescript
function generateFixGuide(issues: any[], score: number): string {
  if (issues.length === 0) return '✅ 代码质量良好，无需修正。';

  const errors = issues.filter(i => i.priority === 1);
  const warnings = issues.filter(i => i.priority === 2);

  let guide = `## 代码质量报告

总分: ${score}/100

### 🔴 必须修复 (${errors.length} 项)
`;

  for (const issue of errors) {
    guide += `
**${issue.type}** — 第 ${issue.line} 行
\`\`\`dart
${issue.snippet}
\`\`\`
→ ${issue.suggestion}
`;
  }

  guide += `
### 🟡 建议修复 (${warnings.length} 项)
`;

  for (const issue of warnings) {
    guide += `- 第 ${issue.line} 行: ${issue.suggestion}\n`;
  }

  guide += `
### 修正顺序
1. 先修所有 🔴，保证编译通过
2. 将硬编码颜色替换为 \`AppColors.*\`
3. 将硬编码间距替换为 \`AppSpacing.*\`
4. 将固定宽度改为响应式约束
5. 重新运行验证直到分数 ≥ 85
`;
  return guide;
}
```

## 5.9 使用流程

```
LLM 生成第一版代码
    │
    ▼
flutter_validate(code, projectPath)
    │  返回: { totalScore: 58, issues: { errors: 3, warnings: 7 }, fixGuide: "..." }
    │
    ▼
LLM 根据 fixGuide 逐个修复
    │
    ▼
flutter_validate(fixedCode, projectPath)
    │  返回: { totalScore: 92, issues: { errors: 0, warnings: 1 }, ... }
    │
    ▼
质量分 ≥ 85 → 输出最终代码
```

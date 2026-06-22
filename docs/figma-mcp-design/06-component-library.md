# Section 6: 组件库设计

## 6.1 核心原则：只注册通用组件

```
┌─────────────────────────────────────────────────┐
│  组件库 (Component Library)                      │
│  条件：在 ≥2 个页面中出现                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │ AppButton│  │ AppCard  │  │ AppInput │       │
│  └──────────┘  └──────────┘  └──────────┘       │
│  只有这些需要 .ts 映射文件                         │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  页面专属 Widget（不进组件库）                     │
│  ┌──────────────┐  ┌──────────────┐              │
│  │ CameraPanel  │  │ PrintTaskView│              │
│  │ (只在控制页)  │  │ (只在控制页)  │              │
│  └──────────────┘  └──────────────┘              │
│  Figma → LLM 直接生成 Container/Row/Column 骨架   │
│  不需要 .ts 映射，不需要注册                       │
│  开发者拿到骨架后填数据 + 替换为真实 Widget         │
└─────────────────────────────────────────────────┘
```

## 6.2 组件库结构

```
mcp-server/src/component-library/
├── types.ts                        # 类型定义（精简版，无 dataContract）
├── manifest.ts                     # 组件注册表
└── base/                           # 只有通用基础组件
    ├── button.ts
    ├── card.ts
    ├── input.ts
    ├── dialog.ts
    └── tab-bar.ts
```

**没有 business 目录**。业务组件（设备卡片、温度面板）都属于页面专属，不进库。

## 6.3 组件定义格式（精简版）

砍掉了 `dataContract`、`integrationExample`，只保留匹配需要的信息：

```typescript
// types.ts

interface ComponentProp {
  name: string;
  type: 'String' | 'int' | 'double' | 'bool' | 'VoidCallback' | 'Widget' | 'enum';
  required: boolean;
  defaultValue?: any;
  enumValues?: string[];
  description?: string;
}

interface FigmaMatchRule {
  componentNames: string[];    // Figma 组件名，支持 * 通配
  minSimilarity: number;       // 0-1
  visualFeatures: {
    borderRadius?: number[];
    hasText: boolean;
    hasIcon: 'always' | 'optional' | 'never';
    minChildren?: number;
    maxChildren?: number;
  };
}

interface ComponentDefinition {
  name: string;
  category: 'base';            // 只有 base，没有 business
  description: string;

  flutter: {
    importPath: string;        // e.g. "package:snapmaker_ui/base/app_button.dart"
    className: string;
    constructorStyle: 'named' | 'positional';
  };

  props: ComponentProp[];
  figmaMatch: FigmaMatchRule;
  usageExample: string;        // Dart 代码片段，帮助 LLM 写出正确的调用
}
```

### 组件定义示例

```typescript
// base/button.ts
import { ComponentDefinition } from '../types';

export const appButton: ComponentDefinition = {
  name: 'AppButton',
  category: 'base',
  description: '通用按钮，对应 Figma 组件 "Button/*" 系列',

  flutter: {
    importPath: 'package:snapmaker_ui/base/app_button.dart',
    className: 'AppButton',
    constructorStyle: 'named',
  },

  props: [
    { name: 'label',    type: 'String',        required: true },
    { name: 'onTap',    type: 'VoidCallback',   required: true },
    { name: 'variant',  type: 'enum', enumValues: ['primary', 'secondary', 'outline', 'ghost'],
                        required: false, defaultValue: 'primary' },
    { name: 'size',     type: 'enum', enumValues: ['small', 'medium', 'large'],
                        required: false, defaultValue: 'medium' },
    { name: 'disabled', type: 'bool',           required: false, defaultValue: false },
  ],

  figmaMatch: {
    componentNames: ['Button/Primary', 'Button/Secondary', 'Button/Outline', 'Button/Ghost'],
    minSimilarity: 0.75,
    visualFeatures: {
      borderRadius: [4, 8],
      hasText: true,
      hasIcon: 'optional',
    },
  },

  usageExample: `
AppButton(
  label: '确定',
  variant: AppButtonVariant.primary,
  size: AppButtonSize.medium,
  onTap: () {},  // 开发者填入实际逻辑
)`,
};
```

```typescript
// base/card.ts
export const appCard: ComponentDefinition = {
  name: 'AppCard',
  category: 'base',
  description: '通用卡片容器',

  flutter: {
    importPath: 'package:snapmaker_ui/base/app_card.dart',
    className: 'AppCard',
    constructorStyle: 'named',
  },

  props: [
    { name: 'child',     type: 'Widget',        required: true },
    { name: 'elevation', type: 'double',         required: false, defaultValue: 2 },
    { name: 'padding',   type: 'double',         required: false, defaultValue: 12 },
  ],

  figmaMatch: {
    componentNames: ['Card', 'Card/*'],
    minSimilarity: 0.70,
    visualFeatures: {
      borderRadius: [8, 12],
      hasText: false,
      hasIcon: 'optional',
    },
  },

  usageExample: `
AppCard(
  elevation: 2,
  padding: AppSpacing.md,
  child: Text('content'),
)`,
};
```

## 6.4 组件注册表

```typescript
// manifest.ts — 只有 base 组件
import { appButton } from './base/button';
import { appCard } from './base/card';
import { appInput } from './base/input';
import { ComponentDefinition } from './types';

export const componentRegistry: ComponentDefinition[] = [
  appButton,
  appCard,
  appInput,
  // 加新通用组件：加一个 import + push 到数组
];

export function findByFigmaName(figmaName: string): ComponentDefinition | undefined {
  return componentRegistry.find(c =>
    c.figmaMatch.componentNames.some(pattern => matchGlob(pattern, figmaName))
  );
}
```

## 6.5 组件实现策略

通用组件不要从零写。两种来源：

### 来源 1：对 Material 组件包一层 adapter

```dart
// lib/widgets/base/app_button.dart
// 不是重写按钮，是给 Material Button 加语义约束

enum AppButtonVariant { primary, secondary, outline, ghost }
enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool disabled;

  const AppButton({super.key, required this.label, this.onTap, ...});

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      AppButtonVariant.primary   => ElevatedButton(onPressed: disabled ? null : onTap, child: Text(label)),
      AppButtonVariant.secondary => FilledButton(onPressed: disabled ? null : onTap, child: Text(label)),
      AppButtonVariant.outline   => OutlinedButton(onPressed: disabled ? null : onTap, child: Text(label)),
      AppButtonVariant.ghost     => TextButton(onPressed: disabled ? null : onTap, child: Text(label)),
    };
  }
}
```

**价值**：不是 UI 实现（Material 已经做好了），而是给 Figma 匹配一个明确的名字和接口。

### 来源 2：项目中已存在的跨页面 Widget

如果项目中已经有一个 Widget 在多个页面使用，只需在 MCP 里加 `.ts` 映射文件，不改 Dart 代码。

## 6.6 新增组件流程

```
1. 在 Flutter 项目写 adapter（或直接用已有 Widget）
   lib/widgets/base/app_xxx.dart

2. 在 MCP Server 创建 .ts 映射文件
   mcp-server/src/component-library/base/xxx.ts

3. 注册到 manifest.ts（加一行 import + push）

4. 验证
   调用 figma_match_components，检查新的 Figma 组件能否命中
```

## 6.7 页面专属区域怎么处理

不在组件库里的 Figma Frame → MCP 不尝试匹配 → LLM 直接用 Container/Row/Column 生成骨架 → 开发者填入实际内容。

```
Figma 中的 CameraPanel (Frame, 有子元素)
  → 组件库里没有对应条目
  → figma_match_components 返回 { matched: false }
  → LLM 生成：
      Container(
        color: AppColors.surface,
        child: Column(children: [
          // TODO: CameraPanel — 替换为实际摄像头 Widget
          _Placeholder(child: Icon(Icons.camera)),
        ]),
      )
  → 开发者把 _Placeholder 换成真正的 CameraWidget(sn: sn)
```

## 6.8 渐进式增长

```
Phase 2 (起步):
  5 个 base 组件 → 匹配覆盖率 ~40%
  
Phase 5 (打磨):
  10-15 个 base 组件 → 匹配覆盖率 ~60%
  
长期:
  Figma 中同一个非通用组件被多处使用 →
  开发者决定提为通用组件 →
  写 adapter + .ts 映射 → 注册
```

**组件库不是一次性设计出来的，是一个一个长出来的。**

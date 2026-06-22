# Section 2: MCP Tools 设计

## 2.1 Tool 总览

MCP Server 通过 6 个 tool 把 Figma 数据逐层喂给 LLM：

| Tool | 职责 | 是否需 LLM |
|------|------|-----------|
| `figma_get_file_structure` | 拉取页面/Frame 树，不含详细样式 | 否 |
| `figma_get_node_details` | 获取指定节点的完整样式信息 | 否 |
| `figma_match_components` | Figma 节点 → Flutter 组件库匹配 | 否（确定性） |
| `figma_extract_tokens` | 提取设计令牌，输出 Dart 代码 | 否（确定性） |
| `figma_generate_flutter` | 确定性组件调用 + LLM 填充骨架 | 部分 |
| `flutter_validate` | 代码质量检查 + 修正指引 | 否（确定性） |

**设计原则**：确定性计算归 MCP Server，语义判断归 LLM。

## 2.2 Tool 1: `figma_get_file_structure`

**职责**：拉取 Figma 文件，返回结构化的页面/Frame 树，不带详细样式。

**输入**：
```
figma_file_key: string
figma_token: string
```

**输出**：
```json
{
  "fileName": "Device Control v2",
  "pages": [
    {
      "id": "0:1",
      "name": "📱 Device Control",
      "frames": [
        {
          "id": "1:10",
          "name": "DeviceControlFullPage",
          "type": "FRAME",
          "size": { "width": 1440, "height": 900 },
          "layoutMode": "HORIZONTAL",
          "childCount": 3,
          "children": [
            { "id": "1:11", "name": "Sidebar", "type": "FRAME", "size": {"w":262, "h":900}, "childCount": 5 },
            { "id": "1:20", "name": "MainArea", "type": "FRAME", "layoutMode": "VERTICAL", "childCount": 2 }
          ]
        }
      ]
    }
  ],
  "componentInstances": [
    { "nodeId": "1:15", "componentName": "Button/Primary", "componentId": "2:5" },
    { "nodeId": "1:30", "componentName": "Card/Device", "componentId": "2:8" }
  ]
}
```

**设计要点**：
- Figma 文件可能巨大，这个 tool 让 LLM 先了解「有哪些页面、哪些区域」
- 再决定对哪些 Frame 深入获取细节（按需调用 tool 2）
- 不一次返回所有细节，避免 token 浪费

## 2.3 Tool 2: `figma_get_node_details`

**职责**：获取指定节点的完整样式信息。

**输入**：
```
figma_file_key: string
figma_token: string
node_ids: string[]  // 批量获取，减少来回
```

**输出**：
```json
{
  "nodes": [
    {
      "id": "1:11",
      "name": "Sidebar",
      "type": "FRAME",
      "absoluteBounds": { "x": 0, "y": 0, "width": 262, "height": 900 },
      "layout": {
        "mode": "VERTICAL",
        "gap": 0,
        "padding": { "top": 28, "right": 0, "bottom": 0, "left": 0 },
        "mainAxisAlign": "MIN",
        "crossAxisAlign": "STRETCH"
      },
      "style": {
        "fills": [{ "type": "SOLID", "color": "#FFFFFF", "opacity": 1.0 }],
        "strokes": [],
        "effects": [],
        "cornerRadius": { "tl": 0, "tr": 0, "bl": 0, "br": 0 },
        "clipsContent": false
      },
      "children": [...]
    }
  ]
}
```

**关键处理**：
- Figma API 返回的颜色是 `{r: 0.92, g: 0.92, b: 0.92}` (0-1 浮点)
- 此 tool 内部转为 `#EBEBEB` 十六进制，省去 LLM 做浮点运算
- 支持递归获取子节点

## 2.4 Tool 3: `figma_match_components`

**职责**：将 Figma 组件实例和 Frame 与 Flutter 组件库做匹配。**提升生成质量最关键的 tool**。

**输入**：
```
node_ids: string[]
```

**输出**：
```json
{
  "matches": [
    {
      "nodeId": "1:15",
      "nodeName": "Button/Primary",
      "matched": true,
      "flutterComponent": {
        "name": "AppButton",
        "category": "base",
        "importPath": "package:snapmaker_ui/base/app_button.dart",
        "className": "AppButton",
        "props": [
          { "name": "label", "type": "String", "required": true },
          { "name": "onTap", "type": "VoidCallback", "required": true },
          { "name": "variant", "type": "enum", "values": ["primary","secondary","outline","ghost"] },
          { "name": "size", "type": "enum", "values": ["small","medium","large"] }
        ],
        "usageExample": "AppButton(label: '确定', variant: AppButtonVariant.primary, onTap: () {})"
      },
      "recommendedProps": {
        "label": "确定",
        "variant": "primary",
        "size": "medium"
      }
    },
    {
      "nodeId": "1:40",
      "nodeName": "CustomGauge",
      "matched": false,
      "suggestion": "使用 Stack + CustomPaint 组合实现",
      "similarComponents": [
        { "name": "AppProgressBar", "similarity": 0.62, "reason": "相似的数据可视化语义" }
      ]
    }
  ],
  "summary": {
    "total": 15,
    "matched": 12,
    "unmatched": 3,
    "coverage": 0.80
  }
}
```

## 2.5 Tool 4: `figma_extract_tokens`

**职责**：从 Figma 文件提取设计令牌，直接输出可用的 Dart 代码。纯确定性计算。

**输入**：
```
figma_file_key: string
figma_token: string
```

**输出**：
```json
{
  "colors": [
    { "name": "primaryCyan",    "value": "#00D4AA", "usage": "主色，出现 23 次" },
    { "name": "darkBackground", "value": "#1A1A2E", "usage": "页面背景，出现 6 次" },
    { "name": "textPrimary",    "value": "#E0E0E0", "usage": "主要文字，出现 45 次" }
  ],
  "typography": [
    { "name": "headlineLarge",  "fontSize": 20, "fontWeight": 600, "lineHeight": 1.4, "usage": "页面标题" },
    { "name": "bodyMedium",     "fontSize": 14, "fontWeight": 400, "lineHeight": 1.5, "usage": "正文" }
  ],
  "spacing": [
    { "name": "sm", "value": 6,  "usage": "默认组件间距，出现 34 次" },
    { "name": "md", "value": 12, "usage": "区块内间距，出现 15 次" }
  ],
  "borderRadius": [
    { "name": "sm", "value": 4,  "usage": "按钮/输入框" },
    { "name": "md", "value": 8,  "usage": "卡片/面板" }
  ],
  "generatedDartCode": "// 设计令牌 Dart 代码\nclass AppColors {\n  static const primary = Color(0xFF00D4AA);\n  ...\n}"
}
```

## 2.6 Tool 5: `figma_generate_flutter`

**职责**：核心生成 tool。**只生成 UI 骨架 + 样式**，不生成数据绑定和业务逻辑。

**输入**：
```
figma_file_key: string
figma_token: string
frame_id: string
```

**输出**：
```json
{
  "frameName": "DeviceControlFullPage",
  "deterministicParts": [
    {
      "nodeId": "1:15",
      "status": "matched",
      "flutterComponent": "AppButton",
      "code": "AppButton(label: '开始打印', variant: AppButtonVariant.primary, onTap: () {})"
    }
  ],
  "skeleton": {
    "dartCode": "class DeviceControlFullPage extends StatelessWidget {
  const DeviceControlFullPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,          // 令牌引用
      child: Row(
        children: [
          // ── Sidebar ──
          Container(
            width: 262,                     // Figma 原值，开发者改为响应式
            color: AppColors.surface,
            child: Column(children: [
              AppButton(                     // 匹配到通用组件
                label: '设备控制',
                variant: AppButtonVariant.primary,
                onTap: () {},               // TODO: 填入实际回调
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Column(children: [
                // ── 顶行 ──
                Expanded(
                  flex: 339,
                  child: Row(children: [
                    // TODO: CameraPanel — 无匹配组件，需替换为实际 Widget
                    Expanded(child: _CameraPanelPlaceholder()),
                    SizedBox(width: AppSpacing.sm),
                    // TODO: ControlPanel — 无匹配组件，需替换为实际 Widget
                    Expanded(child: _ControlPanelPlaceholder()),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}",
    "tokensUsed": ["AppColors.background", "AppColors.surface", "AppSpacing.sm"],
    "unmatchedNodes": [
      {
        "nodeId": "1:20",
        "name": "CameraPanel",
        "reason": "页面专属区域，不在通用组件库中",
        "suggestion": "开发者替换 _CameraPanelPlaceholder 为实际业务 Widget"
      }
    ],
    "matchedComponents": [
      { "nodeId": "1:15", "component": "AppButton", "code": "AppButton(...)" }
    ]
  },
  "designTokens": { "colorsDart": "...", "typographyDart": "..." },
  "componentDocs": [
    { "name": "AppButton", "props": [...], "usageExample": "..." }
  ]
}
```

**生成规则**：
- **通用组件**：匹配到的 → 直接生成组件调用代码，`onTap` 留 `() {}`
- **页面专属区域**：未匹配的 → 生成 `Container`/`Row`/`Column` 骨架 + `// TODO: 替换为实际 Widget`
- **样式属性**：全部引用设计令牌（`AppColors.*`, `AppSpacing.*`, `AppTypography.*`）
- **数据绑定**：不生成 `ConsumerWidget`、`ref.watch`、provider 引用 → 开发者自己连

## 2.7 Tool 6: `flutter_validate`

**职责**：对生成的 Flutter 代码做静态检查和质量分析。

**输入**：
```
dart_code: string
project_path: string (optional)
```

**输出**：
```json
{
  "syntaxOk": true,
  "totalScore": 73,
  "breakdown": {
    "syntax": 40,
    "tokenCompliance": 15,
    "responsiveness": 8,
    "componentUsage": 6,
    "codeStyle": 4
  },
  "warnings": [
    {
      "type": "HARDCODED_VALUE",
      "location": "line 23, col 18",
      "code": "width: 262",
      "suggestion": "建议改用 MediaQuery.of(context).size.width * 0.18 或 AppSizing.sidebarWidth"
    },
    {
      "type": "MAGIC_NUMBER",
      "location": "line 41, col 17",
      "code": "SizedBox(height: 6)",
      "suggestion": "间距 6 已定义为 AppSpacing.sm，建议替换"
    }
  ],
  "fixGuide": "### 🔴 必须修复 (0 项)\n### 🟡 建议修复 (2 项)\n..."
}
```

## 2.8 完整调用流程

LLM 做一次 Figma→Flutter 转换的典型链路：

```
1. figma_get_file_structure
   → "设备控制页面，顶 Frame 是 HORIZONTAL，3 个子区域"

2. figma_extract_tokens           }  并行调用
3. figma_match_components         }

4. figma_get_node_details([未匹配的节点])
   → "CameraPanel 详细样式"

5. figma_generate_flutter
   → 骨架代码 + 确定性组件调用 + 设计令牌

6. LLM 根据以上上下文生成完整 Dart 代码

7. flutter_validate(生成的代码)
   → "3 warnings: 2 硬编码 + 1 缺 import"

8. LLM 根据 fixGuide 修正代码

9. 最终输出 Flutter 代码 + design_tokens.dart
```

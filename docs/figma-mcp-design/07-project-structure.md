# Section 7: 项目结构 & 实施计划

## 7.1 完整目录结构

```
snapmaker-flutter/                          # 现有 Flutter 项目（同仓库）
│
├── mcp-server/                             # MCP Server (TypeScript)
│   ├── package.json
│   ├── tsconfig.json
│   ├── src/
│   │   ├── index.ts                        # MCP Server 入口，注册所有 tools
│   │   │
│   │   ├── figma/                          # Figma API 层
│   │   │   ├── client.ts                   #   Figma REST API 封装 (axios)
│   │   │   ├── parser.ts                   #   节点树解析
│   │   │   ├── image-exporter.ts          #   图层导出为 PNG
│   │   │   └── types.ts                    #   Figma JSON 类型定义
│   │   │
│   │   ├── component-library/              # 通用组件元数据（仅 base，无 business）
│   │   │   ├── types.ts                    #   ComponentDefinition 接口
│   │   │   ├── manifest.ts                 #   组件注册表（只有 base 组件）
│   │   │   ├── matcher.ts                  #   匹配引擎
│   │   │   └── base/                       #   通用基础组件定义
│   │   │       ├── button.ts
│   │   │       ├── card.ts
│   │   │       └── input.ts
│   │   │
│   │   ├── tokens/                         # 令牌提取
│   │   │   ├── extractor.ts                #   提取引擎
│   │   │   ├── color-extractor.ts
│   │   │   ├── typography-extractor.ts
│   │   │   ├── spacing-extractor.ts
│   │   │   └── codegen.ts                  #   输出 Dart tokens 代码
│   │   │
│   │   ├── codegen/                        # 代码生成
│   │   │   ├── flutter-writer.ts          #   骨架生成
│   │   │   └── templates/                  #   Handlebars 模板
│   │   │       ├── stateless-widget.hbs
│   │   │       ├── stateful-widget.hbs
│   │   │       └── layout.hbs
│   │   │
│   │   ├── validator/                      # 后处理 & 验证
│   │   │   ├── analyzer.ts                 #   质量检查
│   │   │   ├── hardcoded-detector.ts      #   硬编码检测
│   │   │   ├── responsive-checker.ts      #   响应式检查
│   │   │   ├── import-checker.ts          #   导入检查
│   │   │   └── scorer.ts                   #   综合评分
│   │   │
│   │   └── tools/                          # MCP Tool 实现
│   │       ├── figma-fetch.ts              #   figma_get_file_structure
│   │       ├── figma-node-details.ts      #   figma_get_node_details
│   │       ├── component-match.ts         #   figma_match_components
│   │       ├── tokens-extract.ts           #   figma_extract_tokens
│   │       ├── flutter-generate.ts        #   figma_generate_flutter
│   │       └── validate.ts                 #   flutter_validate
│   │
│   └── tests/
│       ├── matcher.test.ts
│       ├── token-extractor.test.ts
│       └── validator.test.ts
│
├── lib/                                    # Flutter 代码 (现有)
│   ├── app/
│   │   └── theme.dart
│   ├── pages/
│   │   └── device/                         # 设备控制页面
│   ├── widgets/                            # 通用组件
│   ├── design/                             # 设计令牌 (新增)
│   │   └── tokens.dart                     #   由 MCP Server 提取生成
│   └── ...
│
├── pubspec.yaml
├── docs/
│   └── figma-mcp-design/                   # 本设计文档
│       ├── 01-overview.md
│       ├── 02-mcp-tools.md
│       ├── 03-component-matcher.md
│       ├── 04-token-extraction.md
│       ├── 05-postprocessing.md
│       ├── 06-component-library.md
│       └── 07-project-structure.md
│
└── CLAUDE.md                               # Claude 配置（可引用 MCP Server）
```

## 7.2 技术栈

| 层 | 技术 | 说明 |
|----|------|------|
| MCP 框架 | `@modelcontextprotocol/sdk` | 官方 TypeScript SDK |
| HTTP 客户端 | `axios` | 调用 Figma REST API |
| 模板引擎 | `handlebars` | 代码骨架生成 |
| 类型系统 | TypeScript strict mode | 组件定义的类型安全 |
| Figma API | REST API v1 | 获取文件、节点、样式、图片 |
| Dart 分析 | `dart analyze` CLI | 语法和类型检查 |
| 测试框架 | `vitest` | MCP Server 单元测试 |

## 7.3 实施阶段

### Phase 1: 骨架搭建（2 天）

**目标**：MCP Server 能跑起来，一个 tool 能调通 Figma API。

- [ ] 初始化 MCP Server 项目 (`package.json`, `tsconfig.json`)
- [ ] 实现 Figma API 客户端 (`src/figma/client.ts`)
- [ ] 实现 Tool 1: `figma_get_file_structure`
- [ ] 在 Claude Code 中配置并测试连接

**验收**：能在 Claude Code 中调用 `figma_get_file_structure` 拿到你的设备控制页面的 Frame 树。

---

### Phase 2: 通用组件匹配引擎（1.5 天）

**目标**：Figma 中的通用 Component Instance 能匹配到 Flutter 组件。

- [ ] 实现 `types.ts` — ComponentDefinition 接口（精简版，无 dataContract）
- [ ] 实现 `manifest.ts` — 组件注册表
- [ ] 编写 3-5 个 base 组件定义 (`button.ts`, `card.ts`, `input.ts`)
- [ ] 实现匹配引擎 (`matcher.ts`)：类型分类 + 候选召回 + 多维打分
- [ ] 匹配引擎只匹配 base 组件，非 base 直接返回 unmatched
- [ ] 实现 Tool 3: `figma_match_components`

**验收**：Figma 用了 Button/Primary → MCP 返回匹配到 AppButton。

---

### Phase 3: 令牌提取（1.5 天）

**目标**：从 Figma 文件自动生成 `tokens.dart`。

- [ ] 实现颜色聚类算法 (`tokens/color-extractor.ts`)
- [ ] 实现字号聚类算法 (`tokens/typography-extractor.ts`)
- [ ] 实现间距聚类算法 (`tokens/spacing-extractor.ts`)
- [ ] 实现 Dart 代码生成 (`tokens/codegen.ts`)
- [ ] 实现 Tool 4: `figma_extract_tokens`

**验收**：对你现有的 `theme.dart` 中的颜色，用 `figma_extract_tokens` 重新提取一遍，对比人工版本和自动版本的差异。

---

### Phase 4: 骨架生成 + 后处理（1.5 天）

**目标**：生成 UI 骨架代码 + 自动验证质量。

- [ ] 实现 Tool 2: `figma_get_node_details`（按需获取详细样式）
- [ ] 实现 Tool 5: `figma_generate_flutter`（骨架生成，只含样式不含数据绑定）
- [ ] 骨架生成规则：
  - 匹配到通用组件 → 直接生成组件调用代码
  - 未匹配 → 生成 Container/Row/Column 骨架 + `// TODO: 替换为实际 Widget`
  - 样式属性引用设计令牌
  - 数据绑定处留空或 `() {}`
- [ ] 实现硬编码检测 (`validator/hardcoded-detector.ts`)
- [ ] 实现响应式检查 (`validator/responsive-checker.ts`)
- [ ] 实现导入检查 (`validator/import-checker.ts`)
- [ ] 实现综合评分 (`validator/scorer.ts`)
- [ ] 实现 Tool 6: `flutter_validate`

**验收**：端到端走通 Figma → UI 骨架 → Validate → Fix → 85 分。

---

### Phase 5: 组件库扩充 + 打磨（持续）

**目标**：按需扩充通用组件。

- [ ] 补充 base 组件到 10-15 个（遇到新的跨页面复用模式时才加）
- [ ] 调优匹配权重（根据实际使用反馈调整 0.35/0.40/0.25）
- [ ] 调优决策阈值（当前 0.65）
- [ ] 写单元测试覆盖匹配引擎和令牌提取
- [ ] 不追求覆盖率 100%——页面专属组件不进库是正常设计

## 7.4 关键依赖

```json
{
  "dependencies": {
    "@modelcontextprotocol/sdk": "^0.5.0",
    "axios": "^1.7.0",
    "handlebars": "^4.7.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "typescript": "^5.5.0",
    "vitest": "^1.6.0",
    "@types/node": "^20.0.0"
  }
}
```

## 7.5 Claude Code 配置

在项目 `.claude/settings.json` 或全局配置中添加 MCP Server：

```json
{
  "mcpServers": {
    "figma-flutter": {
      "command": "node",
      "args": ["mcp-server/dist/index.js"],
      "cwd": "${workspaceFolder}/mcp-server",
      "env": {
        "FIGMA_ACCESS_TOKEN": "${FIGMA_ACCESS_TOKEN}"
      }
    }
  }
}
```

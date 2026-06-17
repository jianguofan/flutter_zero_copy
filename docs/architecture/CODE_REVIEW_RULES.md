# 代码审查规则 (Code Review Rules)

> **版本**: 1.0  
> **生效日期**: 2026-06-17  
> **适用范围**: flutter_zero_copy 项目  
> **目的**: 防止架构退化、订阅泄漏、分层混乱

---

## 使用说明

每个规则包含：
- **规则 ID**: 用于审查评论引用 (如: "违反 LAYER-01")
- **严重程度**: 🔴 阻断合并 | 🟡 必须修复 | 🟢 建议优化
- **自动化**: ✅ Lint 自动检查 | 🔧 工具辅助 | 👁️ 人工审查

---

## 第一部分：分层规则 (LAYER)

### LAYER-01: UI 层不得直接依赖 SDK 🔴

**规则**: `lib/pages/` 和 `lib/widgets/` 不得直接 import SDK 包

**禁止**:
```dart
// ❌ 错误示例
import 'package:lava_device_sdk/lava_device_sdk.dart';

class MyDevicesPage extends ConsumerWidget {
  void _connectDevice() {
    final hub = DeviceHub();  // 直接使用 SDK
    hub.connectLan('192.168.1.1');
  }
}
```

**正确**:
```dart
// ✅ 正确示例
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/providers/device_session_provider.dart';

class MyDevicesPage extends ConsumerWidget {
  void _connectDevice(WidgetRef ref) {
    final session = ref.read(deviceSessionProvider);
    session.activate(deviceId);  // 通过 Provider 层
  }
}
```

**原因**: 
- UI 层直接依赖 SDK → SDK 变更影响 UI
- 跳过 Provider 层 → 无法统一管理状态

**自动化**: ✅ Lint 规则
```yaml
# analysis_options.yaml
custom_lint:
  rules:
    - no_direct_sdk_import_in_ui:
        paths: ['lib/pages/', 'lib/widgets/']
        forbidden: ['lava_device_sdk']
```

---

### LAYER-02: UI 层不得直接实例化 Service 🟡

**规则**: UI 层不得使用 `ChangeNotifier` Service，必须通过 Riverpod Provider

**禁止**:
```dart
// ❌ 错误示例
class _MyDevicesPageState extends ConsumerState<MyDevicesPage> {
  final DeviceManagerService _deviceManager = DeviceManagerService();
  
  @override
  void initState() {
    _deviceManager.addListener(_onChanged);  // 手动管理生命周期
  }
}
```

**正确**:
```dart
// ✅ 正确示例
class MyDevicesPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(deviceListProvider);  // Riverpod 自动管理
    // ...
  }
}
```

**原因**:
- 手动 `addListener` → 容易忘记 `removeListener`
- 绕过 Riverpod → 无法利用依赖注入和测试替换

**自动化**: 👁️ 人工审查 (检查 `extends ChangeNotifier` 的类是否被直接实例化)

---

### LAYER-03: Provider 不得依赖 Flutter UI 框架 🟡

**规则**: `lib/features/*/application/providers/` 不得 import `package:flutter/material.dart` 或 `widgets.dart`

**禁止**:
```dart
// ❌ 错误示例
import 'package:flutter/material.dart';

final deviceListProvider = Provider<List<DeviceInfo>>((ref) {
  final devices = ref.watch(deviceRegistryProvider).devices;
  debugPrint('Loaded ${devices.length} devices');  // 依赖 Flutter
  return devices;
});
```

**正确**:
```dart
// ✅ 正确示例
import 'dart:developer' as developer;

final deviceListProvider = Provider<List<DeviceInfo>>((ref) {
  final devices = ref.watch(deviceRegistryProvider).devices;
  developer.log('Loaded ${devices.length} devices');  // 纯 Dart
  return devices;
});
```

**例外**: 可以 import `package:flutter/foundation.dart` (用于 `@immutable` 等)

**原因**: Provider 层应该可以在纯 Dart 环境中测试

**自动化**: ✅ Lint 规则
```yaml
custom_lint:
  rules:
    - no_flutter_in_providers:
        paths: ['lib/features/*/application/providers/']
        forbidden: ['package:flutter/material.dart', 'package:flutter/widgets.dart']
```

---

### LAYER-04: 数据层不得依赖 Riverpod 🔴

**规则**: `lib/features/*/data/` 不得 import `flutter_riverpod`

**禁止**:
```dart
// ❌ 错误示例 (data/repositories/device_session_impl.dart)
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceSessionImpl {
  void activate(ProviderRef ref) {  // 数据层依赖 Riverpod
    final registry = ref.read(deviceRegistryProvider);
  }
}
```

**正确**:
```dart
// ✅ 正确示例
class DeviceSessionImpl {
  final IDeviceRegistry _registry;
  
  DeviceSessionImpl({required IDeviceRegistry registry}) 
    : _registry = registry;  // 构造函数注入
    
  void activate() {
    _registry.lookup(deviceId);
  }
}
```

**原因**: 数据层应该框架无关，便于测试和复用

**自动化**: ✅ Lint 规则

---

### LAYER-05: 依赖方向检查 🟢

**规则**: 依赖关系必须单向: UI → Application → Data → SDK

**检查清单**:
```
✅ lib/pages/         → lib/features/*/application/  (允许)
✅ lib/application/   → lib/data/                    (允许)
✅ lib/data/          → packages/lava_device_sdk/    (允许)
❌ lib/data/          → lib/application/             (禁止)
❌ lib/application/   → lib/pages/                   (禁止)
```

**自动化**: 🔧 工具辅助 (import_sorter + 脚本检查)

```bash
# tools/check_dependencies.sh
#!/bin/bash
grep -r "import.*application" lib/data/ && echo "❌ Data layer imports Application!" && exit 1
grep -r "import.*pages" lib/features/ && echo "❌ Features layer imports UI!" && exit 1
echo "✅ Dependency direction check passed"
```

---

## 第二部分：订阅管理规则 (SUB)

### SUB-01: Timer 必须在 dispose 中取消 🔴

**规则**: 所有 `Timer.periodic` 必须在 Widget/Service 的 `dispose()` 中调用 `.cancel()`

**禁止**:
```dart
// ❌ 错误示例
class _MyWidgetState extends State<MyWidget> {
  Timer? _timer;
  
  @override
  void initState() {
    _timer = Timer.periodic(Duration(seconds: 30), (_) {
      _checkStatus();
    });
  }
  
  // ❌ 忘记 dispose
}
```

**正确**:
```dart
// ✅ 正确示例
class _MyWidgetState extends State<MyWidget> {
  Timer? _timer;
  
  @override
  void initState() {
    _timer = Timer.periodic(Duration(seconds: 30), (_) {
      _checkStatus();
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();  // ✅ 必须取消
    super.dispose();
  }
}
```

**检查方法**: 搜索 `Timer.periodic`，确保同文件中有 `dispose()` 和 `.cancel()`

**自动化**: 👁️ 人工审查 + 正则检查

```bash
# 检查脚本
for file in $(grep -l "Timer.periodic" lib/**/*.dart); do
  if ! grep -q "\.cancel()" "$file"; then
    echo "⚠️ $file: Timer.periodic without cancel()"
  fi
done
```

---

### SUB-02: addListener 必须配对 removeListener 🔴

**规则**: 每个 `addListener` 必须有对应的 `removeListener`

**禁止**:
```dart
// ❌ 错误示例
@override
void initState() {
  _controller.addListener(_onChanged);
  // ❌ 没有在 dispose 中 removeListener
}
```

**正确**:
```dart
// ✅ 正确示例
@override
void initState() {
  _controller.addListener(_onChanged);
}

@override
void dispose() {
  _controller.removeListener(_onChanged);  // ✅ 配对释放
  super.dispose();
}
```

**自动化**: 👁️ 人工审查 (检查 `addListener` 和 `removeListener` 数量一致)

---

### SUB-03: StreamSubscription 必须取消 🔴

**规则**: 手动创建的 `StreamSubscription` 必须在 `dispose()` 中 `cancel()`

**禁止**:
```dart
// ❌ 错误示例
StreamSubscription? _sub;

void _subscribe() {
  _sub = stream.listen((data) {
    // ...
  });
  // ❌ 未取消
}
```

**正确**:
```dart
// ✅ 正确示例
StreamSubscription? _sub;

void _subscribe() {
  _sub = stream.listen((data) {
    // ...
  });
}

@override
void dispose() {
  _sub?.cancel();  // ✅ 必须取消
  super.dispose();
}
```

**例外**: Riverpod 的 `ref.listen` 和 `StreamBuilder` 会自动取消，无需手动管理

**自动化**: 👁️ 人工审查

---

### SUB-04: 避免单个 Widget 订阅过多字段 🟡

**规则**: 单个 Widget 使用 `deviceFieldStreamProvider` 不超过 5 个字段

**不推荐**:
```dart
// ⚠️ 过度订阅
class DeviceDetailPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nozzleTemp = ref.watch(deviceFieldStreamProvider('temperature.nozzle'));
    final bedTemp = ref.watch(deviceFieldStreamProvider('temperature.bed'));
    final chamberTemp = ref.watch(deviceFieldStreamProvider('temperature.chamber'));
    final printState = ref.watch(deviceFieldStreamProvider('print.state'));
    final progress = ref.watch(deviceFieldStreamProvider('print.progress'));
    final filament = ref.watch(deviceFieldStreamProvider('filament.used'));
    final duration = ref.watch(deviceFieldStreamProvider('print.duration'));
    final fileName = ref.watch(deviceFieldStreamProvider('print.filename'));
    // ⚠️ 8 个字段订阅 → 性能问题
  }
}
```

**推荐**:
```dart
// ✅ 订阅聚合状态
final deviceStatusProvider = Provider<DeviceStatus>((ref) {
  final device = ref.watch(activeDeviceProvider);
  return DeviceStatus(
    nozzleTemp: device?.getField('temperature.nozzle'),
    bedTemp: device?.getField('temperature.bed'),
    // ... 其他字段
  );
});

class DeviceDetailPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(deviceStatusProvider);  // 单次订阅
    // ...
  }
}
```

**原因**: 每个字段订阅创建一个 Stream 监听器，过多订阅增加内存和重建开销

**自动化**: 👁️ 人工审查 (计数 `deviceFieldStreamProvider`)

---

### SUB-05: 优先使用 ref.watch 而非 StreamBuilder 🟢

**规则**: 在 `ConsumerWidget` 中，优先使用 `ref.watch` 订阅 `StreamProvider`

**不推荐**:
```dart
// ⚠️ ConsumerWidget 中使用 StreamBuilder
class DeviceListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateStream = ref.read(deviceSessionStateProvider.stream);
    return StreamBuilder<DeviceSessionState>(
      stream: stateStream,
      builder: (context, snapshot) {
        // ...
      },
    );
  }
}
```

**推荐**:
```dart
// ✅ 直接使用 ref.watch
class DeviceListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceSessionStateProvider);
    return state.when(
      data: (state) => _buildContent(state),
      loading: () => CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
    );
  }
}
```

**原因**: `ref.watch` 自动管理生命周期，代码更简洁

**例外**: 当需要 `initialData` 或自定义 `StreamBuilder` 行为时可使用

**自动化**: 👁️ 人工审查

---

## 第三部分：Provider 规则 (PROV)

### PROV-01: Provider 命名约定 🟡

**规则**: 
- `Provider` → `xxxProvider`
- `StreamProvider` → `xxxStreamProvider` 或 `xxxProvider`
- `FutureProvider` → `xxxFutureProvider` 或 `xxxProvider`
- `StateProvider` → `xxxStateProvider`

**正确示例**:
```dart
final deviceListProvider = Provider<List<DeviceInfo>>(...);
final deviceSessionStateProvider = StreamProvider<DeviceSessionState>(...);
final sendDeviceCommandProvider = FutureProvider.family<CommandResult, DeviceCommand>(...);
```

**自动化**: ✅ Lint 规则 (命名检查)

---

### PROV-02: Provider 不得包含业务逻辑 🟡

**规则**: Provider 仅用于依赖注入和组合，不应包含复杂业务逻辑

**禁止**:
```dart
// ❌ 错误示例
final deviceListProvider = Provider<List<DeviceInfo>>((ref) {
  final registry = ref.watch(deviceRegistryProvider);
  final devices = registry.devices;
  
  // ❌ 业务逻辑放在 Provider 中
  final sortedDevices = devices.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  
  final filteredDevices = sortedDevices.where((d) => d.isOnline).toList();
  
  return filteredDevices;
});
```

**正确**:
```dart
// ✅ 正确示例: 逻辑放在 Service 或 Repository
final deviceListProvider = Provider<List<DeviceInfo>>((ref) {
  final registry = ref.watch(deviceRegistryProvider);
  return registry.devices;  // 仅注入
});

final sortedDeviceListProvider = Provider<List<DeviceInfo>>((ref) {
  final devices = ref.watch(deviceListProvider);
  return DeviceListService.sortByName(devices);  // 逻辑在 Service
});
```

**原因**: Provider 应该保持简单，便于测试和理解

**自动化**: 👁️ 人工审查 (Provider 函数体 < 10 行)

---

### PROV-03: 避免 Provider 循环依赖 🔴

**规则**: Provider 之间不得形成循环依赖

**禁止**:
```dart
// ❌ 错误示例
final providerA = Provider((ref) {
  ref.watch(providerB);  // A → B
});

final providerB = Provider((ref) {
  ref.watch(providerA);  // B → A ❌ 循环
});
```

**检查方法**: 绘制依赖图，确保是有向无环图 (DAG)

**自动化**: 🔧 工具辅助 (Riverpod Inspector)

---

### PROV-04: Family Provider 必须文档说明参数 🟢

**规则**: 使用 `Provider.family` 时，必须注释说明参数含义

**禁止**:
```dart
// ❌ 缺少文档
final deviceFieldStreamProvider =
    Provider.family<Stream<dynamic>, String>((ref, fieldPath) {
  // ...
});
```

**正确**:
```dart
// ✅ 完整文档
/// Subscribe to a specific field of the active device as a [Stream].
///
/// **Parameters**:
/// - [fieldPath]: Dot-separated path like 'temperature.nozzle' or 'print.state'
///
/// **Returns**: Empty stream when no device is active.
///
/// **Example**:
/// ```dart
/// final tempStream = ref.watch(deviceFieldStreamProvider('temperature.nozzle'));
/// ```
final deviceFieldStreamProvider =
    Provider.family<Stream<dynamic>, String>((ref, fieldPath) {
  // ...
});
```

**自动化**: 👁️ 人工审查

---

## 第四部分：架构一致性规则 (ARCH)

### ARCH-01: 文档声明的类必须存在 🔴

**规则**: `/docs/architecture/*.md` 中提到的核心类必须在代码中实现

**检查清单**:
```bash
# 自动化检查脚本
#!/bin/bash
MISSING=0

# 从文档中提取类名
CLASSES=$(grep -oP '(?<=class )\w+' docs/architecture/*.md | sort -u)

for class in $CLASSES; do
  if ! grep -rq "class $class" lib/; then
    echo "❌ 文档中声明的 $class 不存在"
    MISSING=1
  fi
done

exit $MISSING
```

**当前问题**:
- ❌ `DeviceMetadataStore` — 文档中 200 行代码，实际不存在
- ❌ `CloudPoller` — 文档提及，代码中未实现
- ❌ `allDevicesProvider` — 文档声明，代码中无定义

**自动化**: 🔧 工具辅助 (CI 脚本)

---

### ARCH-02: 核心类职责必须与文档一致 🟡

**规则**: 核心类的职责描述必须与实际代码一致

**检查方法**:
1. 读取 `docs/architecture/DEVICE_ARCHITECTURE.md` 中的职责表
2. 检查代码中的类是否符合描述

**示例**:
```markdown
# 文档声明
| 类 | 职责 |
|----|------|
| DeviceSessionImpl | 管理"当前活跃设备"的唯一所有者 |

# 代码检查
class DeviceSessionImpl {
  // ✅ 确实管理 _activeDevice
  // ✅ 提供 activate/deactivate 方法
}
```

**自动化**: 👁️ 人工审查 (每月一次架构审查会议)

---

### ARCH-03: 新增 Provider 必须更新文档 🟢

**规则**: 在 `lib/features/*/application/providers/` 新增 Provider 时，必须在同一 PR 中更新 `DEVICE_ARCHITECTURE.md`

**检查清单**:
```
✅ 新增 Provider 代码
✅ 更新架构文档中的 Provider 列表
✅ 更新架构图 (如有影响)
```

**自动化**: 👁️ PR 模板检查

```markdown
## PR Checklist
- [ ] 如新增 Provider，已更新 `/docs/architecture/DEVICE_ARCHITECTURE.md`
- [ ] 如修改分层，已更新架构图
```

---

## 第五部分：代码质量规则 (QUALITY)

### QUAL-01: 不得使用 dynamic 作为返回类型 🟡

**规则**: Provider 和 public 方法不得返回 `dynamic`

**禁止**:
```dart
// ❌ 错误示例
final deviceFieldStreamProvider =
    Provider.family<Stream<dynamic>, String>((ref, fieldPath) {
  // ...
});
```

**正确**:
```dart
// ✅ 正确示例
final deviceFieldStreamProvider =
    Provider.family<Stream<Object?>, String>((ref, fieldPath) {
  // ... 返回 Object? 而非 dynamic
});
```

**例外**: 内部实现可以使用 `dynamic`，但 API 边界必须类型安全

**自动化**: ✅ Lint 规则 (`avoid_types_as_parameter_names`, `avoid_dynamic_calls`)

---

### QUAL-02: 公共 API 必须有文档注释 🟢

**规则**: 所有 Provider 和 public 方法必须有 `///` 文档注释

**最低要求**:
```dart
/// [一句话描述]
///
/// [详细说明（可选）]
///
/// **Example**:
/// ```dart
/// [使用示例]
/// ```
final xxxProvider = ...;
```

**自动化**: ✅ Lint 规则 (`public_member_api_docs`)

---

## 第六部分：执行流程

### 代码审查流程

```
1. 开发者提交 PR
     ↓
2. CI 自动检查
   - Lint 规则
   - 依赖方向脚本
   - 单元测试
     ↓
3. 人工审查 (使用此规则文档)
   - 检查分层规则
   - 检查订阅管理
   - 检查架构一致性
     ↓
4. 反馈 (引用规则 ID)
   - "违反 LAYER-01: 不得直接导入 SDK"
   - "违反 SUB-01: Timer 未取消"
     ↓
5. 修复 → 重新审查
     ↓
6. 合并
```

### 严重程度处理

| 严重程度 | 处理方式 |
|---------|---------|
| 🔴 阻断合并 | 必须修复才能合并 PR |
| 🟡 必须修复 | 可合并但需在 2 个工作日内修复 |
| 🟢 建议优化 | 可合并，后续迭代优化 |

---

## 附录：自动化工具配置

### A. Lint 规则配置

```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    # 已有规则
    - avoid_dynamic_calls
    - avoid_types_as_parameter_names
    - public_member_api_docs
    - depend_on_referenced_packages
    
    # 自定义规则 (需要 custom_lint 包)
    # - no_direct_sdk_import_in_ui
    # - no_flutter_in_providers

analyzer:
  errors:
    avoid_dynamic_calls: warning
    public_member_api_docs: info
```

### B. 依赖检查脚本

```bash
#!/bin/bash
# tools/check_architecture.sh

echo "🔍 检查架构规则..."

# LAYER-01: UI 层不得导入 SDK
if grep -r "import.*lava_device_sdk" lib/pages/ lib/widgets/ 2>/dev/null; then
  echo "❌ LAYER-01 违规: UI 层导入了 SDK"
  exit 1
fi

# LAYER-03: Provider 不得导入 Flutter
if grep -r "import.*flutter/material" lib/features/*/application/providers/ 2>/dev/null; then
  echo "❌ LAYER-03 违规: Provider 导入了 Flutter"
  exit 1
fi

# SUB-01: Timer 检查
for file in $(grep -rl "Timer.periodic" lib/); do
  if ! grep -q "\.cancel()" "$file"; then
    echo "⚠️ SUB-01 警告: $file 中 Timer 可能未取消"
  fi
done

echo "✅ 架构检查通过"
```

### C. CI 集成

```yaml
# .github/workflows/code_review.yml
name: Code Review Checks

on: [pull_request]

jobs:
  architecture-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run architecture checks
        run: bash tools/check_architecture.sh
      
      - name: Check documentation sync
        run: |
          # 检查 Provider 是否都在文档中
          bash tools/check_docs_sync.sh
```

---

## 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0 | 2026-06-17 | 初始版本，基于架构审查报告制定 |

---

**维护者**: 架构团队  
**反馈**: 如发现规则不合理或需要补充，请提交 Issue

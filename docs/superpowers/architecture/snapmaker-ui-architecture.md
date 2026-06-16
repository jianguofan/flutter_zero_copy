# Snapmaker Flutter 页面架构设计方案

> 基于对抗审查的可扩展、非侵入式架构

---

## 🎯 核心问题

从 3 个页面（准备/项目/设备）看到的挑战：

1. **布局高度相似** - 都是 `顶部导航 + 左侧面板 + 主内容区`
2. **内容差异很大** - 左侧面板和主内容区在不同页面完全不同
3. **扩展性焦虑** - 担心未来功能侵入现有代码

---

## ✅ 推荐架构：Slot-based Shell + Feature Modules

### 核心思想

**页面是容器（Shell），内容是插件（Modules）**

```dart
// 每个页面只需提供"插件"
PreparePage(
  leftPanel: PrepareConfigPanel(),    // 配置表单
  mainContent: Preview3DView(),       // 3D预览
)

ProjectPage(
  leftPanel: ProjectNavigationPanel(), // 导航列表
  mainContent: ModelGridView(),        // 模型网格
)

DevicePage(
  leftPanel: DeviceControlPanel(),     // 控制面板
  mainContent: Device3DView(),         // 设备视图
)
```

**优势**：
- ✅ 布局逻辑完全复用（AppShell 组件）
- ✅ 新页面只需实现 Panel 和 Content widget
- ✅ 功能扩展不修改现有代码

---

## 📁 目录结构

```
lib/
├── core/
│   ├── app_shell.dart              # 统一布局容器
│   ├── base_panel.dart             # 左侧面板基类
│   ├── base_content.dart           # 主内容区基类
│   └── page_registry.dart          # 页面注册中心（可选）
│
├── features/
│   ├── prepare/                    # 准备页面 Feature
│   │   ├── prepare_page.dart
│   │   ├── widgets/
│   │   │   ├── prepare_config_panel.dart
│   │   │   └── preview_3d_view.dart
│   │   ├── state/
│   │   │   └── prepare_state.dart  # Riverpod/Bloc
│   │   └── models/
│   │       └── print_config.dart
│   │
│   ├── project/                    # 项目页面 Feature
│   │   ├── project_page.dart
│   │   ├── widgets/
│   │   │   ├── project_nav_panel.dart
│   │   │   └── model_grid_view.dart
│   │   └── state/
│   │       └── project_state.dart
│   │
│   └── device/                     # 设备页面 Feature
│       ├── device_page.dart
│       ├── widgets/
│       │   ├── device_control_panel.dart
│       │   └── device_3d_view.dart
│       └── state/
│           └── device_state.dart
│
├── shared/
│   ├── widgets/                    # 跨页面复用组件
│   │   ├── sm_button.dart
│   │   ├── sm_input.dart
│   │   ├── sm_toolbar.dart
│   │   └── sm_tab_bar.dart
│   ├── services/                   # 共享服务
│   │   ├── device_service.dart     # 设备管理
│   │   ├── user_service.dart       # 用户信息
│   │   └── storage_service.dart
│   └── theme/
│       └── app_theme.dart
│
└── main.dart
```

---

## 🏗️ 核心类设计

### 1. AppShell - 统一布局容器

```dart
// core/app_shell.dart

/// 统一的页面布局容器
/// 
/// 所有页面共享这个布局，只需提供左侧面板和主内容区
class AppShell extends StatelessWidget {
  final Widget topBar;
  final Widget leftPanel;
  final Widget mainContent;
  final Widget? rightPanel;  // 可选的右侧面板

  const AppShell({
    required this.topBar,
    required this.leftPanel,
    required this.mainContent,
    this.rightPanel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 顶部导航栏
          topBar,
          
          // 主体区域
          Expanded(
            child: Row(
              children: [
                // 左侧面板（固定宽度或可调节）
                SizedBox(
                  width: 280,
                  child: leftPanel,
                ),
                
                // 分隔线
                const VerticalDivider(width: 1),
                
                // 主内容区（自适应宽度）
                Expanded(
                  child: mainContent,
                ),
                
                // 可选的右侧面板
                if (rightPanel != null) ...[
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 280,
                    child: rightPanel!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

### 2. BasePanel - 左侧面板基类

```dart
// core/base_panel.dart

/// 左侧面板基类
/// 
/// 提供统一的样式和行为，子类只需实现 buildContent()
abstract class BasePanel extends StatelessWidget {
  const BasePanel({Key? key}) : super(key: key);

  /// 面板标题（可选）
  String? get title => null;

  /// 面板内容（子类实现）
  Widget buildContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 可选的标题区域
          if (title != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title!,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          
          // 面板内容
          Expanded(
            child: buildContent(context),
          ),
        ],
      ),
    );
  }
}
```

---

### 3. 具体页面实现示例

#### 准备页面（配置表单）

```dart
// features/prepare/prepare_page.dart

class PreparePage extends StatelessWidget {
  const PreparePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppShell(
      topBar: const PrepareTopBar(),
      leftPanel: const PrepareConfigPanel(),
      mainContent: const Preview3DView(),
    );
  }
}

// features/prepare/widgets/prepare_config_panel.dart

class PrepareConfigPanel extends BasePanel {
  const PrepareConfigPanel({Key? key}) : super(key: key);

  @override
  String get title => '打印配置';

  @override
  Widget buildContent(BuildContext context) {
    // 使用 Riverpod/Bloc 管理状态
    final config = ref.watch(prepareConfigProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 打印机选择
          PrinterSelector(
            value: config.printer,
            onChanged: (printer) => ref.read(prepareConfigProvider.notifier)
                .updatePrinter(printer),
          ),
          
          const SizedBox(height: 16),
          
          // 热床类型
          HeatBedSelector(
            value: config.heatBed,
            onChanged: (bed) => ref.read(prepareConfigProvider.notifier)
                .updateHeatBed(bed),
          ),
          
          const SizedBox(height: 16),
          
          // 工艺参数（折叠面板）
          ProcessParametersSection(
            config: config,
            onChanged: (params) => ref.read(prepareConfigProvider.notifier)
                .updateParameters(params),
          ),
          
          // ... 其他配置项
        ],
      ),
    );
  }
}
```

#### 项目页面（导航列表）

```dart
// features/project/project_page.dart

class ProjectPage extends StatelessWidget {
  const ProjectPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppShell(
      topBar: const ProjectTopBar(),
      leftPanel: const ProjectNavigationPanel(),
      mainContent: const ModelGridView(),
    );
  }
}

// features/project/widgets/project_nav_panel.dart

class ProjectNavigationPanel extends BasePanel {
  const ProjectNavigationPanel({Key? key}) : super(key: key);

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // 用户信息
        const UserInfoCard(),
        
        const Divider(),
        
        // 导航列表
        Expanded(
          child: ListView(
            children: const [
              NavListTile(
                icon: Icons.widgets,
                title: '模型库',
                selected: true,
              ),
              NavListTile(
                icon: Icons.devices,
                title: '我的设备',
              ),
              NavListTile(
                icon: Icons.folder,
                title: '近期文件',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

#### 设备页面（控制面板）

```dart
// features/device/device_page.dart

class DevicePage extends StatelessWidget {
  const DevicePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppShell(
      topBar: const DeviceTopBar(),
      leftPanel: const DeviceControlPanel(),
      mainContent: const Device3DView(),
    );
  }
}

// features/device/widgets/device_control_panel.dart

class DeviceControlPanel extends BasePanel {
  const DeviceControlPanel({Key? key}) : super(key: key);

  @override
  String get title => '设备控制';

  @override
  Widget buildContent(BuildContext context) {
    final deviceState = ref.watch(deviceStateProvider);

    return Column(
      children: [
        // 设备选择
        DeviceSelector(
          devices: deviceState.devices,
          selected: deviceState.currentDevice,
          onChanged: (device) => ref.read(deviceStateProvider.notifier)
              .selectDevice(device),
        ),
        
        const Divider(),
        
        // 控制按钮
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ControlButton(
                icon: Icons.play_arrow,
                label: '开始',
                onPressed: () => ref.read(deviceStateProvider.notifier).start(),
              ),
              ControlButton(
                icon: Icons.stop,
                label: '停止',
                onPressed: () => ref.read(deviceStateProvider.notifier).stop(),
              ),
              // ... 其他控制
            ],
          ),
        ),
      ],
    );
  }
}
```

---

## 🔌 非侵入式扩展机制

### 1. 新增页面 - 零修改现有代码

```dart
// 新增"文件管理"页面
// features/files/files_page.dart

class FilesPage extends StatelessWidget {
  const FilesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppShell(
      topBar: const FilesTopBar(),
      leftPanel: const FileNavigationPanel(),  // 新实现
      mainContent: const FileListView(),       // 新实现
    );
  }
}

// 注册到路由（仅需修改路由配置）
final routes = {
  '/prepare': (_) => const PreparePage(),
  '/project': (_) => const ProjectPage(),
  '/device': (_) => const DevicePage(),
  '/files': (_) => const FilesPage(),  // 新增
};
```

**修改范围**：只修改路由配置文件，0 行现有代码改动 ✅

---

### 2. 扩展左侧面板 - 组合模式

```dart
// 在准备页面增加"高级设置"折叠面板
// 不修改 PrepareConfigPanel，使用组合

class PrepareConfigPanelV2 extends BasePanel {
  const PrepareConfigPanelV2({Key? key}) : super(key: key);

  @override
  Widget buildContent(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 复用原有面板
          const PrepareConfigPanel(),
          
          // 新增高级设置
          ExpansionTile(
            title: const Text('高级设置'),
            children: [
              AdvancedSetting1(),
              AdvancedSetting2(),
            ],
          ),
        ],
      ),
    );
  }
}
```

**修改范围**：创建新类，0 行原有类改动 ✅

---

### 3. 全局功能 - 服务层

```dart
// shared/services/device_monitor_service.dart

/// 全局设备状态监控服务
/// 
/// 通过 Riverpod Provider 注入，任何页面可监听
class DeviceMonitorService {
  final _statusController = StreamController<DeviceStatus>.broadcast();
  
  Stream<DeviceStatus> get statusStream => _statusController.stream;
  
  void startMonitoring() {
    // 启动监控逻辑
  }
  
  void stopMonitoring() {
    // 停止监控
  }
}

// 注册为全局 Provider
final deviceMonitorProvider = Provider((ref) {
  final service = DeviceMonitorService();
  ref.onDispose(() => service.stopMonitoring());
  return service;
});

// 任何页面监听（不侵入页面代码）
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitor = ref.watch(deviceMonitorProvider);
    
    return StreamBuilder<DeviceStatus>(
      stream: monitor.statusStream,
      builder: (context, snapshot) {
        // UI 响应
      },
    );
  }
}
```

**修改范围**：创建新服务，现有页面选择性监听 ✅

---

## 📊 状态管理策略

推荐使用 **Riverpod** (或 Bloc) + Feature-based 状态：

```dart
// features/prepare/state/prepare_state.dart

/// 准备页面的状态
@immutable
class PrepareState {
  final Printer? selectedPrinter;
  final HeatBed? selectedHeatBed;
  final ProcessParameters parameters;
  
  const PrepareState({
    this.selectedPrinter,
    this.selectedHeatBed,
    required this.parameters,
  });
  
  PrepareState copyWith({...}) => PrepareState(...);
}

/// 准备页面的状态管理器
class PrepareStateNotifier extends StateNotifier<PrepareState> {
  PrepareStateNotifier() : super(PrepareState.initial());
  
  void updatePrinter(Printer printer) {
    state = state.copyWith(selectedPrinter: printer);
  }
  
  void updateHeatBed(HeatBed bed) {
    state = state.copyWith(selectedHeatBed: bed);
  }
  
  // ... 其他业务逻辑
}

/// Provider 定义
final prepareStateProvider = StateNotifierProvider<PrepareStateNotifier, PrepareState>(
  (ref) => PrepareStateNotifier(),
);
```

**原则**：
- ✅ 每个 Feature 独立管理自己的状态
- ✅ 跨页面共享状态（如当前设备）放在 `shared/services/`
- ✅ 页面销毁时状态自动清理（Riverpod auto-dispose）

---

## 🧪 测试性

### 单元测试 - 业务逻辑

```dart
// test/features/prepare/state/prepare_state_test.dart

void main() {
  test('PrepareStateNotifier updates printer correctly', () {
    final notifier = PrepareStateNotifier();
    final printer = Printer(id: '1', name: 'Snapmaker U1');
    
    notifier.updatePrinter(printer);
    
    expect(notifier.state.selectedPrinter, equals(printer));
  });
}
```

### Widget 测试 - UI 组件

```dart
// test/features/prepare/widgets/prepare_config_panel_test.dart

void main() {
  testWidgets('PrepareConfigPanel renders correctly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PrepareConfigPanel(),
          ),
        ),
      ),
    );
    
    expect(find.text('打印配置'), findsOneWidget);
    expect(find.byType(PrinterSelector), findsOneWidget);
  });
}
```

**优势**：
- ✅ 状态逻辑与 UI 解耦，可独立测试
- ✅ Widget 可 mock Provider 进行单元测试
- ✅ 页面级集成测试只需组装 Shell

---

## 🚀 迁移计划

### Phase 1: 搭建基础架构（2-3 天）

1. 创建 `core/` 目录
2. 实现 `AppShell`、`BasePanel`、`BaseContent`
3. 定义共享主题和样式

### Phase 2: 重构第一个页面（3-5 天）

1. 选择最简单的页面（如"设备"页面）
2. 拆分为 Panel + Content
3. 迁移到新架构
4. 验证功能完整性

### Phase 3: 迁移其他页面（5-7 天）

1. 复用 Phase 2 的经验
2. 逐个迁移"准备"和"项目"页面
3. 提取共享组件到 `shared/widgets/`

### Phase 4: 优化与文档（2-3 天）

1. 性能优化（减少不必要的 rebuild）
2. 添加单元测试
3. 编写架构文档和示例

**总计**: 12-18 天完成完整迁移

---

## 📝 架构原则总结

1. **页面是容器，内容是插件** - AppShell + Feature Modules
2. **状态按 Feature 隔离** - 避免页面间耦合
3. **共享逻辑下沉到服务层** - 全局功能不侵入页面
4. **组件优先组合而非继承** - 灵活扩展
5. **依赖注入（Riverpod）** - 便于测试和替换

---

## ⚠️ 潜在风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 过度抽象导致复杂度增加 | 中 | 从最简单页面开始，逐步验证架构 |
| 状态管理学习曲线 | 低 | 提供完整示例，团队培训 |
| 迁移工作量大 | 中 | 分阶段迁移，不影响现有功能 |
| 3D视图性能问题 | 高 | 独立优化渲染逻辑，与架构解耦 |

---

## ✅ 下一步行动

1. **讨论确认架构** - 团队评审这个方案
2. **创建 PoC** - 用一个简单页面验证可行性（1 天）
3. **开始 Phase 1** - 搭建基础架构

需要我提供更详细的代码示例或特定部分的设计吗？

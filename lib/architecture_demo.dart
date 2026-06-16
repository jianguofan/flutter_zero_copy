import 'package:flutter/material.dart';

void main() {
  runApp(const SnapmakerArchitectureDemo());
}

class SnapmakerArchitectureDemo extends StatelessWidget {
  const SnapmakerArchitectureDemo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snapmaker Architecture Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D4AA), // Snapmaker 青色
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D4AA),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DemoRouter(),
    );
  }
}

/// 演示路由器 - 切换不同页面
class DemoRouter extends StatefulWidget {
  const DemoRouter({Key? key}) : super(key: key);

  @override
  State<DemoRouter> createState() => _DemoRouterState();
}

class _DemoRouterState extends State<DemoRouter> {
  int _currentIndex = 0;

  final _pages = const [
    PreparePage(),
    ProjectPage(),
    DevicePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.print),
            label: '准备',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder),
            label: '项目',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_input_antenna),
            label: '设备',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 核心架构：AppShell - 统一布局容器
// ============================================================================

/// 统一的页面布局容器
///
/// 所有页面共享这个布局，只需提供左侧面板和主内容区
class AppShell extends StatelessWidget {
  final Widget topBar;
  final Widget leftPanel;
  final Widget mainContent;
  final Widget? rightPanel;

  const AppShell({
    Key? key,
    required this.topBar,
    required this.leftPanel,
    required this.mainContent,
    this.rightPanel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部工具栏
        topBar,

        // 主体区域
        Expanded(
          child: Row(
            children: [
              // 左侧面板（固定宽度）
              SizedBox(
                width: 280,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: leftPanel,
                ),
              ),

              // 主内容区（自适应宽度）
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.background,
                  child: mainContent,
                ),
              ),

              // 可选的右侧面板
              if (rightPanel != null)
                SizedBox(
                  width: 280,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        left: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: rightPanel!,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 核心架构：BasePanel - 左侧面板基类
// ============================================================================

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 可选的标题区域
        if (title != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),

        // 面板内容
        Expanded(
          child: buildContent(context),
        ),
      ],
    );
  }
}

// ============================================================================
// 页面 1: 准备页面（配置表单）
// ============================================================================

class PreparePage extends StatelessWidget {
  const PreparePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppShell(
      topBar: _buildTopBar(context, '准备'),
      leftPanel: const PrepareConfigPanel(),
      mainContent: const Preview3DView(),
    );
  }
}

/// 准备页面的配置面板
class PrepareConfigPanel extends BasePanel {
  const PrepareConfigPanel({Key? key}) : super(key: key);

  @override
  String get title => '打印配置';

  @override
  Widget buildContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 打印机选择
        _buildSection(
          context,
          title: '打印机',
          child: _buildDropdown(
            context,
            value: 'Snapmaker U1',
            items: ['Snapmaker U1', 'Snapmaker A350', 'Snapmaker A250'],
          ),
        ),

        const SizedBox(height: 16),

        // 热床类型
        _buildSection(
          context,
          title: '热床类型',
          child: _buildDropdown(
            context,
            value: '纹理PEI热床',
            items: ['纹理PEI热床', '光面PEI热床', '玻璃热床'],
          ),
        ),

        const SizedBox(height: 16),

        // 喷嘴配置
        _buildSection(
          context,
          title: '喷嘴',
          child: Row(
            children: [
              Expanded(
                child: _buildTabButton(context, '喷嘴 1', selected: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTabButton(context, '喷嘴 2', selected: false),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        _buildTextField(context, label: '直径', value: '0.4mm'),

        const SizedBox(height: 16),

        // 耗材丝
        _buildSection(
          context,
          title: '耗材丝',
          child: Column(
            children: [
              _buildMaterialRow(context, '1', 'Snapmaker PLA', selected: true),
              const SizedBox(height: 8),
              _buildMaterialRow(context, '2', 'Snapmaker PLA', selected: false),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 工艺参数
        ExpansionTile(
          title: const Text('工艺参数'),
          initiallyExpanded: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSlider(context, label: '质量', value: 0.2),
                  _buildSlider(context, label: '强度', value: 0.5),
                  _buildSlider(context, label: '速度', value: 0.8),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 3D预览视图
class Preview3DView extends StatelessWidget {
  const Preview3DView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 模拟3D视图
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.view_in_ar,
                size: 120,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                '3D 预览区域',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.5),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '打印床网格 + 模型视图',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.3),
                    ),
              ),
            ],
          ),
        ),

        // 顶部工具栏
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.view_in_ar), onPressed: () {}),
                IconButton(icon: const Icon(Icons.grid_on), onPressed: () {}),
                const Spacer(),
                IconButton(icon: const Icon(Icons.zoom_in), onPressed: () {}),
                IconButton(icon: const Icon(Icons.zoom_out), onPressed: () {}),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 页面 2: 项目页面（模型库）
// ============================================================================

class ProjectPage extends StatelessWidget {
  const ProjectPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppShell(
      topBar: _buildTopBar(context, '项目'),
      leftPanel: const ProjectNavigationPanel(),
      mainContent: const ModelGridView(),
    );
  }
}

/// 项目导航面板
class ProjectNavigationPanel extends BasePanel {
  const ProjectNavigationPanel({Key? key}) : super(key: key);

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // 用户信息
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Text('JG', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'JG_CN1',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.expand_more),
                onPressed: () {},
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // 导航列表
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildNavTile(
                context,
                icon: Icons.widgets,
                title: '模型库',
                selected: true,
              ),
              _buildNavTile(
                context,
                icon: Icons.devices,
                title: '我的设备',
                selected: false,
              ),
              _buildNavTile(
                context,
                icon: Icons.folder_open,
                title: '近期文件',
                selected: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 模型网格视图
class ModelGridView extends StatelessWidget {
  const ModelGridView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 搜索栏
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                '官方推荐',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {},
              ),
            ],
          ),
        ),

        // 模型网格
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              return _buildModelCard(context, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModelCard(BuildContext context, int index) {
    final models = [
      'IKEA SKÅDIS',
      '咖啡杯解压钥匙扣',
      '可动关节深熊',
      '可爱的法斗眼镜架',
      '中式镂窗_魔塑丝',
      '专业吸纳盒',
      '京剧脸谱装饰品',
      'Snapmaker U1 维护工具',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 模型预览图
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.view_in_ar,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
            ),
          ),

          // 模型信息
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  models[index % models.length],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Snapmaker',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 页面 3: 设备页面（设备控制）
// ============================================================================

class DevicePage extends StatelessWidget {
  const DevicePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppShell(
      topBar: _buildTopBar(context, '设备'),
      leftPanel: const DeviceControlPanel(),
      mainContent: const Device3DView(),
    );
  }
}

/// 设备控制面板
class DeviceControlPanel extends BasePanel {
  const DeviceControlPanel({Key? key}) : super(key: key);

  @override
  String get title => '设备控制';

  @override
  Widget buildContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 设备选择
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '未连接设备',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '点击选择设备',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.expand_more),
                onPressed: () {},
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 控制按钮
        _buildControlButton(
          context,
          icon: Icons.play_arrow,
          label: '开始',
          color: Theme.of(context).colorScheme.primary,
        ),

        const SizedBox(height: 12),

        _buildControlButton(
          context,
          icon: Icons.pause,
          label: '暂停',
          color: Colors.orange,
        ),

        const SizedBox(height: 12),

        _buildControlButton(
          context,
          icon: Icons.stop,
          label: '停止',
          color: Theme.of(context).colorScheme.error,
        ),

        const SizedBox(height: 24),

        // 温度控制
        _buildSection(
          context,
          title: '温度',
          child: Column(
            children: [
              _buildTemperatureRow(context, '喷嘴', 200, 210),
              const SizedBox(height: 8),
              _buildTemperatureRow(context, '热床', 60, 60),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
        ),
        onPressed: () {},
      ),
    );
  }

  Widget _buildTemperatureRow(
    BuildContext context,
    String label,
    int current,
    int target,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: current / target,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Text('$current°C / $target°C'),
      ],
    );
  }
}

/// 设备3D视图
class Device3DView extends StatelessWidget {
  const Device3DView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.precision_manufacturing,
            size: 120,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '设备 3D 模型',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.5),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '显示设备状态和控制',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.3),
                ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 共享 UI 组件
// ============================================================================

Widget _buildTopBar(BuildContext context, String title) {
  return Container(
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        bottom: BorderSide(color: Theme.of(context).dividerColor),
      ),
    ),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          icon: const Icon(Icons.upload),
          label: const Text('导入'),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('新建'),
          onPressed: () {},
        ),
      ],
    ),
  );
}

Widget _buildSection(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}

Widget _buildDropdown(
  BuildContext context, {
  required String value,
  required List<String> items,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      children: [
        Expanded(child: Text(value)),
        const Icon(Icons.expand_more, size: 20),
      ],
    ),
  );
}

Widget _buildTabButton(
  BuildContext context,
  String label, {
  required bool selected,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: selected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surfaceVariant,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Center(
      child: Text(
        label,
        style: TextStyle(
          color: selected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    ),
  );
}

Widget _buildTextField(
  BuildContext context, {
  required String label,
  required String value,
}) {
  return TextField(
    controller: TextEditingController(text: value),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );
}

Widget _buildMaterialRow(
  BuildContext context,
  String number,
  String name, {
  required bool selected,
}) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceVariant,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(name)),
        if (selected) const Icon(Icons.check, size: 20),
      ],
    ),
  );
}

Widget _buildSlider(
  BuildContext context, {
  required String label,
  required double value,
}) {
  return Row(
    children: [
      SizedBox(width: 60, child: Text(label)),
      Expanded(
        child: Slider(
          value: value,
          onChanged: (v) {},
        ),
      ),
      SizedBox(
        width: 40,
        child: Text(
          '${(value * 100).toInt()}%',
          textAlign: TextAlign.right,
        ),
      ),
    ],
  );
}

Widget _buildNavTile(
  BuildContext context, {
  required IconData icon,
  required String title,
  required bool selected,
}) {
  return ListTile(
    leading: Icon(
      icon,
      color: selected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    title: Text(
      title,
      style: TextStyle(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    ),
    selected: selected,
    selectedTileColor:
        Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
    onTap: () {},
  );
}

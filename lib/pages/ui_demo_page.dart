import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/pages/main_frame_page.dart';
import 'package:flutter_zero_copy/pages/projects/projects_page.dart';
import 'package:flutter_zero_copy/pages/device/widgets/device_selector.dart';
import 'package:flutter_zero_copy/pages/device/device_control_full_page.dart';
import 'package:flutter_zero_copy/pages/device/widgets/device_filament_view.dart';

/// UI迁移演示页面
///
/// 展示新的顶部导航、项目页面和设备页面
class UiMigrationDemoPage extends StatefulWidget {
  const UiMigrationDemoPage({super.key});

  @override
  State<UiMigrationDemoPage> createState() => _UiMigrationDemoPageState();
}

class _UiMigrationDemoPageState extends State<UiMigrationDemoPage> {
  // 模拟设备数据
  final List<DeviceInfo> _availableDevices = [
    const DeviceInfo(id: '1', name: 'Snapmaker J1', isConnected: false),
    const DeviceInfo(id: '2', name: 'Snapmaker A350', isConnected: true),
    const DeviceInfo(id: '3', name: 'Snapmaker 2.0', isConnected: false),
  ];

  DeviceInfo? _currentDevice;

  @override
  void initState() {
    super.initState();
    _currentDevice = _availableDevices.firstWhere((d) => d.isConnected);
  }

  @override
  Widget build(BuildContext context) {
    return MainFramePage(
      initialTabIndex: 3, // 默认显示项目页面
      pages: [
        _buildPreparePage(),
        _buildPreviewPage(),
        _buildDevicePage(),
        const ProjectsPage(),
      ],
      pageActions: [
        [], // 准备页面无操作按钮
        [], // 预览页面无操作按钮
        [], // 设备页面无操作按钮
        _buildProjectPageActions(), // 项目页面操作按钮
      ],
    );
  }

  /// 项目页面的右侧操作按钮
  List<Widget> _buildProjectPageActions() {
    return [
      OutlinedButton(
        onPressed: () {
          debugPrint('Open project');
        },
        child: const Text('打开项目'),
      ),
      const SizedBox(width: 8),
      ElevatedButton.icon(
        onPressed: () {
          debugPrint('Create project');
        },
        icon: const Icon(Icons.add, size: 18),
        label: const Text('创建项目'),
      ),
    ];
  }

  /// 准备页面（占位）
  Widget _buildPreparePage() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '准备',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  /// 预览页面（占位）
  Widget _buildPreviewPage() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.preview, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '预览',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  /// 设备页面
  Widget _buildDevicePage() {
    return DeviceControlFullPage(
      currentDevice: _currentDevice,
      availableDevices: _availableDevices,
    );
  }
}

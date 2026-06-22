import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/pages/main_frame_page.dart';
import 'package:flutter_zero_copy/pages/home/home_page.dart';
import 'package:flutter_zero_copy/pages/device/device_control_page.dart';

/// UI迁移演示页面
///
/// 展示新的顶部导航、项目页面和设备页面
class UiMigrationDemoPage extends StatefulWidget {
  const UiMigrationDemoPage({super.key});

  @override
  State<UiMigrationDemoPage> createState() => _UiMigrationDemoPageState();
}

class _UiMigrationDemoPageState extends State<UiMigrationDemoPage> {
  @override
  Widget build(BuildContext context) {
    return MainFramePage(
      initialTabIndex: 0, // 默认显示首页
      pages: [
        const HomePage(), // 首页（包含侧边栏和项目网格）
        _buildPreparePage(),
        _buildPreviewPage(),
        _buildDevicePage(),
      ],
      pageActions: [
        [], // 首页（操作按钮已集成在 HomePage 内部）
        [], // 准备页面
        [], // 预览页面
        [], // 设备页面
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
    return const DeviceControlPage();
  }
}

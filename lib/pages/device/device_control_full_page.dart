import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/pages/device/widgets/device_selector.dart';
import 'package:flutter_zero_copy/pages/device/widgets/device_camera_view.dart';
import 'package:flutter_zero_copy/pages/device/widgets/device_control_left_panel.dart';
import 'package:flutter_zero_copy/pages/device/widgets/device_control_right_panel.dart';
import 'package:flutter_zero_copy/pages/device/widgets/device_print_task_view.dart';
import 'package:flutter_zero_copy/pages/device/widgets/device_filament_view.dart';
import 'package:flutter_zero_copy/pages/device/widgets/device_control_panel.dart';

/// 完整的设备控制页面
///
/// 包含摄像头、控制、打印任务、耗材等多个Tab
class DeviceControlFullPage extends StatefulWidget {
  final DeviceInfo? currentDevice;
  final List<DeviceInfo> availableDevices;

  const DeviceControlFullPage({
    super.key,
    this.currentDevice,
    required this.availableDevices,
  });

  @override
  State<DeviceControlFullPage> createState() => _DeviceControlFullPageState();
}

class _DeviceControlFullPageState extends State<DeviceControlFullPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _cameraVideoTabIndex = 0; // 0: 摄像机, 1: 视频
  DeviceInfo? _currentDevice;

  // 模拟耗材数据
  final List<FilamentInfo> _filaments = [
    const FilamentInfo(
      index: 1,
      type: 'PETG',
      color: Colors.blue,
      isActive: true,
    ),
    const FilamentInfo(
      index: 2,
      type: 'ABS',
      color: Colors.grey,
    ),
    const FilamentInfo(
      index: 3,
      type: 'PLA',
      color: Colors.orange,
    ),
    const FilamentInfo(
      index: 4,
      type: 'PLA',
      color: Colors.black,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentDevice = widget.currentDevice;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = _currentDevice?.isConnected ?? false;

    return Column(
      children: [
        // 设备选择器
        DeviceSelector(
          currentDevice: _currentDevice,
          availableDevices: widget.availableDevices,
          onDeviceSelected: (device) {
            setState(() {
              _currentDevice = device;
            });
          },
        ),

        // Tab栏（仅在设备连接时显示）
        if (isConnected)
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(text: '控制'),
                Tab(text: '打印任务'),
                Tab(text: '耗材'),
              ],
            ),
          ),

        // 主内容区
        Expanded(
          child: isConnected
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    // 控制Tab
                    _buildControlTab(context),
                    // 打印任务Tab
                    _buildPrintTaskTab(context),
                    // 耗材Tab
                    _buildFilamentTab(context),
                  ],
                )
              : _buildDisconnectedState(context),
        ),
      ],
    );
  }

  /// 控制Tab页面
  Widget _buildControlTab(BuildContext context) {
    return Row(
      children: [
        // 左侧温度控制面板
        const DeviceControlLeftPanel(isDeviceConnected: true),

        // 中间摄像头视图
        Expanded(
          child: Column(
            children: [
              // 摄像机/视频切换
              _buildCameraVideoTabs(context),

              // 摄像头画面
              const Expanded(
                child: DeviceCameraView(
                  isDeviceConnected: true,
                  isCameraOn: false,
                ),
              ),
            ],
          ),
        ),

        // 右侧XYZ轴控制
        DeviceControlRightPanel(
          isDeviceConnected: true,
          onMove: (direction) {
            debugPrint('Move: $direction');
          },
        ),
      ],
    );
  }

  /// 摄像机/视频切换Tab
  Widget _buildCameraVideoTabs(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildCameraTab(context, 0, '摄像机'),
          const SizedBox(width: 16),
          _buildCameraTab(context, 1, '视频'),
        ],
      ),
    );
  }

  Widget _buildCameraTab(BuildContext context, int index, String label) {
    final theme = Theme.of(context);
    final isSelected = _cameraVideoTabIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _cameraVideoTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary)
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 打印任务Tab页面
  Widget _buildPrintTaskTab(BuildContext context) {
    return const DevicePrintTaskView(
      taskName: 'lxk-test',
      progress: 0,
      isPrinting: false,
    );
  }

  /// 耗材Tab页面
  Widget _buildFilamentTab(BuildContext context) {
    return DeviceFilamentView(
      filaments: _filaments,
      onFilamentTap: (index) {
        debugPrint('Filament $index tapped');
      },
    );
  }

  /// 未连接设备状态
  Widget _buildDisconnectedState(BuildContext context) {
    return Stack(
      children: [
        // 空状态
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.devices_other,
                size: 80,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                '未连接设备',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),

        // 底部控制面板
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DeviceControlPanel(
            isEnabled: false,
            onControlTap: () {},
            onRefreshTap: () {},
            onHomeTap: () {},
            onToolSelected: (tool) {},
            onPrecisionSelected: (precision) {},
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zero_copy/pages/devices/widgets/add_device_dialog.dart';

/// 我的设备页面
///
/// 显示用户的设备列表，支持添加新设备
class MyDevicesPage extends ConsumerStatefulWidget {
  const MyDevicesPage({super.key});

  @override
  ConsumerState<MyDevicesPage> createState() => _MyDevicesPageState();
}

class _MyDevicesPageState extends ConsumerState<MyDevicesPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('我的设备'),
        actions: [
          // 打开项目按钮
          OutlinedButton(
            onPressed: () {
              debugPrint('打开项目');
            },
            child: const Text('打开项目'),
          ),
          const SizedBox(width: 12),

          // 创建项目按钮
          FilledButton.icon(
            onPressed: () {
              debugPrint('创建项目');
            },
            icon: const Icon(Icons.add, size: 20),
            label: const Text('创建'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              '我的设备',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            // 设备网格
            Expanded(
              child: _buildDeviceGrid(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 设备网格
  Widget _buildDeviceGrid(BuildContext context) {
    // 模拟设备数据
    final devices = <DeviceInfo>[
      DeviceInfo(
        id: '1',
        name: 'u11',
        type: 'LAN',
        ipAddress: null,
        isOnline: true,
      ),
      DeviceInfo(
        id: '2',
        name: 'U1',
        type: 'LAN',
        ipAddress: 'IP:172.18.0.154',
        isOnline: true,
      ),
    ];

    // 如果没有设备，显示空状态
    // if (devices.isEmpty) {
    //   return _buildEmptyState(context);
    // }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        childAspectRatio: 0.9,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: devices.length + 1, // +1 for add button
      itemBuilder: (context, index) {
        if (index < devices.length) {
          return DeviceCard(device: devices[index]);
        } else {
          return const AddDeviceCard();
        }
      },
    );
  }

  /// 空状态
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 设备图标
          Icon(
            Icons.devices_other,
            size: 120,
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
          const SizedBox(height: 24),

          // 提示文本
          Text(
            '暂无设备',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            '添加您的第一台设备开始使用',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 32),

          // 添加设备按钮
          FilledButton.icon(
            onPressed: () {
              _showAddDeviceDialog(context);
            },
            icon: const Icon(Icons.add),
            label: const Text('添加设备'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示添加设备对话框
  void _showAddDeviceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加设备'),
        content: const Text('这里将实现添加设备的功能。\n\n可以通过以下方式添加：\n• 扫描局域网设备\n• 手动输入IP地址\n• USB连接'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              debugPrint('开始扫描设备');
            },
            child: const Text('扫描设备'),
          ),
        ],
      ),
    );
  }
}

/// 设备信息
class DeviceInfo {
  final String id;
  final String name;
  final String type;
  final String? ipAddress;
  final bool isOnline;

  DeviceInfo({
    required this.id,
    required this.name,
    required this.type,
    this.ipAddress,
    required this.isOnline,
  });
}

/// 设备卡片
class DeviceCard extends StatelessWidget {
  final DeviceInfo device;

  const DeviceCard({
    super.key,
    required this.device,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部状态栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // 在线状态指示器
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: device.isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),

                // 连接类型
                Text(
                  device.type,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const Spacer(),

                // 链接图标
                Icon(
                  Icons.link,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),

          // 设备图片
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Image.asset(
                'assets/images/device_placeholder.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.devices,
                    size: 80,
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  );
                },
              ),
            ),
          ),

          // IP地址（如果有）
          if (device.ipAddress != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                device.ipAddress!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // 操作按钮
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 创建建模按钮
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      debugPrint('创建建模: ${device.name}');
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('创建建模'),
                  ),
                ),
                const SizedBox(width: 8),

                // 设备控制按钮
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      debugPrint('设备控制: ${device.name}');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('设备控制'),
                  ),
                ),
              ],
            ),
          ),

          // 设备名称
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
              device.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// 添加设备卡片
class AddDeviceCard extends StatelessWidget {
  const AddDeviceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: InkWell(
        onTap: () {
          debugPrint('添加设备');
          _showAddDeviceDialog(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 加号图标
            Icon(
              Icons.add,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.6),
            ),
            const SizedBox(height: 16),

            // 添加设备文本
            Text(
              '添加设备',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示添加设备对话框
  void _showAddDeviceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加设备'),
        content: const Text('这里将实现添加设备的功能。\n\n可以通过以下方式添加：\n• 扫描局域网设备\n• 手动输入IP地址\n• USB连接'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              debugPrint('开始扫描设备');
            },
            child: const Text('扫描设备'),
          ),
        ],
      ),
    );
  }
}

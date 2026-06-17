import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zero_copy/pages/devices/widgets/add_device_dialog.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_list_provider.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_session_provider.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_metadata_store_provider.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';

/// 我的设备页面
///
/// 显示用户的设备列表，支持添加新设备
/// ✅ 重构后: 使用 Riverpod Provider，不直接导入 SDK
class MyDevicesPage extends ConsumerWidget {
  const MyDevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final devices = ref.watch(deviceListProvider);

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
              child: _buildDeviceGrid(context, ref, devices),
            ),
          ],
        ),
      ),
    );
  }

  /// 设备网格
  Widget _buildDeviceGrid(
    BuildContext context,
    WidgetRef ref,
    List devices,
  ) {
    // 如果没有设备，显示空状态
    if (devices.isEmpty) {
      return _buildEmptyState(context, ref);
    }

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
          return DeviceCard(
            device: devices[index],
            onRemove: () => _removeDevice(ref, devices[index].id),
          );
        } else {
          return AddDeviceCard(
            onDeviceAdded: (deviceInfo) => _handleDeviceAdded(ref, deviceInfo),
          );
        }
      },
    );
  }

  /// 空状态
  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices,
            size: 80,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有添加设备',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮开始添加设备',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          AddDeviceCard(
            onDeviceAdded: (deviceInfo) => _handleDeviceAdded(ref, deviceInfo),
          ),
        ],
      ),
    );
  }

  /// 删除设备
  void _removeDevice(WidgetRef ref, String deviceId) async {
    final registry = ref.read(deviceRegistryProvider);
    await registry.unregister(deviceId);
  }

  /// 处理设备添加
  void _handleDeviceAdded(WidgetRef ref, dynamic deviceInfo) async {
    if (deviceInfo is! Map<String, dynamic>) {
      debugPrint('设备信息格式错误: $deviceInfo');
      return;
    }

    final device = deviceInfo['device'];
    final credentials = deviceInfo['credentials'] as Map<String, dynamic>?;

    if (device == null) {
      debugPrint('设备信息中缺少 device 字段');
      return;
    }

    final sn = credentials?['sn'] as String? ?? 'LAN-${device.ip}';
    final deviceId = sn;

    final info = DeviceInfo(
      id: deviceId,
      name: device.name ?? 'Unknown Device',
      sn: sn,
      networkType: NetworkType.lan,
      ipAddress: device.ip,
      createdAt: DateTime.now(),
    );

    // 持久化
    final registry = ref.read(deviceRegistryProvider);
    await registry.register(info);
    debugPrint('📝 Registry 注册完成: ${info.name}, 当前 registry 设备数: ${registry.devices.length}');

    // 更新响应式状态
    final notifier = ref.read(deviceMetadataStoreProvider.notifier);
    notifier.onDeviceRegistered(info);
    debugPrint('📝 Store 更新完成: ${info.name}, 当前 store 设备数: ${notifier.allDevices.length}');
    debugPrint('📝 Store allDevices: ${notifier.allDevices.map((d) => d.displayName).toList()}');
  }
}

/// 设备卡片
class DeviceCard extends StatelessWidget {
  final dynamic device;
  final VoidCallback onRemove;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          debugPrint('点击设备: ${device.name}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 设备图标和状态
              Row(
                children: [
                  Icon(
                    Icons.print,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const Spacer(),
                  // 在线状态指示器
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: device.isOnline
                          ? Colors.green
                          : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 设备名称
              Text(
                device.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // 设备型号
              if (device.model != null)
                Text(
                  device.model!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),

              const Spacer(),

              // 删除按钮
              Align(
                alignment: Alignment.bottomRight,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemove,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 添加设备卡片
class AddDeviceCard extends StatelessWidget {
  final Function(dynamic) onDeviceAdded;

  const AddDeviceCard({
    super.key,
    required this.onDeviceAdded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () async {
          final result = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (context) => AddDeviceDialog(
              onDeviceAdded: onDeviceAdded,
            ),
          );
          if (result != null && result['success'] == true) {
            onDeviceAdded(result);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 60,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                '添加设备',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// 设备信息模型
class DeviceInfo {
  final String id;
  final String name;
  final bool isConnected;

  const DeviceInfo({
    required this.id,
    required this.name,
    this.isConnected = false,
  });
}

/// 设备选择器组件
///
/// 下拉菜单显示当前设备状态和可用设备列表
class DeviceSelector extends StatelessWidget {
  final DeviceInfo? currentDevice;
  final List<DeviceInfo> availableDevices;
  final ValueChanged<DeviceInfo>? onDeviceSelected;

  const DeviceSelector({
    super.key,
    this.currentDevice,
    required this.availableDevices,
    this.onDeviceSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          // 设备下拉选择
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentDevice?.id,
                hint: Row(
                  children: [
                    Icon(
                      Icons.devices,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '未连接设备',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                items: availableDevices.map((device) {
                  return DropdownMenuItem<String>(
                    value: device.id,
                    child: Row(
                      children: [
                        // 连接状态指示器
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: device.isConnected
                                ? Colors.green
                                : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 设备名称
                        Text(
                          device.name,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: onDeviceSelected != null
                    ? (String? deviceId) {
                        if (deviceId != null) {
                          final device = availableDevices.firstWhere(
                            (d) => d.id == deviceId,
                          );
                          onDeviceSelected!(device);
                        }
                      }
                    : null,
              ),
            ),
          ),

          // 当前设备状态
          if (currentDevice != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: currentDevice!.isConnected
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                currentDevice!.isConnected ? '已连接' : '未连接',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: currentDevice!.isConnected
                      ? Colors.green
                      : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// 设备空状态组件
///
/// 当未连接设备时显示的占位UI
class DeviceEmptyState extends StatelessWidget {
  final VoidCallback? onAddDevice;

  const DeviceEmptyState({
    super.key,
    this.onAddDevice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 大型空状态图标
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 3D打印机图标
                Icon(
                  Icons.view_in_ar,
                  size: 80,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                ),
                // WiFi波纹图标
                Positioned(
                  top: 40,
                  right: 50,
                  child: Icon(
                    Icons.wifi_off,
                    size: 32,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 提示文字
          Text(
            '未连接设备',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '请连接设备以继续',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),

          if (onAddDevice != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddDevice,
              icon: const Icon(Icons.add),
              label: const Text('添加设备'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

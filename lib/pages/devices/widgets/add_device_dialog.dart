import 'package:flutter/material.dart';

/// 添加设备对话框
///
/// 显示不同的设备连接方式
class AddDeviceDialog extends StatelessWidget {
  const AddDeviceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              '添加设备',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // 副标题
            Text(
              '选择一种连接方式',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // 连接方式选项
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Wi-Fi连接
                DeviceConnectionOption(
                  icon: Icons.wifi,
                  title: 'Wi-Fi',
                  description: '扫描局域网设备',
                  onTap: () {
                    Navigator.of(context).pop();
                    debugPrint('选择Wi-Fi连接');
                  },
                ),

                // USB连接
                DeviceConnectionOption(
                  icon: Icons.usb,
                  title: 'USB',
                  description: 'USB连接设备',
                  onTap: () {
                    Navigator.of(context).pop();
                    debugPrint('选择USB连接');
                  },
                ),

                // 以太网连接
                DeviceConnectionOption(
                  icon: Icons.settings_ethernet,
                  title: '以太网',
                  description: '手动输入IP',
                  onTap: () {
                    Navigator.of(context).pop();
                    debugPrint('选择以太网连接');
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    debugPrint('开始扫描设备');
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('扫描设备'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 设备连接方式选项
class DeviceConnectionOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const DeviceConnectionOption({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // 图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),

            // 标题
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),

            // 描述
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

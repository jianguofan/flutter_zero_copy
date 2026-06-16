import 'package:flutter/material.dart';

/// 耗材信息模型
class FilamentInfo {
  final int index;
  final String type; // PETG, ABS, PLA, etc.
  final Color color;
  final bool isActive;
  final bool canEdit;

  const FilamentInfo({
    required this.index,
    required this.type,
    required this.color,
    this.isActive = false,
    this.canEdit = true,
  });
}

/// 耗材管理视图
///
/// 显示4个耗材槽的状态
class DeviceFilamentView extends StatelessWidget {
  final List<FilamentInfo> filaments;
  final Function(int)? onFilamentTap;

  const DeviceFilamentView({
    super.key,
    required this.filaments,
    this.onFilamentTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      color: theme.colorScheme.surfaceContainer,
      child: Column(
        children: [
          // 标题
          Row(
            children: [
              Text(
                '耗材',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // 刷新按钮
              IconButton(
                onPressed: () {
                  debugPrint('Refresh filaments');
                },
                icon: Icon(
                  Icons.refresh,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // 帮助按钮
              IconButton(
                onPressed: () {
                  debugPrint('Show filament help');
                },
                icon: Icon(
                  Icons.help_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // 耗材槽列表
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: filaments.map((filament) {
              return _buildFilamentSlot(context, filament);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilamentSlot(BuildContext context, FilamentInfo filament) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => onFilamentTap?.call(filament.index),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filament.isActive
                ? theme.colorScheme.primary
                : theme.dividerColor,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // 耗材图标
            Stack(
              alignment: Alignment.center,
              children: [
                // 耗材槽背景
                Container(
                  width: 60,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // 耗材颜色圆圈
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: filament.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${filament.index}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 耗材类型标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                filament.type,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 编辑图标或查看图标
            Icon(
              filament.canEdit ? Icons.edit : Icons.visibility,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// 顶部导航栏组件
///
/// 包含4个Tab：准备、预览、设备、项目
/// 右侧区域可以自定义操作按钮
class TopNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final List<Widget>? actions;

  const TopNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
      child: Row(
        children: [
          // Tab 按钮
          _buildTab(context, 0, '准备'),
          _buildTab(context, 1, '预览'),
          _buildTab(context, 2, '设备'),
          _buildTab(context, 3, '项目'),

          const Spacer(),

          // 右侧操作按钮区域
          if (actions != null) ...actions!,

          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, int index, String label) {
    final theme = Theme.of(context);
    final isSelected = currentIndex == index;

    // 第一个Tab显示home图标
    final Widget content = index == 0
        ? Icon(
            Icons.home,
            size: 20,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          )
        : Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          );

    return InkWell(
      onTap: () => onTabChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: content,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// 项目页面标题栏
///
/// 显示"官方推荐"标题和刷新按钮
class ProjectHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onRefresh;
  final bool isRefreshing;

  const ProjectHeader({
    super.key,
    required this.title,
    this.onRefresh,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          // 标题
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(width: 8),

          // 刷新按钮
          if (onRefresh != null)
            IconButton(
              icon: isRefreshing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.refresh,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
              onPressed: isRefreshing ? null : onRefresh,
              tooltip: '刷新',
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

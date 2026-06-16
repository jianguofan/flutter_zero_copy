import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/pages/projects/widgets/project_card.dart';

/// 项目网格布局组件
///
/// 4列响应式网格布局，支持懒加载
class ProjectGrid extends StatelessWidget {
  final List<ProjectCardData> projects;
  final Function(ProjectCardData)? onProjectTap;
  final VoidCallback? onLoadMore;
  final bool isLoading;

  const ProjectGrid({
    super.key,
    required this.projects,
    this.onProjectTap,
    this.onLoadMore,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty && !isLoading) {
      return _buildEmptyState(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算列数：基于可用宽度动态调整
        final crossAxisCount = _calculateCrossAxisCount(constraints.maxWidth);
        const spacing = 16.0;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 0.75, // 宽高比
          ),
          itemCount: projects.length + (isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            // 加载指示器
            if (index == projects.length) {
              return Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            }

            final project = projects[index];

            // 检测是否接近底部，触发加载更多
            if (index == projects.length - 1 && onLoadMore != null && !isLoading) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onLoadMore!();
              });
            }

            return ProjectCard(
              project: project,
              onTap: () => onProjectTap?.call(project),
            );
          },
        );
      },
    );
  }

  /// 根据可用宽度计算列数
  int _calculateCrossAxisCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }

  /// 空状态
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无项目',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

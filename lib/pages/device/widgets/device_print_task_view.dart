import 'package:flutter/material.dart';

/// 打印任务视图
///
/// 显示当前打印任务的进度和信息
class DevicePrintTaskView extends StatelessWidget {
  final String? taskName;
  final int progress; // 0-100
  final String? estimatedTime;
  final bool isPrinting;

  const DevicePrintTaskView({
    super.key,
    this.taskName,
    this.progress = 0,
    this.estimatedTime,
    this.isPrinting = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      color: theme.colorScheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 任务标题
          Row(
            children: [
              // 状态标签
              if (isPrinting)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '空闲',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(width: 8),

              // 任务名称
              Text(
                taskName ?? 'lxk-test',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 主要内容区域
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：3D 模型预览
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '无模型预览',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 32),

              // 右侧：进度信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 文件名占位
                    Text(
                      'XXX',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.3),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 进度百分比
                    Text(
                      '$progress%',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.3),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 层数信息
                    Text(
                      '0/0',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.3),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 预计时间
                    Row(
                      children: [
                        Text(
                          '— 0h 0m',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 进度条
          LinearProgressIndicator(
            value: progress / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary.withOpacity(0.3),
            ),
          ),

          const SizedBox(height: 24),

          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: null,
                  icon: Icon(
                    Icons.play_arrow,
                    color: theme.colorScheme.onSurfaceVariant
                        .withOpacity(0.3),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

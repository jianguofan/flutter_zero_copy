import 'package:flutter/material.dart';

/// 移动方向类型
enum MoveDirectionType {
  xPositive,
  xNegative,
  yPositive,
  yNegative,
  zPositive,
  zNegative,
  xyHome,
}

/// 设备控制右侧面板
///
/// 显示 XYZ 轴控制
class DeviceControlRightPanel extends StatefulWidget {
  final bool isDeviceConnected;
  final Function(MoveDirectionType)? onMove;

  const DeviceControlRightPanel({
    super.key,
    this.isDeviceConnected = false,
    this.onMove,
  });

  @override
  State<DeviceControlRightPanel> createState() =>
      _DeviceControlRightPanelState();
}

class _DeviceControlRightPanelState extends State<DeviceControlRightPanel> {
  int moveStepIndex = 1; // 默认 1mm

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 406,
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // XY 轴控制
          _buildXYControl(context),

          const SizedBox(height: 24),

          // Z 轴控制
          _buildZControl(context),

          const SizedBox(height: 24),

          // 回零按钮
          _buildHomeButton(context),
        ],
      ),
    );
  }

  Widget _buildXYControl(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // 上方按钮（Y+）
        _buildDirectionButton(
          context,
          icon: Icons.arrow_drop_up,
          label: '前出头',
          onPressed: () => _handleMove(MoveDirectionType.yPositive),
        ),

        const SizedBox(height: 8),

        // 中间行：左、XY标签、右
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 左按钮（X-）
            _buildDirectionButton(
              context,
              icon: Icons.arrow_left,
              onPressed: () => _handleMove(MoveDirectionType.xNegative),
            ),

            const SizedBox(width: 16),

            // 中间 XY 标签
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'XY',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // 右按钮（X+）
            _buildDirectionButton(
              context,
              icon: Icons.arrow_right,
              label: '向床',
              onPressed: () => _handleMove(MoveDirectionType.xPositive),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // 下方按钮（Y-）
        _buildDirectionButton(
          context,
          icon: Icons.arrow_drop_down,
          onPressed: () => _handleMove(MoveDirectionType.yNegative),
        ),
      ],
    );
  }

  Widget _buildZControl(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Z+ 按钮
        _buildDirectionButton(
          context,
          icon: Icons.arrow_drop_up,
          onPressed: () => _handleMove(MoveDirectionType.zPositive),
        ),

        const SizedBox(width: 16),

        // Z- 按钮
        _buildDirectionButton(
          context,
          icon: Icons.arrow_drop_down,
          onPressed: () => _handleMove(MoveDirectionType.zNegative),
        ),
      ],
    );
  }

  Widget _buildDirectionButton(
    BuildContext context, {
    required IconData icon,
    String? label,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.dividerColor,
              width: 1,
            ),
          ),
          child: IconButton(
            onPressed: widget.isDeviceConnected ? onPressed : null,
            icon: Icon(
              icon,
              size: 32,
              color: widget.isDeviceConnected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildHomeButton(BuildContext context) {
    final theme = Theme.of(context);

    return ElevatedButton(
      onPressed: widget.isDeviceConnected
          ? () => _handleMove(MoveDirectionType.xyHome)
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      ),
      child: const Text('取出料头'),
    );
  }

  void _handleMove(MoveDirectionType direction) {
    widget.onMove?.call(direction);
    debugPrint('Move: $direction, step: $moveStepIndex mm');
  }
}

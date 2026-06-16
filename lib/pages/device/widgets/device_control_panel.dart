import 'package:flutter/material.dart';

/// 设备控制面板
///
/// 底部固定面板，包含：
/// - 控制按钮 + 刷新
/// - 工具选择器（Tool1-4）
/// - 精度选择（10mm/1mm/0.1mm）
/// - Home归位按钮
class DeviceControlPanel extends StatefulWidget {
  final VoidCallback? onControlTap;
  final VoidCallback? onRefreshTap;
  final VoidCallback? onHomeTap;
  final Function(int)? onToolSelected;
  final Function(String)? onPrecisionSelected;
  final bool isEnabled;

  const DeviceControlPanel({
    super.key,
    this.onControlTap,
    this.onRefreshTap,
    this.onHomeTap,
    this.onToolSelected,
    this.onPrecisionSelected,
    this.isEnabled = true,
  });

  @override
  State<DeviceControlPanel> createState() => _DeviceControlPanelState();
}

class _DeviceControlPanelState extends State<DeviceControlPanel> {
  int _selectedTool = 1;
  String _selectedPrecision = '1mm';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 左侧：控制按钮
            _buildControlButton(context),
            const SizedBox(width: 8),
            _buildRefreshButton(context),

            const SizedBox(width: 24),

            // 中间：工具选择器
            _buildToolSelector(context),

            const Spacer(),

            // 右侧：精度选择 + Home按钮
            _buildPrecisionSelector(context),
            const SizedBox(width: 16),
            _buildHomeButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(BuildContext context) {
    final theme = Theme.of(context);

    return ElevatedButton.icon(
      onPressed: widget.isEnabled ? widget.onControlTap : null,
      icon: const Icon(Icons.tune, size: 18),
      label: const Text('控制'),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildRefreshButton(BuildContext context) {
    final theme = Theme.of(context);

    return IconButton(
      onPressed: widget.isEnabled ? widget.onRefreshTap : null,
      icon: const Icon(Icons.refresh),
      tooltip: '刷新',
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  Widget _buildToolSelector(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (index) {
          final toolNumber = index + 1;
          final isSelected = _selectedTool == toolNumber;

          return InkWell(
            onTap: widget.isEnabled
                ? () {
                    setState(() {
                      _selectedTool = toolNumber;
                    });
                    widget.onToolSelected?.call(toolNumber);
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : Colors.transparent,
                border: index < 3
                    ? Border(
                        right: BorderSide(color: theme.dividerColor),
                      )
                    : null,
              ),
              child: Text(
                'Tool$toolNumber',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPrecisionSelector(BuildContext context) {
    final theme = Theme.of(context);
    final precisions = ['10mm', '1mm', '0.1mm'];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: precisions.asMap().entries.map((entry) {
          final index = entry.key;
          final precision = entry.value;
          final isSelected = _selectedPrecision == precision;

          return InkWell(
            onTap: widget.isEnabled
                ? () {
                    setState(() {
                      _selectedPrecision = precision;
                    });
                    widget.onPrecisionSelected?.call(precision);
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : Colors.transparent,
                border: index < precisions.length - 1
                    ? Border(
                        right: BorderSide(color: theme.dividerColor),
                      )
                    : null,
              ),
              child: Text(
                precision,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHomeButton(BuildContext context) {
    final theme = Theme.of(context);

    return ElevatedButton.icon(
      onPressed: widget.isEnabled ? widget.onHomeTap : null,
      icon: const Icon(Icons.home, size: 18),
      label: const Text('Home'),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

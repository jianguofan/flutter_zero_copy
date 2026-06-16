import 'package:flutter/material.dart';

/// 设备控制左侧面板
///
/// 显示温度控制、LED开关、风扇控制等
class DeviceControlLeftPanel extends StatefulWidget {
  final bool isDeviceConnected;

  const DeviceControlLeftPanel({
    super.key,
    this.isDeviceConnected = false,
  });

  @override
  State<DeviceControlLeftPanel> createState() => _DeviceControlLeftPanelState();
}

class _DeviceControlLeftPanelState extends State<DeviceControlLeftPanel> {
  bool ledOn = false;
  int speedPercentage = 100;
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: isExpanded ? 437 : 109,
      color: theme.colorScheme.surfaceContainer,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // 挤出头温度显示（4个）
            ...List.generate(4, (index) {
              return _buildTemperatureItem(
                context,
                iconPath: 'assets/extruder_$index.svg',
                currentTemp: 27,
                targetTemp: 0,
                label: '挤出头 ${index + 1}',
              );
            }),

            const SizedBox(height: 12),

            // 热床温度
            _buildTemperatureItem(
              context,
              iconPath: 'assets/heated_bed.svg',
              currentTemp: 28,
              targetTemp: 0,
              label: '热床',
            ),

            const SizedBox(height: 12),

            // 腔体温度
            _buildTemperatureItem(
              context,
              iconPath: 'assets/cavity.svg',
              currentTemp: 25,
              targetTemp: 0,
              label: '腔体',
            ),

            const SizedBox(height: 12),

            // LED 开关
            _buildLEDControl(context),

            const SizedBox(height: 12),

            // 速度控制
            _buildSpeedControl(context),

            const SizedBox(height: 12),

            // 风扇控制
            _buildFanControl(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureItem(
    BuildContext context, {
    required String iconPath,
    required int currentTemp,
    required int targetTemp,
    required String label,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // 图标
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.thermostat,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),

          // 温度显示
          Text(
            '$currentTemp / $targetTemp°C',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLEDControl(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Switch(
              value: ledOn,
              onChanged: widget.isDeviceConnected
                  ? (value) {
                      setState(() {
                        ledOn = value;
                      });
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedControl(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.speed,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '$speedPercentage%',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildFanControl(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.air,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '100%',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

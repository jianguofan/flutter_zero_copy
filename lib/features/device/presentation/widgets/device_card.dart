import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_facade.dart';
import 'package:flutter_zero_copy/features/device/presentation/widgets/connection_indicator.dart';

/// A Material card representing a registered device in the list.
///
/// Displays device name, SN, network type, and connection status.
/// Tap to activate, long-press to delete.
class DeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final DeviceConnectionState? connectionState;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const DeviceCard({
    super.key,
    required this.device,
    this.connectionState,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Device icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.threed_rotation,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SN: ${device.sn}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _networkChip(device.networkType),
                        const SizedBox(width: 8),
                        if (device.model != null)
                          Text(
                            device.model!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status
              if (connectionState != null)
                ConnectionIndicator(
                  state: connectionState!,
                  size: 14,
                )
              else
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _networkChip(NetworkType type) {
    final (label, color) = switch (type) {
      NetworkType.lan => ('LAN', Colors.blue),
      NetworkType.wan => ('WAN', Colors.purple),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

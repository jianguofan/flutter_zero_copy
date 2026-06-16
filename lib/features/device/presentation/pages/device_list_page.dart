import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_list_provider.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_session_provider.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_facade.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_session.dart';
import 'package:flutter_zero_copy/features/device/presentation/widgets/device_card.dart';

/// Home screen — list of registered devices.
///
/// Shows all known devices with their connection status.
/// Floating action button navigates to device discovery.
class DeviceListPage extends ConsumerWidget {
  const DeviceListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(deviceListProvider);
    final sessionState = ref.watch(deviceSessionStateProvider);
    final activeDeviceId = sessionState.valueOrNull?.let((s) {
      if (s is DeviceSessionActive) return s.device.info.id;
      return null;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(deviceListProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: devices.isEmpty ? _buildEmptyState(context) : _buildDeviceList(
        context,
        ref,
        devices,
        activeDeviceId,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed('deviceDiscovery'),
        icon: const Icon(Icons.add),
        label: const Text('Add Device'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.devices_other, size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            'No devices yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Add Device" to discover and connect',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(
    BuildContext context,
    WidgetRef ref,
    List<DeviceInfo> devices,
    String? activeDeviceId,
  ) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(deviceListProvider),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          final isActive = device.id == activeDeviceId;

          return DeviceCard(
            device: device,
            connectionState: isActive
                ? DeviceConnectionState.connected
                : DeviceConnectionState.idle,
            onTap: () => _activateDevice(context, ref, device),
            onLongPress: () => _confirmDelete(context, ref, device),
          );
        },
      ),
    );
  }

  Future<void> _activateDevice(
    BuildContext context,
    WidgetRef ref,
    DeviceInfo device,
  ) async {
    final session = ref.read(deviceSessionProvider);
    await session.activate(device.id);
    if (context.mounted) {
      context.pushNamed('deviceDetail', pathParameters: {'id': device.id});
    }
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DeviceInfo device,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Device'),
        content: Text('Remove "${device.name}" from your device list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteDevice(ref, device);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDevice(WidgetRef ref, DeviceInfo device) async {
    final registry = ref.read(deviceRegistryProvider);
    await registry.unregister(device.id);
    ref.invalidate(deviceListProvider);
  }
}

/// Extension for nullable value transformation.
extension _Let<T> on T? {
  R? let<R>(R Function(T) block) {
    final self = this;
    if (self == null) return null;
    return block(self);
  }
}

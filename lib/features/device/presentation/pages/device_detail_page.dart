import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_session_provider.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_command_service_provider.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_command.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_facade.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_session.dart';
import 'package:flutter_zero_copy/features/device/presentation/widgets/connection_indicator.dart';
import 'package:uuid/uuid.dart';

/// Device detail page with monitoring and control tabs.
///
/// Requires a device to be active (via IDeviceSession). If no device
/// is active when the page loads, it shows an error state.
class DeviceDetailPage extends ConsumerStatefulWidget {
  final String deviceId;

  const DeviceDetailPage({super.key, required this.deviceId});

  @override
  ConsumerState<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends ConsumerState<DeviceDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(deviceSessionStateProvider);

    final device = switch (sessionState.valueOrNull) {
      DeviceSessionActive(:final device) => device,
      _ => null,
    };

    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Device')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text('Device not connected',
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
              SizedBox(height: 8),
              Text('Activate a device from the device list',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final info = device.info;

    return Scaffold(
      appBar: AppBar(
        title: Text(info.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ConnectionIndicator(
              state: device.connectionState,
              size: 14,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.monitor), text: 'Monitor'),
            Tab(icon: Icon(Icons.tune), text: 'Control'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MonitorTab(device: device),
          _ControlTab(device: device, deviceId: info.id),
        ],
      ),
    );
  }
}

// ── Monitor Tab ──

class _MonitorTab extends ConsumerWidget {
  final IDeviceFacade device;

  const _MonitorTab({required this.device});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stateAsync = ref.watch(deviceSessionStateProvider);

    final connState = switch (stateAsync.valueOrNull) {
      DeviceSessionActive(:final device) => device.connectionState,
      _ => DeviceConnectionState.idle,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Connection status card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ConnectionIndicator(state: connState, size: 20),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connection', style: theme.textTheme.titleSmall),
                    Text(connState.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Device info card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Device Info', style: theme.textTheme.titleMedium),
                const Divider(),
                _infoRow('Name', device.info.name),
                _infoRow('Serial', device.info.sn),
                _infoRow('Model', device.info.model ?? 'Unknown'),
                _infoRow('Network', device.info.networkType.name.toUpperCase()),
                if (device.info.ipAddress != null)
                  _infoRow('IP', device.info.ipAddress!),
                if (device.info.firmwareVersion != null)
                  _infoRow('Firmware', device.info.firmwareVersion!),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// ── Control Tab ──

class _ControlTab extends ConsumerWidget {
  final IDeviceFacade device;
  final String deviceId;

  const _ControlTab({required this.device, required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Print controls
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Print Controls',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _controlButton(
                      context,
                      ref,
                      icon: Icons.pause,
                      label: 'Pause',
                      method: 'pause',
                      color: Colors.orange,
                    ),
                    _controlButton(
                      context,
                      ref,
                      icon: Icons.stop,
                      label: 'Stop',
                      method: 'stop',
                      color: Colors.red,
                    ),
                    _controlButton(
                      context,
                      ref,
                      icon: Icons.play_arrow,
                      label: 'Resume',
                      method: 'resume',
                      color: Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Emergency stop
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _confirmEstop(context, ref),
            icon: const Icon(Icons.warning, color: Colors.white),
            label: const Text('EMERGENCY STOP',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _controlButton(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String label,
    required String method,
    required Color color,
  }) {
    return Column(
      children: [
        IconButton.filled(
          onPressed: () => _sendCommand(ref, method),
          icon: Icon(icon),
          style: IconButton.styleFrom(backgroundColor: color.withAlpha(30)),
          color: color,
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Future<void> _sendCommand(WidgetRef ref, String method) async {
    final command = DeviceCommand(
      id: const Uuid().v4(),
      deviceId: deviceId,
      method: method,
      createdAt: DateTime.now(),
    );
    await ref.read(sendDeviceCommandProvider(command).future);
  }

  void _confirmEstop(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emergency Stop'),
        content: const Text(
            'This will immediately stop all printer operations. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendCommand(ref, 'emergency_stop');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('STOP'),
          ),
        ],
      ),
    );
  }
}

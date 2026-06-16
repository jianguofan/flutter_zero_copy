import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_zero_copy/features/device/application/providers/device_session_provider.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_info.dart';
import 'package:uuid/uuid.dart';

/// Device discovery page — add new devices via LAN or WAN.
///
/// Tab 1 (LAN): manual IP + access code input
/// Tab 2 (WAN): SN + PIN code input (simplified for Phase 1)
class DeviceDiscoveryPage extends ConsumerStatefulWidget {
  const DeviceDiscoveryPage({super.key});

  @override
  ConsumerState<DeviceDiscoveryPage> createState() =>
      _DeviceDiscoveryPageState();
}

class _DeviceDiscoveryPageState extends ConsumerState<DeviceDiscoveryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _lanIpController = TextEditingController();
  final _lanAccessCodeController = TextEditingController(text: '12345678');
  final _wanSnController = TextEditingController();
  final _wanPinController = TextEditingController();
  bool _isConnecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _lanIpController.dispose();
    _lanAccessCodeController.dispose();
    _wanSnController.dispose();
    _wanPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Device'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.wifi), text: 'LAN'),
            Tab(icon: Icon(Icons.cloud), text: 'WAN'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLanTab(context),
          _buildWanTab(context),
        ],
      ),
    );
  }

  Widget _buildLanTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.wifi, size: 48, color: Colors.blue),
        const SizedBox(height: 16),
        Text(
          'Connect via Local Network',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the IP address of your Snapmaker printer on the same WiFi network.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _lanIpController,
          decoration: const InputDecoration(
            labelText: 'Device IP Address',
            hintText: '192.168.1.100',
            prefixIcon: Icon(Icons.computer),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _lanAccessCodeController,
          decoration: const InputDecoration(
            labelText: 'Access Code',
            hintText: '12345678',
            prefixIcon: Icon(Icons.lock),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
          ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _isConnecting ? null : _connectLan,
            icon: _isConnecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find),
            label: Text(_isConnecting ? 'Connecting...' : 'Connect (LAN)'),
          ),
        ),
      ],
    );
  }

  Widget _buildWanTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.cloud, size: 48, color: Colors.purple),
        const SizedBox(height: 16),
        Text(
          'Connect via Cloud',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Bind your printer using its serial number and PIN code.\nRequires cloud account setup.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _wanSnController,
          decoration: const InputDecoration(
            labelText: 'Serial Number (SN)',
            hintText: 'SNP12345678',
            prefixIcon: Icon(Icons.qr_code),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _wanPinController,
          decoration: const InputDecoration(
            labelText: 'PIN Code',
            hintText: '6-digit code from printer screen',
            prefixIcon: Icon(Icons.pin),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
          ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _isConnecting ? null : _connectWan,
            icon: _isConnecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload),
            label: Text(_isConnecting ? 'Connecting...' : 'Connect (WAN)'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.purple,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'WAN connection requires cloud API setup (Phase 2).',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _connectLan() async {
    final ip = _lanIpController.text.trim();
    if (ip.isEmpty) {
      setState(() => _error = 'Please enter an IP address');
      return;
    }

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    try {
      final registry = ref.read(deviceRegistryProvider);
      final deviceId = const Uuid().v4();

      final device = DeviceInfo(
        id: deviceId,
        name: 'Printer ($ip)',
        sn: 'LAN-$ip',
        networkType: NetworkType.lan,
        ipAddress: ip,
        accessCode: _lanAccessCodeController.text,
        createdAt: DateTime.now(),
      );

      await registry.register(device);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device added successfully')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _error = 'Connection failed: $e');
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  Future<void> _connectWan() async {
    final sn = _wanSnController.text.trim();
    if (sn.isEmpty) {
      setState(() => _error = 'Please enter a serial number');
      return;
    }

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    // WAN connection requires cloud API — deferred to Phase 2.
    // For now, register the device locally.
    try {
      final registry = ref.read(deviceRegistryProvider);
      final deviceId = const Uuid().v4();

      final device = DeviceInfo(
        id: deviceId,
        name: 'Printer ($sn)',
        sn: sn,
        networkType: NetworkType.wan,
        pinCode: _wanPinController.text,
        createdAt: DateTime.now(),
      );

      await registry.register(device);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Device registered (WAN connection deferred)')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _error = 'Registration failed: $e');
    } finally {
      setState(() => _isConnecting = false);
    }
  }
}

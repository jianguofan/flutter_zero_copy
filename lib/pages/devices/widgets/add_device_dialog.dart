import 'package:flutter/material.dart';

/// 添加设备对话框
///
/// 显示设备扫描和连接界面
class AddDeviceDialog extends StatefulWidget {
  const AddDeviceDialog({super.key});

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isScanning = false;

  // 模拟设备列表
  final List<DiscoveredDevice> _devices = [
    DiscoveredDevice(
      name: 'U1Kk',
      ip: '172.18.6.34',
      mode: '局域网模式',
      icon: Icons.print,
    ),
    DiscoveredDevice(
      name: 'HMC',
      ip: '172.18.6.191',
      mode: '局域网模式',
      icon: Icons.print,
    ),
    DiscoveredDevice(
      name: 'U1 雷后',
      ip: '172.18.6.112',
      mode: '局域网模式',
      icon: Icons.print,
    ),
    DiscoveredDevice(
      name: 'YuYu U1',
      ip: '172.18.6.240',
      mode: '局域网模式',
      icon: Icons.print,
    ),
    DiscoveredDevice(
      name: 'qi',
      ip: '172.18.6.136',
      mode: '局域网模式',
      icon: Icons.print,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    // 自动开始扫描
    _startScanning();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
    });
    // 模拟扫描完成
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 580,
        height: 680,
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    '添加设备',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab栏
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'PIN码绑定'),
                  Tab(text: 'IP码搜索绑定'),
                ],
              ),
            ),

            // Tab内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // PIN码绑定页面
                  _buildPinCodeTab(theme),

                  // IP码搜索绑定页面
                  _buildIpSearchTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PIN码绑定Tab
  Widget _buildPinCodeTab(ThemeData theme) {
    return const Center(
      child: Text('PIN码绑定功能待实现'),
    );
  }

  /// IP码搜索绑定Tab
  Widget _buildIpSearchTab(ThemeData theme) {
    return Column(
      children: [
        // 刷新按钮
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                _isScanning ? Icons.refresh : Icons.refresh,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '附近机器',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              if (_isScanning)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _startScanning,
                tooltip: '刷新',
              ),
            ],
          ),
        ),

        // 设备列表
        Expanded(
          child: _isScanning && _devices.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _devices.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return _buildDeviceItem(device, theme);
                  },
                ),
        ),
      ],
    );
  }

  /// 设备列表项
  Widget _buildDeviceItem(DiscoveredDevice device, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          // 设备图标
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              device.icon,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),

          // 设备信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      device.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${device.mode})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  device.ip,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // 连接按钮
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              debugPrint('连接设备: ${device.name} (${device.ip})');
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('连接'),
          ),
        ],
      ),
    );
  }
}

/// 发现的设备
class DiscoveredDevice {
  final String name;
  final String ip;
  final String mode;
  final IconData icon;

  DiscoveredDevice({
    required this.name,
    required this.ip,
    required this.mode,
    required this.icon,
  });
}

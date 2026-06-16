import 'package:flutter/material.dart';

/// 添加设备对话框
///
/// 显示设备扫描和连接界面
class AddDeviceDialog extends StatefulWidget {
  const AddDeviceDialog({super.key});

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  int _selectedTabIndex = 1; // 默认选中IP码搜索绑定
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
    // 自动开始扫描
    _startScanning();
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
            // 深色标题栏
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF37474F), // 深灰色背景
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  const Text(
                    '添加设备',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 白色内容区
            Expanded(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 自定义Tab按钮
                    Row(
                      children: [
                        Expanded(
                          child: _buildTabButton(
                            index: 0,
                            icon: Icons.cloud_outlined,
                            label: 'PIN码绑定',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTabButton(
                            index: 1,
                            icon: Icons.router,
                            label: 'IP码搜索绑定',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 内容区
                    Expanded(
                      child: _selectedTabIndex == 0
                          ? _buildPinCodeTab()
                          : _buildIpSearchTab(theme),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 自定义Tab按钮
  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTabIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1976D2) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF1976D2) : const Color(0xFFBDBDBD),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : const Color(0xFF1976D2),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF1976D2),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PIN码绑定Tab
  Widget _buildPinCodeTab() {
    return const Center(
      child: Text(
        'PIN码绑定功能待实现',
        style: TextStyle(
          color: Color(0xFF757575),
          fontSize: 14,
        ),
      ),
    );
  }

  /// IP码搜索绑定Tab
  Widget _buildIpSearchTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 附近机器标题
        Row(
          children: [
            const Icon(
              Icons.refresh,
              size: 20,
              color: Color(0xFF1976D2),
            ),
            const SizedBox(width: 8),
            const Text(
              '附近机器',
              style: TextStyle(
                color: Color(0xFF1976D2),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            if (_isScanning)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1976D2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // 设备列表
        Expanded(
          child: _isScanning && _devices.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  itemCount: _devices.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return _buildDeviceItem(device);
                  },
                ),
        ),
      ],
    );
  }

  /// 设备列表项
  Widget _buildDeviceItem(DiscoveredDevice device) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          // 设备图标
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.print,
              color: Color(0xFF757575),
              size: 28,
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${device.mode})',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  device.ip,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),

          // 连接按钮
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              debugPrint('连接设备: ${device.name} (${device.ip})');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              elevation: 0,
            ),
            child: const Text(
              '连接',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
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

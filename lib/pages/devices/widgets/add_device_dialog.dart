import 'package:flutter/material.dart';

/// 添加设备对话框
///
/// 参考 lava-orca AddDeviceMainPageView 实现
class AddDeviceDialog extends StatefulWidget {
  const AddDeviceDialog({super.key});

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  bool _isScanning = false;
  bool _showIpInput = false;

  // 模拟设备列表
  final List<DiscoveredDevice> _devices = [
    DiscoveredDevice(
      name: 'U1Kk',
      ip: '172.18.6.34',
      mode: '局域网模式',
      cover: null,
    ),
    DiscoveredDevice(
      name: 'HMC',
      ip: '172.18.6.191',
      mode: '局域网模式',
      cover: null,
    ),
    DiscoveredDevice(
      name: 'U1 雷后',
      ip: '172.18.6.112',
      mode: '局域网模式',
      cover: null,
    ),
    DiscoveredDevice(
      name: 'YuYu U1',
      ip: '172.18.6.240',
      mode: '局域网模式',
      cover: null,
    ),
    DiscoveredDevice(
      name: 'qi',
      ip: '172.18.6.136',
      mode: '局域网模式',
      cover: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
    });
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 623),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 深色导航栏
            _buildNavBar(theme, context),

            // 白色内容区
            Flexible(
              child: Container(
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tab按钮区
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // PIN码绑定按钮
                          SizedBox(
                            width: 217,
                            height: 48,
                            child: _buildPinButton(theme),
                          ),
                          const SizedBox(width: 24),
                          // IP码搜索绑定按钮
                          SizedBox(
                            width: 217,
                            height: 48,
                            child: _buildIpButton(theme),
                          ),
                        ],
                      ),
                    ),

                    // 附近机器标题
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Text(
                            '附近机器',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _startScanning,
                              icon: Icon(
                                Icons.refresh,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 设备列表
                    Flexible(
                      child: _buildDeviceList(theme),
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

  /// 导航栏
  Widget _buildNavBar(ThemeData theme, BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFF3B4547),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          const Spacer(),
          Text(
            '添加设备',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// PIN码绑定按钮（白色背景+蓝色边框）
  Widget _buildPinButton(ThemeData theme) {
    return ElevatedButton.icon(
      icon: Icon(
        Icons.cloud_outlined,
        size: 24,
        color: theme.colorScheme.primary,
      ),
      label: Text(
        'PIN码绑定',
        style: theme.textTheme.titleMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.primary,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: theme.colorScheme.primary,
          ),
        ),
        elevation: 0,
      ),
      onPressed: () {
        debugPrint('PIN码绑定');
      },
    );
  }

  /// IP码搜索绑定按钮（蓝色背景+白色文字）
  Widget _buildIpButton(ThemeData theme) {
    return ElevatedButton.icon(
      icon: Icon(
        Icons.router,
        size: 24,
        color: theme.colorScheme.onPrimary,
      ),
      label: Text(
        'IP码搜索绑定',
        style: theme.textTheme.titleMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onPrimary,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
      onPressed: () {
        debugPrint('IP码搜索绑定');
      },
    );
  }

  /// 设备列表
  Widget _buildDeviceList(ThemeData theme) {
    if (_isScanning && _devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '正在搜索设备',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                ),
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final device = _devices[index];
        return _buildDeviceCard(device, theme);
      },
    );
  }

  /// 设备卡片
  Widget _buildDeviceCard(DiscoveredDevice device, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E6EB)),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Row(
        children: [
          // 设备图片
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 40,
              height: 40,
              color: const Color(0xFFF5F5F5),
              child: const Icon(Icons.print, color: Color(0xFF757575)),
            ),
          ),
          const SizedBox(width: 8),

          // 设备信息
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    '${device.name}\n${device.ip}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Text(
                  ' (${device.mode})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 连接按钮
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              debugPrint('连接设备: ${device.name} (${device.ip})');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              elevation: 0,
            ),
            child: Text(
              '连接',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onPrimary,
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
  final String? cover;

  DiscoveredDevice({
    required this.name,
    required this.ip,
    required this.mode,
    this.cover,
  });
}

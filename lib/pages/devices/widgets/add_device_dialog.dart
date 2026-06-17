import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/services/device_discovery_service.dart';
import 'package:lava_device_sdk/lava_device_sdk.dart';

/// 添加设备对话框
///
/// 支持PIN码绑定和IP码搜索两种模式
class AddDeviceDialog extends StatefulWidget {
  final Function(dynamic)? onDeviceAdded;

  const AddDeviceDialog({
    super.key,
    this.onDeviceAdded,
  });

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  bool _showIpInput = false;
  bool _isPinMode = false; // false=IP搜索模式, true=PIN码模式
  bool _isConnecting = false;

  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();

  final DeviceDiscoveryService _discoveryService = DeviceDiscoveryService();
  List<DiscoveredDevice> _devices = [];
  StreamSubscription? _deviceSubscription;

  // LAN 连接相关
  LanStrategy? _lanStrategy;
  StreamSubscription? _progressSubscription;
  String _connectionProgress = '';
  Map<String, dynamic>? _credentials; // 保存证书信息

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _ipController.dispose();
    _deviceSubscription?.cancel();
    _progressSubscription?.cancel();
    _lanStrategy?.cancel();
    _discoveryService.dispose();
    super.dispose();
  }

  void _startScanning() {
    _deviceSubscription = _discoveryService.deviceStream.listen((devices) {
      if (mounted) {
        setState(() {
          _devices = devices;
        });
      }
    });
    _discoveryService.startScanning();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                child: _isPinMode
                    ? _buildPinModeContent(theme)
                    : _buildIpModeContent(theme),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Spacer(),
          const Text(
            '添加设备',
            style: TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
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

  /// PIN码模式内容
  Widget _buildPinModeContent(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tab按钮区
        _buildTabButtons(theme),

        const SizedBox(height: 24),

        // PIN码输入框
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '请输入设备上显示的PIN码',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                decoration: InputDecoration(
                  hintText: '请输入6位PIN码',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  onPressed: () {
                    final pin = _pinController.text.trim();
                    if (pin.length == 6) {
                      Navigator.of(context).pop();
                      debugPrint('连接设备 PIN: $pin');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入6位PIN码')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text('连接', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// IP搜索模式内容
  Widget _buildIpModeContent(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tab按钮区
        _buildTabButtons(theme),

        // 手动输入IP按钮
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showIpInput = true;
                  });
                },
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('手动输入IP', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        // IP输入框或设备列表
        if (_showIpInput)
          _buildIpInputSection(theme)
        else
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                          onPressed: _discoveryService.isScanning
                              ? null
                              : _startScanning,
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
                Flexible(child: _buildDeviceList(theme)),
              ],
            ),
          ),
      ],
    );
  }

  /// Tab按钮区
  Widget _buildTabButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // PIN码绑定按钮
          SizedBox(
            width: 217,
            height: 48,
            child: ElevatedButton.icon(
              icon: Icon(
                Icons.cloud_outlined,
                size: 24,
                color: _isPinMode
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
              ),
              label: Text(
                'PIN码绑定',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _isPinMode
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isPinMode
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
                foregroundColor: _isPinMode
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.colorScheme.primary),
                ),
                elevation: 0,
              ),
              onPressed: () {
                setState(() {
                  _isPinMode = true;
                  _showIpInput = false;
                });
              },
            ),
          ),
          const SizedBox(width: 24),
          // IP码搜索绑定按钮
          SizedBox(
            width: 217,
            height: 48,
            child: ElevatedButton.icon(
              icon: Icon(
                Icons.router,
                size: 24,
                color: !_isPinMode
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
              ),
              label: Text(
                'IP码搜索绑定',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: !_isPinMode
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: !_isPinMode
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
                foregroundColor: !_isPinMode
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.colorScheme.primary),
                ),
                elevation: 0,
              ),
              onPressed: () {
                setState(() {
                  _isPinMode = false;
                  _showIpInput = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  /// IP输入区域
  Widget _buildIpInputSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showIpInput = false;
                  });
                },
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('返回设备列表', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '手动输入设备IP地址',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ipController,
            decoration: InputDecoration(
              hintText: '例如：192.168.1.100',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: _isConnecting ? null : _connectManualIp,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              child: _isConnecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('连接', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  /// 设备列表
  Widget _buildDeviceList(ThemeData theme) {
    if (_discoveryService.isScanning && _devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('正在搜索设备',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14)),
                const SizedBox(width: 8),
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ],
        ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.devices_other, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text('未发现设备',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('请确保设备已开机并连接到同一网络',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildDeviceCard(_devices[index], theme),
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
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    '${device.name}\n${device.ip}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
                  ),
                ),
                Text(
                  ' (${device.mode})',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isConnecting ? null : () => _connectToDevice(device),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              elevation: 0,
            ),
            child: _isConnecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text('连接',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onPrimary,
                    )),
          ),
        ],
      ),
    );
  }

  /// 连接到设备
  Future<void> _connectToDevice(DiscoveredDevice device) async {
    debugPrint('========== 开始连接设备 ==========');
    debugPrint('设备名称: ${device.name}');
    debugPrint('设备IP: ${device.ip}');

    setState(() {
      _isConnecting = true;
      _connectionProgress = '正在连接到 ${device.name}...';
    });

    try {
      // 创建 LanStrategy 以监听连接进度
      debugPrint('创建 LanStrategy...');
      _lanStrategy = LanStrategy(
        host: device.ip,
        authPort: 1884,
        accessCode: '12345678',
      );

      // 监听连接进度
      _progressSubscription = _lanStrategy!.progressStream.listen((progress) {
        debugPrint('连接进度: ${progress.step}');
        if (progress.error != null) {
          debugPrint('连接错误: ${progress.error}');
        }
        if (mounted) {
          setState(() {
            if (progress.error != null) {
              _connectionProgress = '错误: ${progress.error}';
            } else {
              _connectionProgress = progress.step;
            }
          });
        }
      });

      // 显示连接进度对话框
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildConnectionProgressDialog(),
        );
      }

      // 使用 DeviceHub 连接（传入 strategy 以获取进度事件）
      debugPrint('调用 DeviceHub.connectLan...');
      final connectionResult = await DeviceHub.connectLan(
        ip: device.ip,
        authPort: 1884,
        accessCode: '12345678',
        strategy: _lanStrategy,
      );

      if (connectionResult != null) {
        debugPrint('连接结果: 成功');

        // 从连接结果中获取证书信息
        _credentials = {
          'ca': connectionResult.credentials.ca,
          'cert': connectionResult.credentials.cert,
          'key': connectionResult.credentials.key,
          'port': connectionResult.credentials.port,
        };

        debugPrint(
            '证书信息已保存: ca=${_credentials!['ca'] != null}, cert=${_credentials!['cert'] != null}, key=${_credentials!['key'] != null}');

        if (mounted) {
          Navigator.of(context).pop(); // 关闭进度对话框

          debugPrint('========== 连接成功 ==========');
          // 连接成功，返回设备信息、客户端和证书
          Navigator.of(context).pop({
            'success': true,
            'device': device,
            'client': connectionResult.client,
            'credentials': _credentials,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('成功连接到 ${device.name}（证书已保存）'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint('连接结果: 失败');

        if (mounted) {
          Navigator.of(context).pop(); // 关闭进度对话框

          debugPrint('========== 连接失败 ==========');
          debugPrint('失败原因: $_connectionProgress');
          // 连接失败
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('连接失败: $_connectionProgress'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('========== 连接异常 ==========');
      debugPrint('异常信息: $e');
      debugPrint('堆栈跟踪: $stackTrace');

      if (mounted) {
        Navigator.of(context).pop(); // 关闭进度对话框

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接异常: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  /// 连接进度对话框
  Widget _buildConnectionProgressDialog() {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_connectionProgress),
        ],
      ),
    );
  }

  /// 手动连接设备
  Future<void> _connectManualIp() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入IP地址')),
      );
      return;
    }

    // 创建手动设备
    final device = _discoveryService.addManualDevice(ip);
    await _connectToDevice(device);
  }
}

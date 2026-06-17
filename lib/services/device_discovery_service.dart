import 'dart:async';

/// 发现的设备信息
class DiscoveredDevice {
  final String name;
  final String ip;
  final String mode;

  DiscoveredDevice({
    required this.name,
    required this.ip,
    required this.mode,
  });

  @override
  String toString() => 'DiscoveredDevice(name: $name, ip: $ip, mode: $mode)';
}

/// 设备发现服务
///
/// 用于局域网内扫描和发现设备
class DeviceDiscoveryService {
  final _deviceController = StreamController<List<DiscoveredDevice>>.broadcast();
  final List<DiscoveredDevice> _devices = [];
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;

  /// 设备流
  Stream<List<DiscoveredDevice>> get deviceStream => _deviceController.stream;

  /// 是否正在扫描
  bool get isScanning => _isScanning;

  /// 开始扫描设备
  void startScanning() {
    if (_isScanning) return;

    _isScanning = true;
    _devices.clear();

    // 目前简单实现：只发送空列表
    // 实际的设备发现需要通过 mDNS 或网络扫描实现
    // 这里保持接口兼容性，让用户可以使用"手动输入IP"功能
    _deviceController.add(List.from(_devices));

    // 可以在这里添加实际的设备发现逻辑
    // 例如：使用 multicast_dns 包进行 mDNS 扫描
    // 或者扫描本地网段的常用端口

    // 模拟扫描完成
    Future.delayed(const Duration(seconds: 2), () {
      if (_isScanning) {
        _isScanning = false;
        _deviceController.add(List.from(_devices));
      }
    });
  }

  /// 停止扫描
  void stopScanning() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
  }

  /// 手动添加设备
  DiscoveredDevice addManualDevice(String ip) {
    final device = DiscoveredDevice(
      name: 'Manual Device',
      ip: ip,
      mode: 'Manual',
    );

    if (!_devices.any((d) => d.ip == ip)) {
      _devices.add(device);
      _deviceController.add(List.from(_devices));
    }

    return device;
  }

  /// 释放资源
  void dispose() {
    stopScanning();
    _deviceController.close();
  }
}

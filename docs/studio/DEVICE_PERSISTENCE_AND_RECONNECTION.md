# 设备持久化和自动重连功能

## 概述

本文档描述设备信息持久化存储和自动重连机制的实现，确保用户每次启动应用时能自动恢复之前连接的设备。

## 功能特性

### 1. 设备持久化存储
- ✅ 自动保存已连接的设备信息到本地存储
- ✅ 应用重启后自动加载设备列表
- ✅ 记录设备的连接历史和最后连接时间

### 2. 自动重连
- ✅ 应用启动时自动重连所有已保存的设备
- ✅ 定期检查设备在线状态（每 30 秒）
- ✅ 自动重连离线设备

### 3. 手动重连
- ✅ 设备卡片显示在线/离线状态
- ✅ 离线设备显示重连按钮
- ✅ 点击重连按钮手动触发重连

## 架构设计

### 数据模型

#### DeviceInfo

```dart
class DeviceInfo {
  final String id;              // 设备唯一标识
  final String name;            // 设备名称
  final String sn;              // 设备序列号
  final String ip;              // IP 地址
  final String model;           // 设备型号
  final ConnectionMode mode;    // 连接模式 (lan/wan/usb)
  final DeviceClient? client;   // 设备客户端（不持久化）
  final DateTime? lastConnected;// 最后连接时间
  final bool isOnline;          // 在线状态

  // JSON 序列化支持
  Map<String, dynamic> toJson();
  factory DeviceInfo.fromJson(Map<String, dynamic> json);
}
```

**注意**: `client` 字段不会被序列化，每次重连时会创建新的客户端实例。

### 服务层

#### DeviceManagerService

单例服务，负责设备管理的所有逻辑：

```dart
class DeviceManagerService extends ChangeNotifier {
  // 设备存储
  final Map<String, DeviceInfo> _devices = {};
  
  // 状态订阅管理
  final Map<String, StreamSubscription> _stateSubscriptions = {};
  
  // 持久化键
  static const String _prefsKey = 'saved_devices';
  
  // 公开接口
  List<DeviceInfo> get devices;           // 所有设备
  List<DeviceInfo> get onlineDevices;     // 在线设备
  
  Future<void> initialize();              // 初始化服务
  Future<void> addDevice(DeviceInfo device);      // 添加设备
  Future<void> removeDevice(String deviceId);     // 移除设备
  Future<void> updateDevice(DeviceInfo device);   // 更新设备
  Future<bool> reconnectDevice(String deviceId);  // 重连设备
}
```

## 工作流程

### 应用启动流程

```
应用启动
    ↓
初始化 DeviceManagerService
    ↓
加载已保存的设备列表 (_loadSavedDevices)
    ↓
自动重连所有设备 (_autoReconnectDevices)
    ↓
  ┌─────┴─────┐
  ↓           ↓
在线设备    离线设备
  ↓           ↓
保持连接    显示离线状态
```

### 自动重连流程

```
_autoReconnectDevices
    ↓
遍历所有设备
    ↓
  筛选离线设备
    ↓
  ┌─────┴─────┐
  ↓           ↓
LAN设备    其他设备
  ↓           ↓
_reconnectLan  暂未实现
  ↓
DeviceHub.connectLan
  ↓
┌─────┴─────┐
↓           ↓
成功        失败
↓           ↓
更新状态    标记离线
监听状态    等待下次重试
保存到本地
```

### 状态监控流程

```
启动定时器 (每 30 秒)
    ↓
_checkAndReconnectDevices
    ↓
筛选离线设备
    ↓
逐个重连
    ↓
延迟 500ms
    ↓
下一台设备
```

## 详细实现

### 1. 持久化存储

**保存设备列表**:
```dart
Future<void> _saveDevices() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = _devices.values
        .map((d) => d.toJson())
        .toList();
    await prefs.setString(_prefsKey, jsonEncode(devicesJson));
  } catch (e) {
    debugPrint('Failed to save devices: $e');
  }
}
```

**加载设备列表**:
```dart
Future<void> _loadSavedDevices() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = prefs.getString(_prefsKey);
    if (devicesJson != null) {
      final List<dynamic> list = jsonDecode(devicesJson);
      for (var json in list) {
        final device = DeviceInfo.fromJson(json as Map<String, dynamic>);
        _devices[device.id] = device;
      }
      notifyListeners();
    }
  } catch (e) {
    debugPrint('Failed to load devices: $e');
  }
}
```

**存储位置**:
- iOS: NSUserDefaults
- Android: SharedPreferences
- macOS: NSUserDefaults
- Key: `saved_devices`

### 2. 自动重连实现

**初始化时自动重连**:
```dart
Future<void> initialize() async {
  await _loadSavedDevices();
  // 自动重连所有已保存的设备
  await _autoReconnectDevices();
}

Future<void> _autoReconnectDevices() async {
  debugPrint('开始自动重连设备，共 ${_devices.length} 台');

  for (var device in _devices.values.toList()) {
    if (!device.isOnline) {
      debugPrint('尝试重连设备: ${device.name} (${device.ip})');
      await reconnectDevice(device.id);
      // 延迟避免同时发起太多连接
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }
}
```

**LAN 模式重连**:
```dart
Future<bool> _reconnectLan(DeviceInfo device) async {
  try {
    debugPrint('LAN 重连: ${device.ip}');

    // 使用 DeviceHub 连接
    final client = await DeviceHub.connectLan(
      ip: device.ip,
      authPort: 1884,
      accessCode: '12345678',
    );

    if (client != null) {
      debugPrint('重连成功: ${device.name}');

      // 更新设备信息
      final updatedDevice = device.copyWith(
        client: client,
        isOnline: true,
        lastConnected: DateTime.now(),
      );

      _devices[device.id] = updatedDevice;

      // 监听设备状态变化
      _stateSubscriptions[device.id]?.cancel();
      _stateSubscriptions[device.id] = client.state.watch('*').listen(
        (event) {
          _onDeviceStateChanged(device.id);
        },
        onError: (error) {
          debugPrint('设备 ${device.id} 状态错误: $error');
          _updateDeviceOnlineStatus(device.id, false);
        },
      );

      await _saveDevices();
      notifyListeners();
      return true;
    } else {
      debugPrint('重连失败: client 为 null');
      _updateDeviceOnlineStatus(device.id, false);
      return false;
    }
  } catch (e) {
    debugPrint('LAN 重连异常: $e');
    _updateDeviceOnlineStatus(device.id, false);
    return false;
  }
}
```

**重连策略**:
1. **启动时重连**: 应用启动时自动重连所有离线设备
2. **定期重连**: 每 30 秒检查一次离线设备并尝试重连
3. **手动重连**: 用户点击重连按钮立即触发重连
4. **延迟策略**: 每台设备重连之间延迟 500ms，避免网络拥堵

### 3. UI 状态显示

**设备卡片状态指示**:
```dart
// 在线状态指示器
Container(
  width: 8,
  height: 8,
  decoration: BoxDecoration(
    color: device.isOnline ? Colors.green : Colors.grey,
    shape: BoxShape.circle,
  ),
),

// 在线状态文本
Text(
  device.isOnline ? '在线' : '离线',
  style: theme.textTheme.bodySmall?.copyWith(
    color: device.isOnline ? Colors.green : Colors.grey,
    fontWeight: FontWeight.w500,
  ),
),
```

**重连按钮（仅离线时显示）**:
```dart
if (!device.isOnline)
  IconButton(
    icon: const Icon(Icons.refresh, size: 16),
    tooltip: '重新连接',
    onPressed: () async {
      final deviceManager = DeviceManagerService();
      final success = await deviceManager.reconnectDevice(device.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '重连成功' : '重连失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    },
  ),
```

**最后连接时间显示**:
```dart
if (device.lastConnected != null)
  Text(
    '最后连接: ${_formatDateTime(device.lastConnected!)}',
    style: theme.textTheme.bodySmall,
  ),
```

**时间格式化**:
- 1 分钟内: "刚刚"
- 1 小时内: "X 分钟前"
- 1 天内: "X 小时前"
- 7 天内: "X 天前"
- 7 天以上: "MM/DD"

### 4. 定期状态监控

**启动定时器**:
```dart
Timer? _statusMonitorTimer;

void _startDeviceStatusMonitor() {
  _statusMonitorTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
    _checkAndReconnectDevices();
  });
}

@override
void dispose() {
  _statusMonitorTimer?.cancel();
  super.dispose();
}
```

**检查并重连**:
```dart
Future<void> _checkAndReconnectDevices() async {
  final offlineDevices = _deviceManager.devices.where((d) => !d.isOnline).toList();

  if (offlineDevices.isNotEmpty) {
    debugPrint('发现 ${offlineDevices.length} 台离线设备，尝试重连...');
    for (var device in offlineDevices) {
      await _deviceManager.reconnectDevice(device.id);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }
}
```

## 状态管理

### 设备状态订阅

每个连接的设备都会监听其状态变化：

```dart
_stateSubscriptions[device.id] = client.state.watch('*').listen(
  (event) {
    _onDeviceStateChanged(device.id);
  },
  onError: (error) {
    debugPrint('设备 ${device.id} 状态错误: $error');
    _updateDeviceOnlineStatus(device.id, false);
  },
);
```

### 状态更新流程

```
设备状态变化
    ↓
state.watch('*') 触发
    ↓
_onDeviceStateChanged
    ↓
检查状态是否有效
    ↓
_updateDeviceOnlineStatus
    ↓
更新设备 isOnline 字段
    ↓
notifyListeners()
    ↓
UI 自动更新
```

## 错误处理

### 重连失败处理

1. **连接超时**: 标记设备为离线，等待下次重试
2. **网络错误**: 记录日志，标记离线
3. **授权失败**: 标记离线，可能需要用户重新授权
4. **设备不可达**: 标记离线，继续监控

### 日志记录

```dart
debugPrint('开始自动重连设备，共 ${_devices.length} 台');
debugPrint('尝试重连设备: ${device.name} (${device.ip})');
debugPrint('重连成功: ${device.name}');
debugPrint('重连失败: client 为 null');
debugPrint('LAN 重连异常: $e');
```

## 性能优化

### 1. 延迟策略
- 设备重连之间延迟 500ms，避免同时发起大量连接
- 定期检查间隔 30 秒，平衡响应速度和资源消耗

### 2. 资源管理
- 正确取消状态订阅，避免内存泄漏
- 设备移除时清理客户端资源
- 页面销毁时取消定时器

### 3. 批量操作
- 使用 `toList()` 复制列表，避免迭代时修改集合
- 异步操作使用 `await`，确保顺序执行

## 使用示例

### 添加设备

```dart
final deviceInfo = DeviceInfo(
  id: 'lan-${DateTime.now().millisecondsSinceEpoch}',
  name: device.name,
  sn: device.sn,
  ip: device.ip,
  model: device.model,
  mode: ConnectionMode.lan,
  client: client,
  lastConnected: DateTime.now(),
  isOnline: true,
);

await deviceManager.addDevice(deviceInfo);
// 自动保存到本地存储
// 自动开始监听设备状态
```

### 手动重连

```dart
final success = await deviceManager.reconnectDevice(deviceId);
if (success) {
  print('重连成功');
} else {
  print('重连失败');
}
```

### 移除设备

```dart
await deviceManager.removeDevice(deviceId);
// 自动取消状态订阅
// 自动清理客户端资源
// 自动从本地存储删除
```

## 测试场景

### 场景 1: 正常启动
1. 启动应用
2. 自动加载已保存的设备列表
3. 自动重连所有设备
4. 显示在线状态

### 场景 2: 设备离线
1. 设备断电或断网
2. 状态订阅检测到错误
3. 标记设备为离线
4. 30 秒后自动尝试重连

### 场景 3: 手动重连
1. 用户点击重连按钮
2. 立即触发重连
3. 显示重连结果（成功/失败）
4. 更新设备状态

### 场景 4: 设备恢复
1. 离线设备重新上线
2. 定期检查发现设备可达
3. 自动重连成功
4. 更新为在线状态

### 场景 5: 应用重启
1. 关闭应用
2. 重新启动应用
3. 自动加载设备列表（包括离线设备）
4. 自动尝试重连所有设备
5. 显示当前状态

## 未来改进

### 1. 智能重连策略
- 指数退避算法（1s, 2s, 4s, 8s, ...）
- 根据设备历史稳定性调整重连频率
- 网络变化时立即触发重连

### 2. 批量操作
- 批量重连所有离线设备
- 批量移除设备

### 3. 设备分组
- 按位置分组（家庭、办公室等）
- 按状态分组（在线、离线）
- 自定义分组

### 4. 通知机制
- 设备上线/离线通知
- 重连成功/失败通知
- 可配置通知开关

### 5. WAN 和 USB 模式支持
- 实现 WAN 模式重连逻辑
- 实现 USB 模式重连逻辑

## 相关文件

### 核心文件
- `lib/models/device_info.dart` - 设备信息模型
- `lib/services/device_manager_service.dart` - 设备管理服务
- `lib/pages/devices/my_devices_page.dart` - 设备列表页面

### 依赖
- `shared_preferences: ^2.2.0` - 本地存储
- `lava_device_sdk` - 设备 SDK

## 总结

设备持久化和自动重连功能确保了：

1. ✅ **无缝体验**: 用户无需每次启动都重新添加设备
2. ✅ **自动恢复**: 设备离线后自动尝试重连
3. ✅ **状态可见**: 清晰显示设备在线/离线状态
4. ✅ **手动控制**: 用户可以手动触发重连
5. ✅ **资源高效**: 正确管理连接和订阅，避免资源泄漏

这些功能大大提升了应用的用户体验和可靠性。

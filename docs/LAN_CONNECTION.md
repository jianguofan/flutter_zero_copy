# LAN 连接实现文档

## 概述

本文档描述了 Flutter Zero Copy 项目中 LAN 设备连接功能的实现，该实现基于 `lava-device-controll` 项目的 LAN 连接策略。

## 架构设计

### 核心组件

1. **DeviceDiscoveryService** (`lib/services/device_discovery_service.dart`)
   - 负责局域网设备发现
   - 支持手动添加设备（通过 IP）
   - 提供设备列表流式更新

2. **LanConnectionService** (`lib/services/lan_connection_service.dart`)
   - 管理单个设备的 LAN 连接
   - 处理授权流程
   - 维持心跳和状态监控
   - 基于 `LanStrategy` 实现

3. **DeviceManagerService** (`lib/services/device_manager_service.dart`)
   - 管理所有已连接设备
   - 持久化设备信息
   - 设备状态监控和重连

4. **DeviceInfo** (`lib/models/device_info.dart`)
   - 设备信息数据模型
   - 支持 LAN/WAN/USB 多种连接模式

## LAN 连接流程

### 1. 设备发现阶段

```dart
// 创建发现服务
final discoveryService = DeviceDiscoveryService();

// 监听发现的设备
discoveryService.deviceStream.listen((devices) {
  // 更新 UI 显示设备列表
});

// 开始扫描
await discoveryService.startScanning();
```

### 2. 授权和连接阶段

基于 `lava-device-controll` 的 `LanStrategy` 实现：

```
Phase 1: 连接授权客户端 (port 1884)
  ↓
Phase 2: 查询授权状态 (confirm_lan_status)
  ↓
Phase 3a: 如果未授权 → 请求授权 (request_lan_auth)
  ↓
Phase 3b: 等待设备确认 (notify_lan_auth)
  ↓
Phase 4: 获取 TLS 凭证 (cert, key, ca)
  ↓
Phase 5: 使用凭证建立主连接 (port 1884 TLS)
  ↓
Phase 6: 连接成功，启动心跳
```

### 3. 连接代码示例

```dart
// 创建连接服务
final connectionService = LanConnectionService(
  deviceIp: '192.168.1.100',
  authPort: 1884,
  accessCode: '12345678',
);

// 监听连接进度
connectionService.progressStream.listen((progress) {
  print('连接进度: $progress');
});

// 监听连接状态
connectionService.statusStream.listen((status) {
  print('连接状态: $status');
});

// 执行连接
final success = await connectionService.connect();

if (success) {
  // 获取 DeviceClient 进行后续操作
  final client = connectionService.client;
  
  // 发送命令
  await connectionService.sendCommand('server.info');
  
  // 获取设备状态
  final state = connectionService.getDeviceState();
}
```

## UI 集成

### AddDeviceDialog

`lib/pages/devices/widgets/add_device_dialog.dart` 提供了用户友好的设备添加界面：

- **IP 搜索模式**：自动扫描局域网设备
- **PIN 码模式**：通过 PIN 码绑定（WAN 模式）
- **手动输入**：手动输入设备 IP 地址

#### 连接流程

1. 用户选择设备或输入 IP
2. 显示连接进度对话框
3. 执行 LAN 连接流程
4. 连接成功后返回设备信息和 DeviceClient
5. 添加到设备管理器

### MyDevicesPage

`lib/pages/devices/my_devices_page.dart` 显示和管理已连接的设备：

- 设备列表展示
- 在线状态监控
- 设备控制和操作
- 设备移除功能

## 技术细节

### 授权协议

LAN 连接使用 JSON-RPC 2.0 协议进行授权：

```json
// 查询授权状态
{
  "jsonrpc": "2.0",
  "method": "server.client_manager.confirm_lan_status",
  "params": {
    "clientid": "app-1234567890"
  },
  "id": 1
}

// 请求授权
{
  "jsonrpc": "2.0",
  "method": "server.client_manager.request_lan_auth",
  "params": {
    "clientid": "app-1234567890",
    "app_id": "app-1234567890"
  },
  "id": 2
}

// 授权通知 (设备 → 客户端)
{
  "method": "notify_lan_auth",
  "params": [{
    "state": "approve",
    "clientid": "app-1234567890",
    "sn": "SN123456",
    "port": 1884,
    "cert": "-----BEGIN CERTIFICATE-----...",
    "key": "-----BEGIN PRIVATE KEY-----...",
    "ca": "-----BEGIN CERTIFICATE-----..."
  }]
}
```

### TLS 证书处理

设备授权成功后会返回 TLS 证书：

```dart
SecurityContext? secCtx;
if (cert != null && key != null) {
  secCtx = SecurityContext(withTrustedRoots: false)
    ..useCertificateChainBytes(utf8.encode(cert))
    ..usePrivateKeyBytes(utf8.encode(key));
  if (ca != null) {
    secCtx.setTrustedCertificatesBytes(utf8.encode(ca));
  }
}
```

### MQTT 主题

主连接使用以下 MQTT 主题：

- **订阅主题**：
  - `{sn}/response` - 命令响应
  - `{sn}/status` - 状态更新
  - `{sn}/notification` - 通知消息
  - `{sn}` - 通用主题

- **发布主题**：
  - `{sn}/request` - 命令请求

### 心跳机制

使用 `SmartHeartbeatManager` 实现智能心跳：

- **空闲阈值**：30 秒无通信时发送心跳
- **检查间隔**：每 10 秒检查一次
- **心跳方法**：`server.info`
- **健康监控**：通过 `DeviceHealthMonitor` 监控设备健康状态

## 数据持久化

使用 `SharedPreferences` 保存设备信息：

```json
{
  "saved_devices": [
    {
      "id": "lan-1234567890",
      "name": "Snapmaker U1",
      "sn": "SN123456",
      "ip": "192.168.1.100",
      "model": "U1",
      "mode": "lan",
      "lastConnected": "2024-01-01T12:00:00.000Z",
      "isOnline": true
    }
  ]
}
```

## 依赖项

- `lava_device_sdk` - 设备通信 SDK
- `shared_preferences` - 数据持久化
- `flutter_riverpod` - 状态管理

## 使用示例

### 完整的设备添加流程

```dart
// 1. 初始化设备管理器
final deviceManager = DeviceManagerService();
await deviceManager.initialize();

// 2. 显示添加设备对话框
final result = await showDialog<Map<String, dynamic>>(
  context: context,
  builder: (context) => const AddDeviceDialog(),
);

// 3. 处理连接结果
if (result != null && result['success'] == true) {
  final device = result['device'];
  final client = result['client'] as DeviceClient;
  
  // 4. 创建设备信息
  final deviceInfo = DeviceInfo(
    id: 'lan-${DateTime.now().millisecondsSinceEpoch}',
    name: device.name,
    sn: device.sn ?? '',
    ip: device.ip,
    model: device.model ?? 'Unknown',
    mode: ConnectionMode.lan,
    client: client,
    lastConnected: DateTime.now(),
    isOnline: true,
  );
  
  // 5. 添加到设备管理器
  await deviceManager.addDevice(deviceInfo);
}
```

## 故障排查

### 常见问题

1. **连接超时**
   - 检查设备 IP 是否正确
   - 确认设备和客户端在同一网络
   - 检查防火墙设置

2. **授权失败**
   - 确认设备端确认授权
   - 检查 access code 是否正确
   - 查看设备屏幕是否有授权提示

3. **TLS 连接失败**
   - 确认证书正确获取
   - 检查端口 1884 是否可访问
   - 验证 SecurityContext 配置

### 日志调试

启用详细日志：

```dart
// 在 LanConnectionService 中
connectionService.progressStream.listen((progress) {
  debugPrint('LAN Connection: $progress');
});
```

## 未来改进

- [ ] 实现真实的局域网设备发现（UDP 广播或 mDNS）
- [ ] 支持设备自动重连
- [ ] 添加连接质量监控
- [ ] 支持批量设备管理
- [ ] 实现设备固件更新功能

## 参考资料

- [lava-device-controll](https://github.com/snapmaker/lava-device-controll) - 原始实现参考
- [MQTT 协议](https://mqtt.org/) - MQTT 通信协议
- [JSON-RPC 2.0](https://www.jsonrpc.org/specification) - RPC 协议规范

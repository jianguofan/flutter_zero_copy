# LAN 连接授权流程详解

## 概述

本文档详细描述 Snapmaker 设备通过 LAN (局域网) 方式连接和授权的完整流程，包括 MQTT 通信、证书获取和 TLS 连接建立。

## 流程架构图

```
用户点击连接
    ↓
创建 LanStrategy
    ↓
连接到 1884 端口 (未加密 MQTT)
    ↓
订阅 MQTT 话题
    ↓
查询授权状态 (confirm_lan_status)
    ↓
  ┌─────────┴─────────┐
  ↓                   ↓
success           unauthorized/authorizing
  ↓                   ↓
直接获取凭证      请求授权 (request_lan_auth)
  ↓                   ↓
  └─────────┬─────────┘
            ↓
    等待授权通知 (notify_lan_auth)
            ↓
    设备用户确认授权
            ↓
    接收授权通知 (包含证书)
            ↓
    提取 SN、CA、证书、私钥
            ↓
    建立 TLS 连接
            ↓
    连接成功
```

## 详细步骤

### 1. 创建 LanStrategy 实例

**文件**: `packages/lava_device_sdk/lib/src/connection/lan_strategy.dart`

```dart
final strategy = LanStrategy(
  host: '192.168.1.100',      // 设备 IP 地址
  authPort: 1884,             // 未加密 MQTT 端口
  accessCode: '12345678',     // 访问码（默认值）
);
```

**参数说明**:
- `host`: 设备的 IP 地址
- `authPort`: 授权端口，默认 1884（未加密 MQTT）
- `accessCode`: 访问码，用于构建 MQTT 话题前缀

### 2. 连接到授权端口 (1884)

**连接信息**:
```dart
MqttTransport(config: MqttConfig(
  host: '192.168.1.100',
  port: 1884,                          // 未加密端口
  clientId: 'lava-lan-{timestamp}-auth',
  subscribeTopics: [
    '12345678/config/response',        // RPC 响应
    '+/status',                        // 状态通知
    '+/notification',                  // 通用通知
    '12345678/config/notification',    // 授权通知（关键）
  ],
));
```

**关键点**:
- 使用 **未加密** 的 MQTT 连接
- ClientId 格式: `lava-lan-{timestamp}-auth`
- 订阅的话题中，`12345678/config/notification` 是接收授权通知的关键话题

### 3. 查询授权状态

**RPC 调用**: `server.client_manager.confirm_lan_status`

```dart
{
  "jsonrpc": "2.0",
  "method": "server.client_manager.confirm_lan_status",
  "params": {
    "clientid": "lava-lan-1718600000000"
  },
  "id": 1
}
```

**响应格式**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "state": "unauthorized"  // 可能的值: success, unauthorized, authorizing
  }
}
```

**状态说明**:
- `success`: 该客户端已授权，可直接获取凭证
- `unauthorized`: 需要请求授权
- `authorizing`: 正在等待用户确认

### 4. 请求授权

**RPC 调用**: `server.client_manager.request_lan_auth`

```dart
{
  "jsonrpc": "2.0",
  "method": "server.client_manager.request_lan_auth",
  "params": {
    "clientid": "lava-lan-1718600000000",
    "app_id": "app-lava-lan-1718600000000"
  },
  "id": 2
}
```

**参数说明**:
- `clientid`: 客户端标识符，用于设备端识别请求来源
- `app_id`: 应用标识符，用于匹配授权通知

**这一步会触发**:
- 设备屏幕显示授权请求对话框
- 显示 ClientId 和 App ID
- 用户可以选择 "批准" 或 "拒绝"

### 5. 等待授权通知

**通知话题**: `12345678/config/notification`

**通知格式** (approve):
```json
{
  "method": "notify_lan_auth",
  "params": [
    {
      "state": "approve",
      "clientid": "lava-lan-1718600000000",
      "app_id": "app-lava-lan-1718600000000",
      "sn": "ABC123456789",
      "ca": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
      "cert": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
      "key": "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----",
      "port": 1883
    }
  ]
}
```

**通知格式** (denied):
```json
{
  "method": "notify_lan_auth",
  "params": [
    {
      "state": "denied",
      "clientid": "lava-lan-1718600000000",
      "app_id": "app-lava-lan-1718600000000"
    }
  ]
}
```

**关键字段**:
- `state`: `approve` 或 `denied`
- `sn`: 设备序列号
- `ca`: CA 证书（PEM 格式）
- `cert`: 客户端证书（PEM 格式）
- `key`: 客户端私钥（PEM 格式）
- `port`: TLS 连接端口（通常是 1883）

### 6. 提取凭证并建立 TLS 连接

**凭证结构**:
```dart
MqttCredentials(
  host: '192.168.1.100',
  port: 1883,                           // TLS 端口
  clientId: 'lava-lan-1718600000000',
  sn: 'ABC123456789',
  securityContext: SecurityContext(
    withTrustedRoots: false
  )
    ..useCertificateChainBytes(utf8.encode(cert))
    ..usePrivateKeyBytes(utf8.encode(key))
    ..setTrustedCertificatesBytes(utf8.encode(ca)),
  subscribeTopics: ['ABC123456789/report', ...],
  publishTopic: 'ABC123456789/request',
);
```

**TLS 连接**:
- 使用端口 1883（加密）
- 双向 TLS 认证（mTLS）
- 服务端证书由 CA 签名
- 客户端使用设备颁发的证书和私钥

## 消息处理机制

### 单一订阅模式

**实现文件**: `lan_strategy.dart`

```dart
// 创建单一订阅，同时处理 RPC 响应和通知
_msgSub = _authTransport!.messageStream.listen(_onMessage);

void _onMessage(TransportMessage msg) {
  final json = jsonDecode(utf8.decode(msg.payload));

  // 1. 处理 RPC 响应 (有 'id' 字段)
  if (json['id'] != null) {
    final completer = _pending[json['id']];
    completer?.complete(json);
    return;
  }

  // 2. 处理授权通知 (有 'method' 字段)
  if (json['method'] == 'notify_lan_auth') {
    final params = json['params'][0];
    if (params['state'] == 'approve') {
      _authNotificationCompleter?.complete(params);
    }
  }
}
```

### 关键设计原则

1. **单一订阅**: 只创建一个 `messageStream` 订阅，避免消息竞争
2. **消息路由**: 根据消息内容（`id` 或 `method`）分发到不同处理器
3. **事件驱动**: 使用 `Completer` 实现异步等待，而不是创建新订阅

## 常见问题和解决方案

### 问题 1: 授权通知未接收到

**症状**:
- `request_lan_auth` 调用成功
- 设备屏幕显示授权请求
- 用户点击"批准"
- 应用一直等待，最终超时

**原因分析**:
1. ❌ 创建了多个订阅，导致消息竞争
2. ❌ `_onMessage` 只处理 RPC 响应，忽略了通知消息
3. ❌ 数据结构解析错误（期望 `params[0]['result']`，实际是 `params[0]`）

**解决方案**:
1. ✅ 只创建一个 `messageStream` 订阅
2. ✅ `_onMessage` 同时处理 RPC 响应和通知
3. ✅ 正确解析通知数据：证书数据直接在 `params[0]` 层级

### 问题 2: 连接超时

**症状**:
- MQTT 连接失败
- 连接超时

**可能原因**:
1. 设备未开机或不在同一网络
2. IP 地址错误
3. 防火墙阻止连接
4. 端口被占用

**排查步骤**:
```bash
# 1. 检查设备是否在线
ping 192.168.1.100

# 2. 检查端口是否开放
nc -zv 192.168.1.100 1884
nc -zv 192.168.1.100 1883

# 3. 使用 mosquitto_sub 测试 MQTT 连接
mosquitto_sub -h 192.168.1.100 -p 1884 -t '#' -v
```

### 问题 3: 证书验证失败

**症状**:
- 授权通知接收成功
- TLS 连接失败

**可能原因**:
1. CA 证书不正确
2. 客户端证书或私钥格式错误
3. 证书过期

**解决方案**:
```dart
// 验证证书格式
SecurityContext secCtx = SecurityContext(withTrustedRoots: false);
try {
  secCtx.useCertificateChainBytes(utf8.encode(cert));
  secCtx.usePrivateKeyBytes(utf8.encode(key));
  secCtx.setTrustedCertificatesBytes(utf8.encode(ca));
} catch (e) {
  print('Certificate error: $e');
}
```

## 参考实现

### lava-orca 项目

**文件**: `lib/features/device_connections/wcp_connection.dart`

**关键代码片段**:
```dart
// 观察授权客户端消息
_observeAuthClientMessage() {
  _authMessageSub = _checkAuthAvailableClient?.clientDataStream.listen((message) {
    final response = protocol.deserialize(message);

    // 处理授权通知
    if (response['method'] == 'notify_lan_auth') {
      final params = response['params'];
      final state = params[0]['state'];
      final clientId = params[0]['clientid'];

      if (state == 'approve') {
        // 授权成功，更新客户端
        _updateDeviceLanWcpClient(params[0]);
        _authStateStream.addNext("ready");
      } else if (state == 'denied') {
        // 授权被拒绝
        _authStateStream.addNext("rejected");
      }
    }

    // 处理 RPC 响应
    if (response["id"] != null) {
      final completer = _pendingRequests[response["id"]];
      completer?.complete(response);
    }
  });
}
```

## 时序图

```
App                    Device (Port 1884)          Device Screen
 |                            |                           |
 |---MQTT Connect (1884)----->|                           |
 |<---------ACK---------------|                           |
 |                            |                           |
 |---Subscribe Topics-------->|                           |
 |<---------ACK---------------|                           |
 |                            |                           |
 |---confirm_lan_status------>|                           |
 |<----unauthorized-----------|                           |
 |                            |                           |
 |---request_lan_auth-------->|                           |
 |<---------ACK---------------|----Show Dialog----------->|
 |                            |                           |
 |         (等待用户操作)       |                           |
 |                            |                           |
 |                            |<---User Approve-----------|
 |<---notify_lan_auth---------|                           |
 |  (state: approve)          |                           |
 |  (包含 sn/ca/cert/key)      |                           |
 |                            |                           |
 |---Disconnect (1884)------->|                           |
 |                            |                           |
 |                                                        |
 |--------建立 TLS 连接 (Port 1883)----------------------->|
 |<---------TLS Handshake (mTLS)------------------------->|
 |                                                        |
 |------------------连接成功------------------------------>|
```

## 总结

LAN 连接授权流程的核心要点：

1. **双端口设计**: 
   - 1884: 未加密 MQTT，用于授权流程
   - 1883: 加密 MQTT (TLS)，用于正常通信

2. **消息类型**:
   - RPC 响应: 包含 `id` 字段
   - 通知: 包含 `method` 字段

3. **授权流程**:
   - 查询状态 → 请求授权 → 等待通知 → 获取证书 → 建立 TLS 连接

4. **关键话题**:
   - 请求: `{accessCode}/config/request`
   - 响应: `{accessCode}/config/response`
   - 通知: `{accessCode}/config/notification`

5. **证书数据结构**:
   - 直接在 `params[0]` 层级，不是嵌套的 `params[0]['result']`

6. **消息处理**:
   - 单一订阅，统一路由
   - 避免多订阅竞争
   - 同时处理 RPC 响应和通知

## 相关文件

- `packages/lava_device_sdk/lib/src/connection/lan_strategy.dart` - LAN 连接策略实现
- `lib/pages/devices/widgets/add_device_dialog.dart` - 添加设备对话框
- `/Users/jgfan/code/lava_app/lava-orca/lib/features/device_connections/wcp_connection.dart` - 参考实现

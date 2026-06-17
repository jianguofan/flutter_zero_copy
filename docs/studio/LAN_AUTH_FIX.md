# LAN 授权通知接收问题修复

## 问题描述

用户在设备屏幕上点击"批准"授权后，应用仍然显示连接失败，错误信息为"设备授权超时或拒绝"。

## 根本原因

### 1. 消息流竞争问题

**原有实现** (`lan_strategy.dart` line 132):
```dart
sub = _msgSub = _authTransport!.messageStream.listen((msg) {
  // ...
});
```

**问题**: 
- 在 line 62 已经创建了 `_msgSub` 订阅用于处理 RPC 响应
- `_waitForAuthNotification()` 创建新订阅时，**覆盖了** `_msgSub` 引用
- 导致两个订阅同时监听同一个 `messageStream`
- 消息可能被错误的订阅消费

### 2. 通知消息被忽略

**原有实现** (`lan_strategy.dart` line 212-219):
```dart
void _onMessage(TransportMessage msg) {
  try {
    final json = jsonDecode(utf8.decode(msg.payload)) as Map<String, dynamic>;
    final id = json['id'];
    if (id is num && _pending.containsKey(id.toInt())) {
      _pending.remove(id.toInt())!.complete(json);
    }
  } catch (_) {}
}
```

**问题**:
- 只处理包含 `id` 字段的 RPC 响应
- **完全忽略** 了 `notify_lan_auth` 通知（只有 `method` 字段，没有 `id`）
- 授权通知到达后被丢弃，导致超时

### 3. 数据结构解析错误

**原有实现**期望的结构:
```dart
if (p['state'] == 'approve' && p['result'] is Map) {
  completer.complete(p['result'] as Map<String, dynamic>);
}
```

**实际通知结构** (来自 lava-orca 参考实现):
```json
{
  "method": "notify_lan_auth",
  "params": [
    {
      "state": "approve",
      "clientid": "...",
      "app_id": "...",
      "sn": "ABC123456789",        // 证书数据直接在 params[0]
      "ca": "...",
      "cert": "...",
      "key": "...",
      "port": 1883
    }
  ]
}
```

**问题**: 
- 原代码期望 `params[0]['result']['sn']`
- 实际是 `params[0]['sn']`
- 即使通知被接收，也会因为数据结构不匹配而失败

## 修复方案

### 修改 1: 添加授权通知 Completer

```dart
// 添加成员变量
Completer<Map<String, dynamic>?>? _authNotificationCompleter;
```

**作用**: 使用 Completer 模式实现异步等待，而不是创建新订阅

### 修改 2: 简化 _waitForAuthNotification()

**修复后**:
```dart
Future<Map<String, dynamic>?> _waitForAuthNotification() async {
  _authNotificationCompleter = Completer<Map<String, dynamic>?>();

  try {
    return await _authNotificationCompleter!.future.timeout(const Duration(seconds: 30));
  } on TimeoutException {
    return null;
  } finally {
    _authNotificationCompleter = null;
  }
}
```

**改进**:
- ✅ 不再创建新订阅
- ✅ 使用 Completer 等待通知
- ✅ 由统一的 `_onMessage` 处理通知并完成 Completer

### 修改 3: 增强 _onMessage() 处理通知

**修复后**:
```dart
void _onMessage(TransportMessage msg) {
  try {
    final json = jsonDecode(utf8.decode(msg.payload)) as Map<String, dynamic>;

    // 1. 处理 RPC 响应 (有 'id' 字段)
    final id = json['id'];
    if (id is num && _pending.containsKey(id.toInt())) {
      _pending.remove(id.toInt())!.complete(json);
      return;
    }

    // 2. 处理授权通知 (有 'method' 字段)
    final method = json['method'] as String?;
    if (method != null && _authNotificationCompleter != null && !_authNotificationCompleter!.isCompleted) {
      // Handle notify_lan_auth notification (LAN mode)
      if (method == 'notify_lan_auth' && json['params'] is List) {
        final params = json['params'] as List;
        if (params.isNotEmpty && params[0] is Map) {
          final p = params[0] as Map;
          final state = p['state'] as String?;

          if (state == 'approve') {
            // 证书数据直接在 params[0]，不是 params[0]['result']
            _authNotificationCompleter!.complete(p as Map<String, dynamic>);
          } else if (state == 'denied') {
            _authNotificationCompleter!.complete(null);
          }
          return;
        }
      }

      // Handle notify_cloud_auth notification (WAN mode fallback)
      if (method == 'notify_cloud_auth' && json['params'] is List) {
        final params = json['params'] as List;
        if (params.isNotEmpty && params[0] is Map) {
          final p = params[0] as Map;
          final state = p['state'] as String?;

          if (state == 'approve') {
            _authNotificationCompleter!.complete(p as Map<String, dynamic>);
          } else if (state == 'denied') {
            _authNotificationCompleter!.complete(null);
          }
          return;
        }
      }
    }
  } catch (_) {}
}
```

**改进**:
- ✅ 统一处理 RPC 响应和通知
- ✅ 正确解析通知数据结构
- ✅ 支持 `approve` 和 `denied` 两种状态
- ✅ 同时支持 `notify_lan_auth` 和 `notify_cloud_auth`

## 修复前后对比

### 修复前的消息流

```
MQTT Message arrives
    ↓
messageStream (广播流)
    ↓
  ┌─────┴─────┐
  ↓           ↓
_msgSub   新订阅 (在 _waitForAuthNotification 中创建)
  ↓           ↓
_onMessage   解析通知
  ↓           ↓
只处理RPC   试图完成 Completer
  ↓           ↓
通知被忽略   可能竞争失败
```

**问题**: 两个订阅竞争，通知可能被错误的处理器消费

### 修复后的消息流

```
MQTT Message arrives
    ↓
messageStream (广播流)
    ↓
  _msgSub (唯一订阅)
    ↓
_onMessage (统一处理)
    ↓
  ┌─────┴─────┐
  ↓           ↓
有 'id'?   有 'method'?
  ↓           ↓
RPC响应    通知消息
  ↓           ↓
完成RPC    完成授权
Completer  Completer
```

**优势**: 
- 单一订阅，消息路由清晰
- 所有消息类型都能被正确处理
- 避免竞争条件

## 测试验证

### 测试场景 1: 用户批准授权

**操作步骤**:
1. 点击"连接"按钮
2. 等待设备屏幕显示授权请求
3. 在设备上点击"批准"
4. 观察应用反应

**预期结果**:
- ✅ 应用立即接收到授权通知
- ✅ 显示"连接成功"
- ✅ 设备添加到设备列表

### 测试场景 2: 用户拒绝授权

**操作步骤**:
1. 点击"连接"按钮
2. 等待设备屏幕显示授权请求
3. 在设备上点击"拒绝"
4. 观察应用反应

**预期结果**:
- ✅ 应用立即接收到拒绝通知
- ✅ 显示"连接失败: 设备授权被拒绝"
- ✅ 对话框关闭

### 测试场景 3: 授权超时

**操作步骤**:
1. 点击"连接"按钮
2. 等待设备屏幕显示授权请求
3. 不进行任何操作，等待 30 秒
4. 观察应用反应

**预期结果**:
- ✅ 30 秒后自动超时
- ✅ 显示"连接失败: 设备授权超时"
- ✅ 对话框关闭

## 调试建议

### 启用详细日志

在 `_onMessage()` 中添加日志:

```dart
void _onMessage(TransportMessage msg) {
  try {
    final payload = utf8.decode(msg.payload);
    debugPrint('📨 收到消息: $payload');
    
    final json = jsonDecode(payload) as Map<String, dynamic>;

    // RPC 响应
    if (json['id'] != null) {
      debugPrint('📋 RPC 响应: id=${json['id']}');
      // ...
    }

    // 通知
    if (json['method'] != null) {
      debugPrint('🔔 通知: method=${json['method']}');
      // ...
    }
  } catch (e) {
    debugPrint('❌ 消息解析错误: $e');
  }
}
```

### 验证 MQTT 话题订阅

使用 mosquitto_sub 监听所有话题:

```bash
mosquitto_sub -h 192.168.1.100 -p 1884 -t '#' -v
```

观察设备发送的授权通知是通过哪个话题发送的。

## 参考资料

- **lava-orca 实现**: `/Users/jgfan/code/lava_app/lava-orca/lib/features/device_connections/wcp_connection.dart`
  - 行 1546-1611: `_observeAuthClientMessage()` 方法
  - 统一处理 RPC 响应和通知的参考实现

- **LAN 连接流程文档**: `./LAN_CONNECTION_FLOW.md`
  - 完整的连接和授权流程说明

## 修改文件

- `packages/lava_device_sdk/lib/src/connection/lan_strategy.dart`
  - 行 20-26: 添加 `_authNotificationCompleter` 成员变量
  - 行 128-137: 简化 `_waitForAuthNotification()` 方法
  - 行 212-257: 增强 `_onMessage()` 方法处理通知

## 总结

这次修复解决了三个关键问题：

1. **消息流竞争**: 从多订阅改为单订阅 + 消息路由
2. **通知被忽略**: `_onMessage()` 现在能处理通知消息
3. **数据结构错误**: 正确解析 `params[0]` 而不是 `params[0]['result']`

修复后，授权通知能被正确接收和处理，用户在设备上批准授权后，应用能立即响应并完成连接。

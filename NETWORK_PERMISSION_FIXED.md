# macOS 网络权限问题已修复

## ✅ 问题原因
```
SocketException: Connection failed (OS Error: Operation not permitted, errno = 1)
```

这是因为 macOS App Sandbox 默认不允许应用进行网络连接。

## ✅ 已修复
在以下文件中添加了网络客户端权限：

### DebugProfile.entitlements
```xml
<key>com.apple.security.network.client</key>
<true/>
```

### Release.entitlements
```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```

## 📋 下一步操作

1. **停止当前运行的应用**
   - 在应用窗口按 `q` 退出
   - 或在终端按 `Ctrl+C`

2. **重新运行应用**
   ```bash
   cd /Users/jgfan/snapmaker/flutter_zero_copy
   flutter run -d macos
   ```

3. **再次测试 LAN 连接**
   - 点击"添加设备"
   - 输入设备 IP: `172.18.4.61`
   - 点击"连接"
   - 这次应该能成功连接了！

## 🔍 预期的成功日志

```
flutter: ========== 开始连接设备 ==========
flutter: 设备名称: Device at 172.18.4.61
flutter: 设备IP: 172.18.4.61
flutter: 创建 LanStrategy...
flutter: 调用 DeviceHub.connectLan...
flutter: 连接进度: Connecting to device...
flutter: 连接进度: Querying authorization...
flutter: 连接进度: Waiting for device approval... (需要在设备上确认)
flutter: 连接进度: Authorized
flutter: 连接结果: 成功
flutter: ========== 连接成功 ==========
```

## 📝 说明

添加的权限说明：
- `com.apple.security.network.client` - 允许应用作为客户端连接到网络
- `com.apple.security.network.server` - 允许应用接受网络连接（用于心跳等）

这些权限对于 MQTT 连接是必需的。

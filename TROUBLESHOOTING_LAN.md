# LAN 连接失败诊断指南

## 当前状态
- ✅ 应用正在运行
- ✅ 代码已更新，增加了详细的调试日志
- ⏳ 等待查看实际的连接错误信息

## 诊断步骤

### 1. 查看调试日志

现在代码中已经添加了详细的调试日志，当你尝试连接设备时，会在终端看到：

```
========== 开始连接设备 ==========
设备名称: xxx
设备IP: xxx.xxx.xxx.xxx
创建 LanStrategy...
调用 DeviceHub.connectLan...
连接进度: Connecting to device...
连接进度: Querying authorization...
连接进度: Waiting for device approval...
连接结果: 成功/失败
```

### 2. 常见失败原因和解决方案

#### 原因 1: 设备 IP 地址不正确
**症状**: 连接进度停在 "Connecting to device..."
**检查**:
```bash
ping <设备IP>
# 例如: ping 192.168.1.100
```
**解决**: 确认设备的实际 IP 地址

#### 原因 2: 端口不可访问
**症状**: 连接超时或拒绝连接
**检查**:
```bash
nc -zv <设备IP> 1884
# 例如: nc -zv 192.168.1.100 1884
```
**解决**: 
- 检查设备防火墙设置
- 确认端口 1884 已开放

#### 原因 3: Access Code 不正确
**症状**: 连接进度到 "Querying authorization..." 后失败
**检查**: 确认 access code 是否为 `12345678`
**解决**: 查看设备设置中的 access code

#### 原因 4: 设备未在同一局域网
**症状**: 无法连接
**检查**:
```bash
# 检查本机 IP
ifconfig | grep "inet " | grep -v 127.0.0.1

# 确认设备和电脑在同一网段
# 例如都是 192.168.1.x
```

#### 原因 5: MQTT 服务未启动
**症状**: 连接被拒绝
**解决**: 确认设备的 MQTT 服务已启动

#### 原因 6: 缺少必要的依赖
**症状**: 代码抛出异常
**检查**:
```bash
flutter pub get --offline
```

## 实时诊断

### 方法 1: 查看应用控制台输出

如果你在 VS Code 或终端运行，查看控制台输出，会看到类似：

```
flutter: ========== 开始连接设备 ==========
flutter: 设备名称: Snapmaker U1
flutter: 设备IP: 192.168.1.100
flutter: 创建 LanStrategy...
flutter: 调用 DeviceHub.connectLan...
flutter: 连接进度: Connecting to device...
flutter: 连接错误: Auth MQTT 连接失败: xxx
```

### 方法 2: 使用 DevTools

1. 打开 DevTools: http://127.0.0.1:9100?uri=http://127.0.0.1:64644/EYOKps2Quxg=/
2. 切换到 "Logging" 标签
3. 尝试连接设备
4. 查看详细日志

### 方法 3: 网络抓包

```bash
# 使用 tcpdump 抓包
sudo tcpdump -i any -n port 1884

# 或者使用 Wireshark
# 过滤器: tcp.port == 1884
```

## 快速测试

### 测试 1: 使用模拟 IP
在 AddDeviceDialog 中，模拟设备使用的是：
- IP: `192.168.1.100`
- Port: `1884`
- Access Code: `12345678`

### 测试 2: 手动输入真实设备 IP
1. 点击"添加设备"
2. 切换到 "IP码搜索绑定" 模式
3. 点击"手动输入IP"
4. 输入真实设备的 IP 地址
5. 点击"连接"
6. 查看控制台日志

## 下一步

1. **尝试连接设备**
   - 在应用中点击"添加设备"
   - 选择一个设备或手动输入 IP
   - 点击"连接"

2. **查看日志输出**
   - 在运行应用的终端查看
   - 或在 VS Code 的 DEBUG CONSOLE 查看

3. **告诉我具体的错误信息**
   - 复制完整的错误日志
   - 我会帮你分析和解决

## 示例：成功的日志应该是这样的

```
flutter: ========== 开始连接设备 ==========
flutter: 设备名称: Snapmaker U1
flutter: 设备IP: 192.168.1.100
flutter: 创建 LanStrategy...
flutter: 调用 DeviceHub.connectLan...
flutter: 连接进度: Connecting to device...
flutter: 连接进度: Querying authorization...
flutter: 连接进度: Waiting for device approval...
flutter: 连接进度: Authorized
flutter: 连接结果: 成功
flutter: ========== 连接成功 ==========
```

## 联系信息

当你看到错误日志后，请提供：
1. 完整的控制台输出
2. 设备型号和 IP
3. 失败时停留在哪个步骤

我会根据具体错误帮你解决！

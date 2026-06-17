# Fix LAN MQTT Connection and Device Registration

## Summary

修复两个阻塞性 bug：LAN 模式 MQTT TLS 证书验证失败，以及设备连接成功后未注册到 Store 导致 UI 不显示。

## Problem

1. **LAN MQTT TLS 证书验证失败** (`CERTIFICATE_VERIFY_FAILED`): 设备返回客户端证书 (`cert`/`key`/`ca`) 但 SDK 的 `SecurityContext` 使用 `withTrustedRoots: false`，设备 broker 的自签名证书无法通过验证（SAN 不匹配 IP 地址，CA 链不完整）。

2. **设备连接成功后不显示**: `AddDeviceCard._showAddDeviceDialog` 调用 `showDialog` 没有 await 结果；`_handleDeviceAdded` 只有 TODO 注释未实现实际注册。

3. **HiveStorage 未初始化**: `Hive.initFlutter()` 从未调用，且 `DeviceRegistryImpl._persist()` 未调用 `_storage.init()`，导致注册设备时 `LateInitializationError`。

## Solution

| # | 文件 | 改动 |
|---|------|------|
| 1 | `packages/lava_device_sdk/` | 新增 `MqttConfig.allowBadCertificate`，`MqttTransport` 传递给 `client.onBadCertificate`，`DeviceHub` 在 LAN 连接时自动启用 |
| 2 | `my_devices_page.dart` | `AddDeviceCard` await dialog 结果 → `onDeviceAdded` → `_handleDeviceAdded` 创建 `DeviceInfo` → `registry.register()` + `notifier.onDeviceRegistered()` |
| 3 | `main.dart` | 添加 `Hive.initFlutter()` 初始化 |
| 4 | `device_registry_impl.dart` | `_persist()` 添加 `_storage.init()` 兜底 |
| 5 | `store_debug_button.dart` | 新增全局浮动调试面板，实时查看 `DeviceMetadataStore` 数据 |

## Non-goals

- 不改动 WAN 连接流程
- 不重构设备注册架构（遵循现有 Provider 链）

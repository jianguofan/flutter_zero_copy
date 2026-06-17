# Tasks

## Done

- [x] **SDK: 新增 `allowBadCertificate` TLS 配置** — `types.dart` 新增字段，`mqtt_transport.dart` 传递 `onBadCertificate` 给 `MqttServerClient`，`device_hub.dart` 在 `securityContext != null` 时自动启用
- [x] **修复 `AddDeviceCard` 未 await dialog 结果** — `build()` 的 `onTap` 改为 `async`，await `showDialog` 后调用 `onDeviceAdded`
- [x] **实现 `_handleDeviceAdded` 设备注册** — 从 dialog 结果提取 `DiscoveredDevice` + `credentials` → `DeviceInfo` → `registry.register()` → `notifier.onDeviceRegistered()`
- [x] **`_buildEmptyState` 内嵌 `AddDeviceCard`** — 空设备列表时也可直接从空状态页面添加设备
- [x] **添加 `Hive.initFlutter()` 初始化** — 在 `main()` 中调用
- [x] **`_persist()` 添加 `_storage.init()` 兜底** — 防止 Hive box 未初始化
- [x] **新增 `StoreDebugButton` 全局调试面板** — 浮动按钮实时查看 `DeviceMetadataStore` 全部数据（设备信息、遥测、云端字段、快照）
- [x] **新增 `DeviceDiscoveryService`** — 设备发现服务（mDNS/网络扫描占位）

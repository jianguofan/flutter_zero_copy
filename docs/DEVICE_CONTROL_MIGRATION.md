# 📐 设备控制页面 — 架构设计文档

> 更新：2026-06-18
> 状态：✅ Figma 重设计 + Riverpod 架构重构完成

---

## 架构概览

```
                        MQTT (高频遥测, 10+ Hz)
                             │
              写入全部设备    │  全量更新 Map<SN, DeviceMetadata>
                             ▼
              ┌──────────────────────────────┐
              │   Global Layer                │
              │   DeviceMetadataStore         │ ← 全设备数据存储，中间件（校验/合并/staleness）
              │   DeviceMetadataStoreNotifier │ ← StateNotifier, 发布 Map 变化
              └──────────────┬───────────────┘
                             │
          ref.listen()       │ 只取当前 SN 的设备
          + 200ms throttle   │
                             ▼
              ┌──────────────────────────────┐
              │   Page ViewModel Layer         │
              │   DeviceControlViewModel      │ ← FamilyNotifier<PageState, String>
              │   (keyed by SN)               │
              │                               │
              │   职责:                        │
              │   1. 从 Store 扁平化为 PageState │
              │   2. 200ms 温度节流             │
              │   3. 管理页面 UI 状态           │
              │   4. 暴露操作方法               │
              └──────────────┬───────────────┘
                             │
       state = PageState     │ 细粒度 select()
                             ▼
   ┌───────────┬──────────────┬──────────────┬──────────────┐
   │ TempPanel │  XYZPanel    │  PrintTask   │  Camera      │
   │ select:   │  select:     │  select:     │  select:     │
   │ temps,    │  tool,       │  progress,   │  cameraTab   │
   │ fans      │  step        │  layers      │              │
   │           │              │              │              │
   │ Repaint   │  Repaint     │  Repaint     │  Repaint     │
   │ Boundary  │  Boundary    │  Boundary    │  Boundary    │
   └───────────┴──────────────┴──────────────┴──────────────┘
```

### 关键设计决策

| 问题 | 方案 | 理由 |
|------|------|------|
| 全局 Store 变化触发全量重建 | ViewModel + `select()` 细粒度 | 只有值变化的叶子 widget 重建 |
| 温度 MQTT 10+ Hz 推送 | ViewModel 200ms throttle | UI 刷新 ≤5 Hz，感知延迟可接受 |
| 页面 UI 状态放哪 | PageState 内（非 Store） | selectedTool / selectedStep 是纯 UI 状态 |
| 子组件如何读数据 | `ref.watch(provider.select(...))` | 精确到字段级别比较 |
| 如何隔离重绘 | `RepaintBoundary` 包裹各区域 | 阻止兄弟区域不必要的重绘传播 |

---

## 文件结构

```
lib/pages/device/
├── state/
│   └── device_control_page_state.dart   ← 不可变 PageState, ==/hashCode
├── viewmodel/
│   └── device_control_viewmodel.dart    ← FamilyNotifier, 节流, UI 操作
├── device_control_full_page.dart        ← ConsumerWidget, 左右布局
└── widgets/
    ├── device_camera_view.dart          ← 摄像头画面 + 耗材指示
    ├── device_control_left_panel.dart   ← 温度 + 风扇滑块
    ├── device_control_right_panel.dart  ← XYZ 控制 + Tool/Step 选择器
    ├── device_print_task_view.dart      ← 打印进度 + 3D 预览
    ├── device_filament_view.dart        ← 耗材槽管理
    └── device_empty_state.dart          ← 未连接状态
```

---

## 数据流详解

### 1. Global → Page

```dart
// DeviceControlViewModel.build(sn)
ref.listen(deviceMetadataStoreProvider, (prev, next) {
  final device = next[sn];          // 只取当前设备
  if (device != null) _onStoreChanged(device);
});
```

### 2. 节流合并

```dart
void _onStoreChanged(DeviceMetadata meta) {
  _pendingMeta = meta;
  _throttleTimer?.cancel();
  _throttleTimer = Timer(200.ms, () {
    final newState = state.mergeTelemetry(_pendingMeta!);
    if (newState != state) state = newState;  // 值不同才发布
  });
}
```

### 3. UI 细粒度监听

```dart
// 只有 progress 字段变化才重建此 widget
final progress = ref.watch(
  deviceControlViewModelProvider(sn).select((s) => s.progress),
);
```

### 4. `mergeTelemetry` 短路

```dart
// 200ms 窗口内遥测无实质变化 → 返回同一对象 → UI 不重建
if (newNozzleTemp == nozzleTemp1 &&
    newBedTemp == bedTemp &&
    newProgress == progress) {
  return this;  // 短路！
}
```

---

## PageState 字段清单

| 来源 | 字段 | 类型 | 说明 |
|------|------|------|------|
| Store | `sn` | `String` | 设备序列号 |
| Store | `displayName` | `String` | 展示名称 |
| Store | `connectionState` | `DeviceConnectionState` | 8 状态机 |
| Store | `nozzleTemp1-4` | `double` | 4 个挤出机温度 |
| Store | `bedTemp` | `double` | 热床温度 |
| Store | `chamberTemp` | `double` | 腔体温度 |
| Store | `progress` | `int` | 打印进度 0-100 |
| Store | `taskName` | `String?` | 打印任务文件名 |
| Store | `currentLayer` / `totalLayers` | `int` | 层数信息 |
| Store | `remainingMinutes` | `int` | 剩余时间 |
| Store | `filamentUsed` | `double` | 已用耗材 |
| Store | `mainFanSpeed` / `auxFanSpeed` / `exhaustFanSpeed` | `int` | 3 路风扇 |
| UI | `selectedTool` | `int` | 当前工具头 1-4 |
| UI | `selectedStep` | `String` | 步进精度 |
| UI | `cameraTabIndex` | `int` | 摄像机/视频 Tab |
| UI | `isLedOn` | `bool` | LED 开关 |

---

## Figma 布局

```
┌──────────────────────────────────────────────────┐
│ Top Nav (dark)                            1440x72 │
├──────────┬───────────────────────────────────────┤
│ Sidebar  │ Main (scrollable)                     │
│ 262px    │                                       │
│          │ ┌─ Camera Section (535x339) ────────┐ │
│ 设备控制  │ │ 摄像机 | Video   ●●●● 耗材       │ │
│ (active) │ │         [▶ Play]                  │ │
│          │ ├───────────────────────────────────┤ │
│ 固件更新  │ │ UnLoad                           │ │
│          │ ├───────────────────────────────────┤ │
│          │ │ ┌─ 打印任务 ────────────────────┐ │ │
│          │ │ │ [preview] 34% 多色老虎.STL    │ │ │
│          │ │ │ ████░░░░ 0/2100 2h 34m       │ │ │
│          │ │ └──────────────────────────────┘ │ │
│          │ ├───────────────────────────────────┤ │
│          │ │ ┌─ 控制 ────────────────────────┐ │ │
│          │ │ │ 1: 120℃/160℃   Tool1 Tool2.. │ │ │
│          │ │ │ 2: 120℃/160℃   放回打印头     │ │ │
│          │ │ │ 3: 120℃/160℃      [↑]        │ │ │
│          │ │ │ 4: 120℃/160℃   [←][XY][→]    │ │ │
│          │ │ │ Bed: 50℃/50℃      [↓]        │ │ │
│          │ │ │ Fan1 ██░░ 25%   挤出机 热床   │ │ │
│          │ │ │ Fan2 █░░░ 0%    10mm 1mm 0.1  │ │ │
│          │ │ └──────────────────────────────┘ │ │
└──────────┴───────────────────────────────────────┘
```

### Figma 色彩参考

| 用途 | 颜色值 |
|------|--------|
| Primary blue | `#0D64E6` |
| Dark surface (camera bg) | `#141414` |
| Light grey surface | `#F5F5FA` |
| Selected menu bg | `#0D64E6` |
| Unselected menu bg | `#F5F5F5` |
| Text primary | `#242424` |
| Text secondary | `#545759` |
| Progress bar fill | `#0D64E6` |
| Progress bar bg | `#D9D9D9` |
| Fan slider bg | `#F5F5FA` |

---

## Router 集成

```dart
// 通过 query parameter 传入设备 SN
GoRoute(
  path: '/device-control',
  name: 'deviceControl',
  builder: (context, state) {
    final sn = state.uri.queryParameters['sn'];
    return DeviceControlFullPage(initialSn: sn);
  },
),
```

---

## 组件对比：旧 vs 新

| 维度 | 旧实现 (2026-06-16) | 新实现 (2026-06-18) |
|------|---------------------|---------------------|
| 状态管理 | StatefulWidget + setState | Riverpod FamilyNotifier |
| 导航 | TabBar (控制/打印任务/耗材) | 左侧菜单 + 垂直滚动 |
| 数据源 | 硬编码 `_defaultDevices` | Global DeviceMetadataStore |
| 重绘控制 | 无 | select() + RepaintBoundary + throttle |
| 温度显示 | 简单 `27/0°C` | 蓝色编号标签 `120℃/160℃` |
| XYZ 控制 | 6 个独立方向按钮 | XY 十字圆盘 + 挤出机/热床按钮 |
| 风扇 | 文字 `100%` | 滑块 + 百分比刻度 |
| 打印进度 | 线性进度条 | 分段进度条 + 文件名 + 剩余时间 |
| 摄像头 | 静态播放按钮 | 摄像机/Video Tab + 耗材圆点 + UnLoad |
| 设备选择 | 顶部下拉框 | 左侧菜单列表 |

---

## 下一步

- [ ] 对接真实设备 MQTT 遥测（当前 Store 结构已就绪）
- [ ] 实现摄像头视频流
- [ ] XYZ 轴移动命令对接 `DeviceCommandService`
- [ ] 耗材数据从 DeviceMetadata 解析
- [ ] 固件更新页面
- [ ] 温度变化 < 0.5°C 跳过写入（Store 层节流增强）

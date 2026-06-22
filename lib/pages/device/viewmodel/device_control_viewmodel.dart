import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_zero_copy/features/device/application/providers/device_metadata_store_provider.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_metadata.dart';
import 'package:flutter_zero_copy/pages/device/state/device_control_page_state.dart';

/// Page-level ViewModel for DeviceControlFullPage.
///
/// **架构角色**: 全局 Store 和 UI 之间的中间层
///
/// - 从 [DeviceMetadataStore] 读取当前设备元数据，扁平化为 [DeviceControlPageState]
/// - 对高频 MQTT 遥测做节流（200ms），避免 UI 过度重绘
/// - 管理页面本地 UI 状态（工具选择、步进精度、摄像头 Tab 等）
/// - 暴露操作方法供 UI 调用
///
/// **Provider**: [deviceControlViewModelProvider] (FamilyNotifier, keyed by SN)
class DeviceControlViewModel
    extends FamilyNotifier<DeviceControlPageState, String> {
  Timer? _throttleTimer;
  DeviceMetadata? _pendingMeta;

  @override
  DeviceControlPageState build(String sn) {
    // ── 清理定时器 ──
    ref.onDispose(() => _throttleTimer?.cancel());

    // ── 监听全局 Store 变化 ──
    ref.listen(deviceMetadataStoreProvider, (prev, next) {
      final device = next[sn];
      if (device != null) {
        _onStoreChanged(device);
      }
    });

    // ── 初始状态 ──
    final store = ref.read(deviceMetadataStoreProvider.notifier);
    final device = store.getDevice(sn);
    return DeviceControlPageState.fromMetadata(device);
  }

  /// 全局 Store 变化回调（高频 → 节流）
  void _onStoreChanged(DeviceMetadata meta) {
    _pendingMeta = meta;
    _throttleTimer?.cancel();
    _throttleTimer = Timer(_throttleWindow, () {
      final meta = _pendingMeta;
      if (meta == null) return;
      final newState = state.mergeTelemetry(meta);
      if (newState != state) {
        state = newState;
      }
    });
  }

  /// 节流窗口：200ms
  ///
  /// 温度 MQTT 推送可达 10+ Hz，200ms 窗口将 UI 更新频率限制在 ≤ 5 Hz，
  /// 同时感知延迟在可接受范围内。
  static const _throttleWindow = Duration(milliseconds: 200);

  // ══════════════════════════════════════════════════════════════
  // UI 操作方法
  // ══════════════════════════════════════════════════════════════

  /// 选择工具头 (1-4)
  void selectTool(int tool) {
    state = state.copyWith(selectedTool: tool);
  }

  /// 选择移动步进精度
  void selectStep(String step) {
    state = state.copyWith(selectedStep: step);
  }

  /// 切换摄像头/视频 Tab
  void selectCameraTab(int index) {
    state = state.copyWith(cameraTabIndex: index);
  }

  /// 切换 LED 开关
  void toggleLed() {
    state = state.copyWith(isLedOn: !state.isLedOn);
  }

}

/// Provider for the DeviceControlPage ViewModel.
///
/// **用法**:
/// ```dart
/// final viewModel = ref.watch(deviceControlViewModelProvider(sn));
/// ```
final deviceControlViewModelProvider = NotifierProvider.family<
    DeviceControlViewModel, DeviceControlPageState, String>(
  DeviceControlViewModel.new,
);

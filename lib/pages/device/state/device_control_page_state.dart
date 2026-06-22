import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/features/device/domain/entities/device_metadata.dart';
import 'package:flutter_zero_copy/features/device/domain/interfaces/i_device_facade.dart';

/// Immutable page state for DeviceControlFullPage.
///
/// Flattened from [DeviceMetadata] with only the fields the UI needs.
/// Equality is value-based so the ViewModel can skip no-op updates.
@immutable
class DeviceControlPageState {
  // ── Device identity ──
  final String sn;
  final String displayName;

  // ── Connection ──
  final DeviceConnectionState connectionState;

  // ── Temperatures ──
  final double nozzleTemp1;
  final double nozzleTemp2;
  final double nozzleTemp3;
  final double nozzleTemp4;
  final double? nozzleTarget1;
  final double? nozzleTarget2;
  final double? nozzleTarget3;
  final double? nozzleTarget4;
  final double bedTemp;
  final double? bedTarget;
  final double chamberTemp;
  final double? chamberTarget;

  // ── Print task ──
  final int progress;
  final String? taskName;
  final int currentLayer;
  final int totalLayers;
  final int remainingMinutes;
  final String? printState;

  // ── Filament ──
  final double filamentUsed;

  // ── Fans (0-100) ──
  final int mainFanSpeed;
  final int auxFanSpeed;
  final int exhaustFanSpeed;

  // ── UI state (local, not from store) ──
  final int selectedTool;
  final String selectedStep; // '10mm' | '1mm' | '0.1mm'
  final int cameraTabIndex; // 0: 摄像机, 1: 视频
  final bool isLedOn;

  const DeviceControlPageState({
    required this.sn,
    this.displayName = '',
    this.connectionState = DeviceConnectionState.idle,
    this.nozzleTemp1 = 0,
    this.nozzleTemp2 = 0,
    this.nozzleTemp3 = 0,
    this.nozzleTemp4 = 0,
    this.nozzleTarget1,
    this.nozzleTarget2,
    this.nozzleTarget3,
    this.nozzleTarget4,
    this.bedTemp = 0,
    this.bedTarget,
    this.chamberTemp = 0,
    this.chamberTarget,
    this.progress = 0,
    this.taskName,
    this.currentLayer = 0,
    this.totalLayers = 0,
    this.remainingMinutes = 0,
    this.printState,
    this.filamentUsed = 0,
    this.mainFanSpeed = 0,
    this.auxFanSpeed = 0,
    this.exhaustFanSpeed = 0,
    this.selectedTool = 1,
    this.selectedStep = '1mm',
    this.cameraTabIndex = 0,
    this.isLedOn = false,
  });

  /// Create from global [DeviceMetadata], keeping existing UI state.
  factory DeviceControlPageState.fromMetadata(DeviceMetadata? meta) {
    if (meta == null) {
      return const DeviceControlPageState(sn: '');
    }
    return DeviceControlPageState(
      sn: meta.sn,
      displayName: meta.displayName,
      connectionState: meta.connectionState,
      nozzleTemp1: meta.nozzleTemp?.value ?? 0,
      // Multi-extruder temps would come from separate fields or array in future
      bedTemp: meta.bedTemp?.value ?? 0,
      chamberTemp: meta.chamberTemp?.value ?? 0,
      progress: meta.progress?.value ?? 0,
      printState: meta.printState?.value,
      filamentUsed: meta.filamentUsed ?? 0,
    );
  }

  /// Merge telemetry updates from [DeviceMetadata] into the state.
  ///
  /// Only fields that actually changed are updated (structural sharing via copyWith).
  /// UI state fields (selectedTool, selectedStep, etc.) are preserved.
  DeviceControlPageState mergeTelemetry(DeviceMetadata meta) {
    final newNozzleTemp = meta.nozzleTemp?.value ?? nozzleTemp1;
    final newBedTemp = meta.bedTemp?.value ?? bedTemp;
    final newChamberTemp = meta.chamberTemp?.value ?? chamberTemp;
    final newProgress = meta.progress?.value ?? progress;
    final newPrintState = meta.printState?.value ?? printState;
    final newFilamentUsed = meta.filamentUsed ?? filamentUsed;
    final newConnectionState = meta.connectionState;

    // Skip if nothing meaningful changed (avoid rebuilds)
    if (newNozzleTemp == nozzleTemp1 &&
        newBedTemp == bedTemp &&
        newChamberTemp == chamberTemp &&
        newProgress == progress &&
        newPrintState == printState &&
        newFilamentUsed == filamentUsed &&
        newConnectionState == connectionState) {
      return this;
    }

    return copyWith(
      nozzleTemp1: newNozzleTemp,
      bedTemp: newBedTemp,
      chamberTemp: newChamberTemp,
      progress: newProgress,
      printState: newPrintState,
      filamentUsed: newFilamentUsed,
      connectionState: newConnectionState,
    );
  }

  /// Whether the device is in a usable connected state.
  bool get isConnected =>
      connectionState == DeviceConnectionState.connected ||
      connectionState == DeviceConnectionState.degraded;

  DeviceControlPageState copyWith({
    String? sn,
    String? displayName,
    DeviceConnectionState? connectionState,
    double? nozzleTemp1,
    double? nozzleTemp2,
    double? nozzleTemp3,
    double? nozzleTemp4,
    double? nozzleTarget1,
    double? nozzleTarget2,
    double? nozzleTarget3,
    double? nozzleTarget4,
    double? bedTemp,
    double? bedTarget,
    double? chamberTemp,
    double? chamberTarget,
    int? progress,
    String? taskName,
    int? currentLayer,
    int? totalLayers,
    int? remainingMinutes,
    String? printState,
    double? filamentUsed,
    int? mainFanSpeed,
    int? auxFanSpeed,
    int? exhaustFanSpeed,
    int? selectedTool,
    String? selectedStep,
    int? cameraTabIndex,
    bool? isLedOn,
  }) {
    return DeviceControlPageState(
      sn: sn ?? this.sn,
      displayName: displayName ?? this.displayName,
      connectionState: connectionState ?? this.connectionState,
      nozzleTemp1: nozzleTemp1 ?? this.nozzleTemp1,
      nozzleTemp2: nozzleTemp2 ?? this.nozzleTemp2,
      nozzleTemp3: nozzleTemp3 ?? this.nozzleTemp3,
      nozzleTemp4: nozzleTemp4 ?? this.nozzleTemp4,
      nozzleTarget1: nozzleTarget1 ?? this.nozzleTarget1,
      nozzleTarget2: nozzleTarget2 ?? this.nozzleTarget2,
      nozzleTarget3: nozzleTarget3 ?? this.nozzleTarget3,
      nozzleTarget4: nozzleTarget4 ?? this.nozzleTarget4,
      bedTemp: bedTemp ?? this.bedTemp,
      bedTarget: bedTarget ?? this.bedTarget,
      chamberTemp: chamberTemp ?? this.chamberTemp,
      chamberTarget: chamberTarget ?? this.chamberTarget,
      progress: progress ?? this.progress,
      taskName: taskName ?? this.taskName,
      currentLayer: currentLayer ?? this.currentLayer,
      totalLayers: totalLayers ?? this.totalLayers,
      remainingMinutes: remainingMinutes ?? this.remainingMinutes,
      printState: printState ?? this.printState,
      filamentUsed: filamentUsed ?? this.filamentUsed,
      mainFanSpeed: mainFanSpeed ?? this.mainFanSpeed,
      auxFanSpeed: auxFanSpeed ?? this.auxFanSpeed,
      exhaustFanSpeed: exhaustFanSpeed ?? this.exhaustFanSpeed,
      selectedTool: selectedTool ?? this.selectedTool,
      selectedStep: selectedStep ?? this.selectedStep,
      cameraTabIndex: cameraTabIndex ?? this.cameraTabIndex,
      isLedOn: isLedOn ?? this.isLedOn,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceControlPageState &&
          runtimeType == other.runtimeType &&
          sn == other.sn &&
          displayName == other.displayName &&
          connectionState == other.connectionState &&
          nozzleTemp1 == other.nozzleTemp1 &&
          nozzleTemp2 == other.nozzleTemp2 &&
          nozzleTemp3 == other.nozzleTemp3 &&
          nozzleTemp4 == other.nozzleTemp4 &&
          nozzleTarget1 == other.nozzleTarget1 &&
          nozzleTarget2 == other.nozzleTarget2 &&
          nozzleTarget3 == other.nozzleTarget3 &&
          nozzleTarget4 == other.nozzleTarget4 &&
          bedTemp == other.bedTemp &&
          bedTarget == other.bedTarget &&
          chamberTemp == other.chamberTemp &&
          chamberTarget == other.chamberTarget &&
          progress == other.progress &&
          taskName == other.taskName &&
          currentLayer == other.currentLayer &&
          totalLayers == other.totalLayers &&
          remainingMinutes == other.remainingMinutes &&
          printState == other.printState &&
          filamentUsed == other.filamentUsed &&
          mainFanSpeed == other.mainFanSpeed &&
          auxFanSpeed == other.auxFanSpeed &&
          exhaustFanSpeed == other.exhaustFanSpeed &&
          selectedTool == other.selectedTool &&
          selectedStep == other.selectedStep &&
          cameraTabIndex == other.cameraTabIndex &&
          isLedOn == other.isLedOn;

  @override
  int get hashCode => Object.hashAll([
        sn,
        displayName,
        connectionState,
        nozzleTemp1,
        nozzleTemp2,
        nozzleTemp3,
        nozzleTemp4,
        bedTemp,
        chamberTemp,
        progress,
        taskName,
        currentLayer,
        totalLayers,
        remainingMinutes,
        printState,
        filamentUsed,
        mainFanSpeed,
        auxFanSpeed,
        exhaustFanSpeed,
        selectedTool,
        selectedStep,
        cameraTabIndex,
        isLedOn,
      ]);
}

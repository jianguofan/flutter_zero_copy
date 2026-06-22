import 'package:flutter/material.dart';
import 'widgets/device_top_bar.dart';
import 'widgets/device_sidebar.dart';
import 'widgets/camera/camera_panel.dart';
import 'widgets/control/control_panel.dart';
import 'widgets/print_task/print_task_panel.dart';
import 'widgets/filament/filament_panel.dart';

/// 设备控制页面 — Figma 首页-待机状态
///
/// 布局:
/// ┌──────────────────────────────────────────────────────┐
/// │ Top Bar (1440×72) — Snapmaker T1                     │
/// ├────────┬─────────────────────┬───────────────────────┤
/// │Sidebar │ Camera Panel        │ Control Panel         │
/// │262     │                     │                       │
/// │        ├─────────────────────┼───────────────────────┤
/// │        │ Print Task Panel    │ Filament Panel        │
/// └────────┴─────────────────────┴───────────────────────┘
class DeviceControlPage extends StatelessWidget {
  const DeviceControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEBEBEB),
      child: Column(
        children: [
          const DeviceTopBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DeviceSidebar(),
                const SizedBox(width: 20),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Expanded(
                          flex: 379,
                          child: Row(
                            children: const [
                              Expanded(child: DeviceCameraPanel()),
                              SizedBox(width: 20),
                              Expanded(child: DeviceControlPanel()),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          flex: 379,
                          child: Row(
                            children: const [
                              Expanded(child: DevicePrintTaskPanel()),
                              SizedBox(width: 20),
                              Expanded(child: DeviceFilamentPanel()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../shared/panel_shell.dart';
import '../shared/header_bar.dart';
import 'components/temps_column.dart';
import 'components/xyz_column.dart';

/// 设备控制面板 — 温度 + XYZ
class DeviceControlPanel extends StatelessWidget {
  const DeviceControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelShell(
      header: const HeaderBar(
        child: Text(
          '控制',
          style: TextStyle(fontSize: 14, color: Color(0xFF242424)),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TempsColumn(),
          Expanded(child: XyzColumn()),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../shared/panel_shell.dart';
import 'components/filament_header.dart';
import 'components/filament_color_slot.dart';
import 'components/info_row.dart';

/// 耗材面板
class DeviceFilamentPanel extends StatelessWidget {
  const DeviceFilamentPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelShell(
      header: const FilamentHeader(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            SizedBox(
              height: 140,
              child: Row(
                children: const [
                  FilamentColorSlot(
                      label: '1',
                      color: Color(0xFF427EFF),
                      selected: true),
                  SizedBox(width: 32),
                  FilamentColorSlot(
                      label: '2',
                      color: Color(0xFFFF6B35),
                      selected: false),
                  SizedBox(width: 32),
                  FilamentColorSlot(
                      label: '3',
                      color: Color(0xFFF5A623),
                      selected: false),
                  SizedBox(width: 32),
                  FilamentColorSlot(
                      label: '4',
                      color: Color(0xFF7B68EE),
                      selected: false),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const InfoRow(label: '耗材', value: 'Snapspeed PLA'),
            const SpacerGap(),
            const InfoRow(
                label: '颜色', value: '蓝色', dotColor: Color(0xFF427EFF)),
            const SpacerGap(),
            const InfoRow(label: '喷嘴温度', value: '220 °C'),
            const SpacerGap(),
            const InfoRow(label: '热床温度', value: '60 °C'),
            const SpacerGap(),
            const DividerLine(),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('SN码：   XXXXXXXXXX',
                  style:
                      TextStyle(fontSize: 12, color: Color(0xFF333333))),
            ),
          ],
        ),
      ),
    );
  }
}

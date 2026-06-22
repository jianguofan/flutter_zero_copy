import 'package:flutter/material.dart';
import '../shared/panel_shell.dart';
import 'components/camera_header.dart';
import 'components/play_overlay.dart';

/// 摄像机面板 — 待机状态
class DeviceCameraPanel extends StatelessWidget {
  const DeviceCameraPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelShell(
      header: const CameraHeader(),
      child: Container(
        color: const Color(0xFF151515),
        child: const Column(
          children: [
            Expanded(
              child: Center(child: PlayOverlay()),
            ),
            SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  '摄像机未打开',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

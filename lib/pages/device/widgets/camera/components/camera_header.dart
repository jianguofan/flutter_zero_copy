import 'package:flutter/material.dart';
import '../../shared/header_bar.dart';
import '../../shared/tab_label.dart';
import 'filament_status_indicator.dart';
import 'camera_menu_icon.dart';

/// 摄像机 Header: [摄像机 | Video ···· 耗材 ●●●● 菜单]
class CameraHeader extends StatelessWidget {
  const CameraHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return HeaderBar(
      child: Row(
        children: const [
          TabLabel('摄像机', active: true),
          SizedBox(width: 12),
          TabLabel('Video', active: false),
          Spacer(),
          FilamentStatusIndicator(),
          SizedBox(width: 12),
          CameraMenuIcon(),
        ],
      ),
    );
  }
}

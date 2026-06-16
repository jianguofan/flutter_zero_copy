import 'package:flutter/material.dart';

/// 摄像头视图组件
///
/// 显示设备摄像头画面或空状态
class DeviceCameraView extends StatelessWidget {
  final bool isDeviceConnected;
  final bool isCameraOn;

  const DeviceCameraView({
    super.key,
    this.isDeviceConnected = false,
    this.isCameraOn = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 播放按钮图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                size: 48,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),

            // 状态文字
            Text(
              isCameraOn ? '摄像头加载中...' : '摄像头未开启',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

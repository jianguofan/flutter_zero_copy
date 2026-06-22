import 'package:flutter/material.dart';

/// 摄像机 header 右侧菜单图标 — 灰色圆角方块 + 更多图标
class CameraMenuIcon extends StatelessWidget {
  const CameraMenuIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.more_horiz, size: 14, color: Color(0xFF242424)),
    );
  }
}

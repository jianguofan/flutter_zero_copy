import 'package:flutter/material.dart';

/// 播放按钮 — 半透明白色圆形 + 白色三角形
class PlayOverlay extends StatelessWidget {
  const PlayOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.10),
      ),
      child: const Icon(
        Icons.play_arrow,
        size: 50,
        color: Color(0xB3FFFFFF),
      ),
    );
  }
}

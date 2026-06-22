import 'package:flutter/material.dart';

/// 进度条 — 对应 Figma 中的进度指示器
class AppProgressBar extends StatelessWidget {
  final double progress; // 0.0 ~ 1.0
  final double height;
  final Color? color;

  const AppProgressBar({
    super.key,
    required this.progress,
    this.height = 8,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    return LayoutBuilder(builder: (context, constraints) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFD9D9D9),
          borderRadius: BorderRadius.circular(30),
        ),
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: effectiveColor,
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      );
    });
  }
}

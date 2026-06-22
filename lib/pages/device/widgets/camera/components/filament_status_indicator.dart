import 'package:flutter/material.dart';

/// 耗材状态指示器 — "耗材" 标签 + 4 个圆点
class FilamentStatusIndicator extends StatelessWidget {
  const FilamentStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '耗材',
          style: TextStyle(fontSize: 14, color: Color(0xFF242424)),
        ),
        const SizedBox(width: 8),
        _dot(true),
        const SizedBox(width: 4),
        _dot(true),
        const SizedBox(width: 4),
        _dot(true),
        const SizedBox(width: 4),
        _dot(false),
      ],
    );
  }

  Widget _dot(bool active) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF0D0D0D),
      ),
      alignment: Alignment.center,
      child: active
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }
}

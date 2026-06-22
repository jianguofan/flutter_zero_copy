import 'package:flutter/material.dart';

/// XY 方向控制盘 — 140x140 圆形 + 4 方向箭头
class XyPad extends StatelessWidget {
  const XyPad({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF5F6FA),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF5F6FA),
            ),
          ),
          const Text(
            'XY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF242424),
            ),
          ),
          const _PadArrow(angle: -0.5, alignment: Alignment(0, -1)),
          const _PadArrow(angle: 0.5, alignment: Alignment(0, 1)),
          const _PadArrow(angle: 0, alignment: Alignment(-1, 0)),
          const _PadArrow(angle: 1, alignment: Alignment(1, 0)),
        ],
      ),
    );
  }
}

class _PadArrow extends StatelessWidget {
  final double angle;
  final Alignment alignment;

  const _PadArrow({required this.angle, required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Transform.rotate(
          angle: angle * 3.14159,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF06141B),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.play_arrow, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

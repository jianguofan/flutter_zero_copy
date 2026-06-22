import 'package:flutter/material.dart';

/// 耗材色卡 — 64px 宽，含圆形颜色 + 编号标签
class FilamentColorSlot extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;

  const FilamentColorSlot({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD9D9D9)),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: selected
                        ? Border.all(
                            color: const Color(0xFF0C63E2), width: 2)
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 32,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF242424),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '耗材 $label',
            style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
  }
}

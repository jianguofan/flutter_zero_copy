import 'package:flutter/material.dart';

/// Chip 选择组 (Tool / Step)
class ChipGroup extends StatelessWidget {
  final List<String> items;
  final int selected;
  final bool showDot;

  const ChipGroup({
    super.key,
    required this.items,
    required this.selected,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () {}, // TODO: 绑定选择逻辑
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: active
                  ? BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    )
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    items[i],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF242424),
                    ),
                  ),
                  if (showDot) ...[
                    const SizedBox(width: 3),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0ED400),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

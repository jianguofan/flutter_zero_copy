import 'package:flutter/material.dart';

/// 信息行 — label + 可选色点 + value
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? dotColor;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 172,
          child: Text(
            label,
            style:
                const TextStyle(fontSize: 14, color: Color(0xFF242424)),
          ),
        ),
        if (dotColor != null) ...[
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          value,
          style:
              const TextStyle(fontSize: 12, color: Color(0xFF666666)),
        ),
      ],
    );
  }
}

/// 间距分隔
class SpacerGap extends StatelessWidget {
  const SpacerGap({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(height: 12);
}

/// 分割线
class DividerLine extends StatelessWidget {
  const DividerLine({super.key});
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: Color(0xFFE8E8E8));
}

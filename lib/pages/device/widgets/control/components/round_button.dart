import 'package:flutter/material.dart';

/// 圆形按钮 (挤出机 / 热床 / 回零)
class RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const RoundButton({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFF5F6FA),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2B2E32),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF06141B),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF242424),
          ),
        ),
      ],
    );
  }
}

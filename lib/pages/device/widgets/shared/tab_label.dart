import 'package:flutter/material.dart';

/// Tab 标签 (摄像机 / Video)
class TabLabel extends StatelessWidget {
  final String text;
  final bool active;

  const TabLabel(this.text, {super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: active ? const Color(0xFF0D64E6) : const Color(0xFF242424),
      ),
    );
  }
}

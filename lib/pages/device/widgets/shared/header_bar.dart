import 'package:flutter/material.dart';

/// 标题栏 — 所有模块 header 统一规范
///
/// Figma: 40px height, #F7F8F8 fill, bottom edge #E8E8E8
class HeaderBar extends StatelessWidget {
  final Widget child;

  const HeaderBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8F8),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8E8E8), width: 1),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

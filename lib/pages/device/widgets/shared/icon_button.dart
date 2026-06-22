import 'package:flutter/material.dart';

/// 小型图标按钮 — 用于 panel header 右侧
class IconBtn extends StatelessWidget {
  final IconData icon;

  const IconBtn(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {}, // TODO: 绑定业务逻辑
      icon: Icon(icon, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      color: const Color(0xFF8F8F8F),
    );
  }
}

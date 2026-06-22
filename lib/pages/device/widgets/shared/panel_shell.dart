import 'package:flutter/material.dart';

/// 白色圆角面板外壳 — 所有模块统一使用
///
/// Figma: Rectangle #FFFFFF + 1px border #D9D9D9 + 4px radius
class PanelShell extends StatelessWidget {
  final Widget header;
  final Widget child;

  const PanelShell({super.key, required this.header, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, Expanded(child: child)],
      ),
    );
  }
}

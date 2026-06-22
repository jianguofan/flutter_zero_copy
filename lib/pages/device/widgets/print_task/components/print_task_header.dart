import 'package:flutter/material.dart';
import '../../shared/header_bar.dart';
import '../../shared/icon_button.dart';

/// 打印任务 Header
class PrintTaskHeader extends StatelessWidget {
  const PrintTaskHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return HeaderBar(
      child: Row(
        children: [
          const Text(
            '打印任务',
            style: TextStyle(fontSize: 14, color: Color(0xFF242424)),
          ),
          const Spacer(),
          const IconBtn(Icons.help_outline),
          const SizedBox(width: 8),
          const IconBtn(Icons.more_horiz),
        ],
      ),
    );
  }
}

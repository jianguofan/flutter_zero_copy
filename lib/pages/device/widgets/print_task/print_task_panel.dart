import 'package:flutter/material.dart';
import '../shared/panel_shell.dart';
import 'components/print_task_header.dart';

/// 打印任务面板
class DevicePrintTaskPanel extends StatelessWidget {
  const DevicePrintTaskPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelShell(
      header: const PrintTaskHeader(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 3D 预览缩略图
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFCFCF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        size: 48, color: Color(0xFFC0C0C0)),
                  ),
                ),
                const SizedBox(width: 20),
                // 进度信息
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('34%',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0C63E2))),
                      SizedBox(height: 8),
                      Text('多色老虎.STL',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333))),
                      SizedBox(height: 4),
                      Text('0/2100',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF333333))),
                      SizedBox(height: 4),
                      Text('剩余时间：2h 34m',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF333333))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: SizedBox(
                height: 8,
                child: Row(children: [
                  Flexible(
                      flex: 34,
                      child:
                          Container(color: const Color(0xFF0C63E2))),
                  Flexible(
                      flex: 66,
                      child:
                          Container(color: const Color(0xFFD9D9D9))),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            // 暂停/停止按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFECECEC)),
                    child: const Icon(Icons.pause,
                        size: 14, color: Color(0xFF333333)),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFECECEC)),
                    child: Container(
                        width: 12,
                        height: 12,
                        color: const Color(0xFFF23535)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

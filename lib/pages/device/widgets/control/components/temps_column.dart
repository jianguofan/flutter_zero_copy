import 'package:flutter/material.dart';
import 'temp_item.dart';

/// 温度列 — 109px 左侧面板
class TempsColumn extends StatelessWidget {
  const TempsColumn({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 109,
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      color: const Color(0xFFF5F6FA),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TempItem(num: '1', temp: '120', target: '160'),
            SizedBox(height: 6),
            TempItem(num: '2', temp: '_', target: '_', active: false),
            SizedBox(height: 6),
            TempItem(num: '3', temp: '_', target: '_', active: false),
            SizedBox(height: 6),
            TempItem(num: '4', temp: '_', target: '_', active: false),
            SizedBox(height: 6),
            BedItem(),
            SizedBox(height: 10),
            LedItem(),
            SizedBox(height: 6),
            FanItem(),
          ],
        ),
      ),
    );
  }
}

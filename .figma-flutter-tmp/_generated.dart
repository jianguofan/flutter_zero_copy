// Figma → Flutter UI 骨架 · Group 427323468
// 样式：✅  令牌：✅  数据：⏳ 由开发者填入
import 'package:flutter/material.dart';


class Group427323468 extends StatelessWidget {
  const Group427323468({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
    children: [
Container(
        width: 535, height: 339,
        decoration: BoxDecoration(color: AppColors.textTertiary),
      ),
Container(
        child: Row(
          children: [
Container(
            child: Row(
              children: [
Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.sm)),
                padding: EdgeInsets.all(AppSpacing.xs),  // Figma: 0,6,0,6
                child: Row(
                  children: [
Text('异常',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                  ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
Text('LAVA-1',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              ],
            ),
          ),
          const SizedBox(width: 6),
Container(
            padding: EdgeInsets.all(AppSpacing.xs),  // Figma: 2,6,2,6
            child: Row(
              children: [
Text('工具头1在进行挤出流量校准',
                style: TextStyle(fontSize: 12, color: Color(0xFF7A7A7A)),
              ),
              ],
            ),
          ),
          ],
        ),
      ),
Column(
        children: [
SizedBox(width: 24, height: 24)  // icon placeholder,
SizedBox(width: 4, height: 16)  // icon placeholder,
SizedBox(width: 4, height: 16)  // icon placeholder,
        ],
      ),
Container(
        width: 535, height: 40,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
Container(
        child: Row(
          children: [
Container(
            child: Row(
              children: [
Text('打印任务',
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
              ],
            ),
          ),
          const SizedBox(width: 40),
Column(
            children: [
SizedBox(width: 20, height: 20)  // icon placeholder,
SizedBox(width: 14, height: 14)  // icon placeholder,
SizedBox(width: 2, height: 2)  // icon placeholder,
            ],
          ),
          const SizedBox(width: 40),
Column(
            children: [
SizedBox(width: 20, height: 20)  // icon placeholder,
Container(
                child: Row(
                  children: [
SizedBox(width: 15, height: 13)  // icon placeholder,
SizedBox(width: 9, height: 3)  // icon placeholder,
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 40),
Column(
            children: [
SizedBox(width: 20, height: 20)  // icon placeholder,
Container(
                child: Column(
                  children: [
Container(
                    child: Row(
                      children: [
SizedBox(width: 17, height: 13)  // icon placeholder,
SizedBox(width: 3, height: 3)  // icon placeholder,
                      ],
                    ),
                  ),
                  ],
                ),
              ),
            ],
          ),
          ],
        ),
      ),
Container(
        width: 140,
        child: Column(
          children: [
Container(width: 140, height: 140)  // Rectangle 34624772,
Container(width: 112, height: 112)  // image 65,
          ],
        ),
      ),
Text('34%',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Color(0xFF0C63E2)),
      ),
Container(
        width: 455, height: 8,
        decoration: BoxDecoration(color: AppColors.colorD9D, borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
Container(
        width: 115, height: 8,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
Column(
        children: [
SizedBox(width: 24, height: 24)  // icon placeholder,
SizedBox(width: 12, height: 12)  // icon placeholder,
        ],
      ),
Text('剩余时间：2h 34m',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
Text('多色老虎.STL',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      ),
Text('0/2100',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    ],
  );
  }
}
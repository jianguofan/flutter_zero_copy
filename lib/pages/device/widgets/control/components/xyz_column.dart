import 'package:flutter/material.dart';
import 'chip_group.dart';
import 'round_button.dart';
import 'xy_pad.dart';

/// XYZ 运动控制区
class XyzColumn extends StatelessWidget {
  const XyzColumn({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const ChipGroup(
                items: ['Tool1', 'Tool2', 'Tool3', 'Tool4'],
                selected: 0,
                showDot: true,
              ),
              const Spacer(),
              const ChipGroup(
                items: ['10mm', '1mm', '0.1mm'],
                selected: 1,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RoundButton(icon: Icons.print, label: '挤出机'),
              SizedBox(width: 12),
              XyPad(),
              SizedBox(width: 12),
              RoundButton(icon: Icons.waves, label: '热床'),
            ],
          ),
          const SizedBox(height: 8),
          const RoundButton(icon: Icons.replay, label: '回零'),
          const SizedBox(height: 12),
          SizedBox(
            width: 150,
            height: 32,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF5F6FA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: BorderSide.none,
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                '放回打印头',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF242424),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF5F6FA),
              border: Border.all(color: const Color(0xFFDDDDDD)),
            ),
            child: const Icon(Icons.home, size: 28, color: Color(0xFF333333)),
          ),
        ],
      ),
    );
  }
}

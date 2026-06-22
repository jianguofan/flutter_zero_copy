import 'package:flutter/material.dart';

/// 设备页顶栏 — 72px 深色条
class DeviceTopBar extends StatelessWidget {
  const DeviceTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Column(
        children: [
          Container(
            height: 36,
            color: const Color(0xFF242424),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text(
              'Snapmaker T1',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            height: 36,
            color: const Color(0xFF3B4547),
            padding: const EdgeInsets.symmetric(horizontal: 282),
            child: Row(
              children: List.generate(36, (i) {
                if (i % 6 == 0) {
                  return Container(
                    width: 12,
                    alignment: Alignment.center,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFFCCD0CF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }
                return const SizedBox(width: 4);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

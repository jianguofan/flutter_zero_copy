import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 设备页侧边栏 — 262px 白色
class DeviceSidebar extends StatelessWidget {
  const DeviceSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 262,
      child: Container(
        color: Colors.white,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 28),
            _SidebarTile(
              iconAsset: 'assets/icons/icon_device_control.svg',
              label: '设备控制',
              selected: true,
            ),
            SizedBox(height: 10),
            _SidebarTile(
              iconAsset: 'assets/icons/icon_firmware_update.svg',
              label: '固件更新',
              selected: false,
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final String iconAsset;
  final String label;
  final bool selected;

  const _SidebarTile({
    required this.iconAsset,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        selected ? const Color(0xFF0C63E2) : const Color(0xFFF4F4F4);
    final fg = selected ? Colors.white : const Color(0xFF545659);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 39),
      color: bg,
      child: Row(
        children: [
          SvgPicture.asset(
            iconAsset,
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

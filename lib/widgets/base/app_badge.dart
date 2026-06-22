import 'package:flutter/material.dart';

/// 状态标签 — 对应 Figma 中的状态标记
enum AppBadgeVariant { error, warning, success, info }
enum AppBadgeSize { small, medium }

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final AppBadgeSize size;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.info,
    this.size = AppBadgeSize.small,
  });

  Color get _bgColor => switch (variant) {
    AppBadgeVariant.error => const Color(0xFFF40004),
    AppBadgeVariant.warning => const Color(0xFFFF9900),
    AppBadgeVariant.success => const Color(0xFF00D4AA),
    AppBadgeVariant.info => const Color(0xFF0C63E2),
  };

  Color get _textColor => switch (variant) {
    AppBadgeVariant.warning => const Color(0xFF333333),
    _ => Colors.white,
  };

  double get _fontSize => size == AppBadgeSize.small ? 12 : 14;
  EdgeInsets get _padding => size == AppBadgeSize.small
      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
      : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _textColor,
          fontSize: _fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

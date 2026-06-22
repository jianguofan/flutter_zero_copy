import 'package:flutter/material.dart';

/// 通用按钮 — 对应 Figma Button 系列组件
///
/// 4 种变体映射到 Material Design:
///   primary → ElevatedButton
///   secondary → FilledButton
///   outline → OutlinedButton
///   ghost → TextButton
enum AppButtonVariant { primary, secondary, outline, ghost }
enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool disabled;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.disabled = false,
    this.icon,
  });

  EdgeInsets get _padding => switch (size) {
    AppButtonSize.small => const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    AppButtonSize.medium => const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    AppButtonSize.large => const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  };

  double get _fontSize => switch (size) {
    AppButtonSize.small => 12,
    AppButtonSize.medium => 14,
    AppButtonSize.large => 16,
  };

  @override
  Widget build(BuildContext context) {
    final child = icon != null
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            icon!,
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: _fontSize)),
          ])
        : Text(label, style: TextStyle(fontSize: _fontSize));

    final style = switch (variant) {
      AppButtonVariant.primary => ElevatedButton.styleFrom(padding: _padding),
      AppButtonVariant.secondary => FilledButton.styleFrom(padding: _padding),
      AppButtonVariant.outline => OutlinedButton.styleFrom(padding: _padding),
      AppButtonVariant.ghost => TextButton.styleFrom(padding: _padding),
    };

    return switch (variant) {
      AppButtonVariant.primary   => ElevatedButton(onPressed: disabled ? null : onTap, style: style, child: child),
      AppButtonVariant.secondary => FilledButton(onPressed: disabled ? null : onTap, style: style, child: child),
      AppButtonVariant.outline   => OutlinedButton(onPressed: disabled ? null : onTap, style: style, child: child),
      AppButtonVariant.ghost     => TextButton(onPressed: disabled ? null : onTap, style: style, child: child),
    };
  }
}

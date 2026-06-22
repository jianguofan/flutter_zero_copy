/// Component Library Demo Page
///
/// 展示所有通用组件的变体和用法，方便设计/开发对齐。
/// 路由: /component-demo

import 'package:flutter/material.dart';
import 'package:flutter_zero_copy/widgets/base/app_button.dart';
import 'package:flutter_zero_copy/widgets/base/app_badge.dart';
import 'package:flutter_zero_copy/widgets/base/app_progress_bar.dart';

class ComponentDemoPage extends StatelessWidget {
  const ComponentDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('组件库 Demo'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          _Section(title: 'AppButton — 通用按钮'),
          SizedBox(height: 12),
          _ButtonDemos(),
          SizedBox(height: 32),
          _Section(title: 'AppBadge — 状态标签'),
          SizedBox(height: 12),
          _BadgeDemos(),
          SizedBox(height: 32),
          _Section(title: 'AppProgressBar — 进度条'),
          SizedBox(height: 12),
          _ProgressDemos(),
          SizedBox(height: 32),
          _Section(title: '组合示例'),
          SizedBox(height: 12),
          _CombinedDemos(),
        ],
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700));
  }
}

// ── Button Demos ───────────────────────────────────────────

class _ButtonDemos extends StatelessWidget {
  const _ButtonDemos();

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: '4 变体 × 3 尺寸',
      child: Wrap(spacing: 12, runSpacing: 12, children: [
        for (final variant in AppButtonVariant.values)
          for (final size in AppButtonSize.values)
            AppButton(
              label: '${variant.name} ${size.name}',
              variant: variant,
              size: size,
              onTap: () {},
            ),
      ]),
    );
  }
}

// ── Badge Demos ────────────────────────────────────────────

class _BadgeDemos extends StatelessWidget {
  const _BadgeDemos();

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: '4 种状态',
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final variant in AppBadgeVariant.values)
          AppBadge(label: variant.name, variant: variant),
      ]),
    );
  }
}

// ── Progress Demos ─────────────────────────────────────────

class _ProgressDemos extends StatelessWidget {
  const _ProgressDemos();

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: '不同进度值',
      child: Column(children: [
        for (final p in [0.0, 0.25, 0.50, 0.75, 1.0]) ...[
          Row(children: [
            SizedBox(width: 60, child: Text('${(p * 100).toInt()}%', style: const TextStyle(fontSize: 13))),
            const SizedBox(width: 12),
            Expanded(child: AppProgressBar(progress: p)),
          ]),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }
}

// ── Combined Demos ─────────────────────────────────────────

class _CombinedDemos extends StatelessWidget {
  const _CombinedDemos();

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: '打印任务面板预览 (MCP 生成的效果)',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Status bar
          Row(children: [
            const Text('LAVA-1', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF242424))),
            const SizedBox(width: 8),
            const AppBadge(label: '异常', variant: AppBadgeVariant.error),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFFF9900), borderRadius: BorderRadius.circular(2)),
              child: const Text('工具头1在进行挤出流量校准', style: TextStyle(fontSize: 12, color: Color(0xFF7A7A7A))),
            ),
          ]),
          const SizedBox(height: 16),

          // Progress
          const Text('34%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF0C63E2))),
          const SizedBox(height: 4),
          const AppProgressBar(progress: 0.34, color: Color(0xFF0C63E2)),
          const SizedBox(height: 12),

          // Meta info
          const Text('剩余时间：2h 34m', style: TextStyle(fontSize: 13, color: Color(0xFF333333))),
          const SizedBox(height: 4),
          const Text('多色老虎.STL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333333))),
          const SizedBox(height: 2),
          const Text('0/2100', style: TextStyle(fontSize: 13, color: Color(0xFF333333))),
          const SizedBox(height: 16),

          // Action buttons
          Row(children: [
            AppButton(label: '暂停', variant: AppButtonVariant.outline, size: AppButtonSize.small, onTap: () {}),
            const SizedBox(width: 8),
            AppButton(label: '取消', variant: AppButtonVariant.ghost, size: AppButtonSize.small, onTap: () {}),
          ]),
        ]),
      ),
    );
  }
}

// ── Demo Card Wrapper ──────────────────────────────────────

class _DemoCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _DemoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

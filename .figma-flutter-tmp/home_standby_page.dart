// 首页-待机状态 — 从 Figma 文件 pasjCGfYDtus7cE6sqO8MO / Frame 10977:31300 生成
// 生成日期: 2026-06-22  |  样式: ✅  令牌: ✅  数据: 假数据可跑
//
// 布局结构:
// ┌──────────────────────────────────────────────────────┐
// │ Top Bar (1440×72) — #242424 + #3B4547               │
// ├────────┬─────────────────────┬───────────────────────┤
// │Sidebar │ Camera Panel        │ Control Panel         │
// │262     │ 535×379             │ 535×379               │
// │        ├─────────────────────┼───────────────────────┤
// │        │ Print Task Panel    │ Filament Panel        │
// │        │ 535×379             │ 535×379               │
// └────────┴─────────────────────┴───────────────────────┘
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════
// 主页面
// ══════════════════════════════════════════════

class HomeStandbyPage extends StatelessWidget {
  const HomeStandbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEBEBEB),
      child: Column(
        children: [
          const _TopBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Sidebar(),
                const SizedBox(width: 20),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // ── 顶行: Camera + Control ──
                        Expanded(
                          flex: 379,
                          child: Row(
                            children: const [
                              Expanded(child: _CameraPanel()),
                              SizedBox(width: 20),
                              Expanded(child: _ControlPanel()),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // ── 底行: Print Task + Filament ──
                        Expanded(
                          flex: 379,
                          child: Row(
                            children: const [
                              Expanded(child: _PrintTaskPanel()),
                              SizedBox(width: 20),
                              Expanded(child: _FilamentPanel()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
// TOP BAR
// ══════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Column(
        children: [
          // 上半: 深色条 #242424
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
          // 下半: 次深色条 #3B4547
          Container(
            height: 36,
            color: const Color(0xFF3B4547),
            padding: const EdgeInsets.symmetric(horizontal: 282), // 对齐内容区
            child: Row(
              children: List.generate(36, (i) {
                // 装饰性网格点
                if (i % 6 == 0)
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
                return const SizedBox(width: 4);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
// SIDEBAR
// ══════════════════════════════════════════════

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 262,
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 28),
            // 设备控制 — 激活状态
            const _SidebarTile(
              icon: Icons.settings_remote,
              label: '设备控制',
              selected: true,
            ),
            const SizedBox(height: 10),
            // 固件更新 — 未激活
            const _SidebarTile(
              icon: Icons.system_update,
              label: '固件更新',
              selected: false,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF0C63E2) : const Color(0xFFF4F4F4);
    final fg = selected ? Colors.white : const Color(0xFF545659);
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.symmetric(horizontal: 39),
      color: bg,
      child: Row(
        children: [
          Icon(icon, size: 20, color: fg),
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

// ══════════════════════════════════════════════
// CAMERA PANEL
// ══════════════════════════════════════════════

class _CameraPanel extends StatelessWidget {
  const _CameraPanel();

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      header: const _CameraHeader(),
      child: Container(
        color: const Color(0xFF151515),
        child: Column(
          children: [
            // 画面区域 — 播放按钮居中
            const Expanded(
              child: Center(
                child: _PlayOverlay(),
              ),
            ),
            // 底部提示文字 (Figma: 摄像机未打开)
            Container(
              height: 40,
              alignment: Alignment.center,
              child: const Text(
                '摄像机未打开',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayOverlay extends StatelessWidget {
  const _PlayOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.10),
      ),
      child: const Icon(
        Icons.play_arrow,
        size: 50,
        color: Color(0xB3FFFFFF), // 70% 白色
      ),
    );
  }
}

class _CameraHeader extends StatelessWidget {
  const _CameraHeader();

  @override
  Widget build(BuildContext context) {
    return const _HeaderBar(
      child: Row(
        children: [
          _TabLabel('摄像机', active: true),
          SizedBox(width: 12),
          _TabLabel('Video', active: false),
          Spacer(),
          _FilamentStatus(),
          SizedBox(width: 12),
          _CameraMenuIcon(),
        ],
      ),
    );
  }
}

/// 耗材状态指示器 — 4 个圆点
class _FilamentStatus extends StatelessWidget {
  const _FilamentStatus();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '耗材',
          style: TextStyle(fontSize: 14, color: Color(0xFF242424)),
        ),
        const SizedBox(width: 8),
        _filamentDot(true),
        const SizedBox(width: 4),
        _filamentDot(true),
        const SizedBox(width: 4),
        _filamentDot(true),
        const SizedBox(width: 4),
        _filamentDot(false),
      ],
    );
  }

  Widget _filamentDot(bool active) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF0D0D0D),
      ),
      alignment: Alignment.center,
      child: active
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }
}

class _CameraMenuIcon extends StatelessWidget {
  const _CameraMenuIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.more_horiz, size: 14, color: Color(0xFF242424)),
    );
  }
}

// ══════════════════════════════════════════════
// CONTROL PANEL
// ══════════════════════════════════════════════

class _ControlPanel extends StatelessWidget {
  const _ControlPanel();

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      header: const _HeaderBar(
        child: Text(
          '控制',
          style: TextStyle(fontSize: 14, color: Color(0xFF242424)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          // 左侧温度面板
          _TempsColumn(),
          // 右侧 XYZ 控制区
          Expanded(child: _XYZColumn()),
        ],
      ),
    );
  }
}

// ── 温度列 ──

class _TempsColumn extends StatelessWidget {
  const _TempsColumn();

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
            _TempItem(num: '1', temp: '120', target: '160'),
            SizedBox(height: 6),
            _TempItem(num: '2', temp: '_', target: '_', active: false),
            SizedBox(height: 6),
            _TempItem(num: '3', temp: '_', target: '_', active: false),
            SizedBox(height: 6),
            _TempItem(num: '4', temp: '_', target: '_', active: false),
            SizedBox(height: 6),
            _BedItem(),
            SizedBox(height: 10),
            _LedItem(),
            SizedBox(height: 6),
            _FanItem(),
          ],
        ),
      ),
    );
  }
}

class _TempItem extends StatelessWidget {
  final String num;
  final String temp;
  final String target;
  final bool active;

  const _TempItem({
    required this.num,
    required this.temp,
    required this.target,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = active ? const Color(0xFF242424) : const Color(0xFF999999);
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF1B50FF),
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.center,
          child: Text(
            num,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$temp /$target℃',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _BedItem extends StatelessWidget {
  const _BedItem();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Color(0xFF1B50FF),
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.waves, size: 10, color: Colors.white),
        ),
        const SizedBox(width: 6),
        const Text(
          '_ /_℃',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF999999),
          ),
        ),
      ],
    );
  }
}

class _LedItem extends StatelessWidget {
  const _LedItem();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Color(0xFF1B50FF),
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.lightbulb_outline, size: 10, color: Colors.white),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.circle, size: 8, color: Color(0xFF0ED400)),
        const SizedBox(width: 4),
        const Text(
          'LED',
          style: TextStyle(fontSize: 10, color: Color(0xFF242424)),
        ),
      ],
    );
  }
}

class _FanItem extends StatelessWidget {
  const _FanItem();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Color(0xFF1B50FF),
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.air, size: 10, color: Colors.white),
        ),
        const SizedBox(width: 6),
        const Text(
          '100%',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF242424),
          ),
        ),
      ],
    );
  }
}

// ── XYZ 控制区 ──

class _XYZColumn extends StatelessWidget {
  const _XYZColumn();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Tool 选择器 + Step 选择器
          Row(
            children: [
              _ChipGroup(
                items: const ['Tool1', 'Tool2', 'Tool3', 'Tool4'],
                selected: 0,
                showDot: true,
              ),
              const Spacer(),
              _ChipGroup(
                items: const ['10mm', '1mm', '0.1mm'],
                selected: 1,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 挤出机 | XY D-pad | 热床
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundBtn(icon: Icons.print, label: '挤出机'),
              SizedBox(width: 12),
              _XYPad(),
              SizedBox(width: 12),
              _RoundBtn(icon: Icons.waves, label: '热床'),
            ],
          ),
          const SizedBox(height: 8),
          // 回零按钮
          const _RoundBtn(icon: Icons.replay, label: '回零'),
          const SizedBox(height: 12),
          // 放回打印头
          SizedBox(
            width: 150,
            height: 32,
            child: OutlinedButton(
              onPressed: () {}, // TODO: 绑定业务逻辑
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
          // Home 按钮
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

class _XYPad extends StatelessWidget {
  const _XYPad();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF5F6FA),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF5F6FA),
            ),
          ),
          const Text(
            'XY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF242424),
            ),
          ),
          // 四个方向箭头
          const _PadArrow(angle: -0.5, alignment: Alignment(0, -1)), // 上
          const _PadArrow(angle: 0.5, alignment: Alignment(0, 1)), // 下
          const _PadArrow(angle: 0, alignment: Alignment(-1, 0)), // 左
          const _PadArrow(angle: 1, alignment: Alignment(1, 0)), // 右
        ],
      ),
    );
  }
}

class _PadArrow extends StatelessWidget {
  final double angle;
  final Alignment alignment;

  const _PadArrow({required this.angle, required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Transform.rotate(
          angle: angle * 3.14159,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF06141B),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.play_arrow, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RoundBtn({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFF5F6FA),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2B2E32),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF06141B),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF242424),
          ),
        ),
      ],
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final List<String> items;
  final int selected;
  final bool showDot;

  const _ChipGroup({
    required this.items,
    required this.selected,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () {}, // TODO: 绑定选择逻辑
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: active
                  ? BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    )
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    items[i],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF242424),
                    ),
                  ),
                  if (showDot) ...[
                    const SizedBox(width: 3),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0ED400),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// PRINT TASK PANEL
// ══════════════════════════════════════════════

class _PrintTaskPanel extends StatelessWidget {
  const _PrintTaskPanel();

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      header: const _PrintTaskHeader(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3D 预览 + 进度信息
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
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Color(0xFFC0C0C0),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // 进度信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      // Figma "N/A" placeholder → mock 为 34%
                      Text(
                        '34%',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0C63E2),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '多色老虎.STL',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '0/2100',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF333333),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '剩余时间：2h 34m',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 进度条 — Figma: 455×8, #D9D9D9 底 + #0C63E2 填充
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Flexible(
                      flex: 34,
                      child: Container(color: const Color(0xFF0C63E2)),
                    ),
                    Flexible(
                      flex: 66,
                      child: Container(color: const Color(0xFFD9D9D9)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 暂停/停止按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 暂停按钮
                GestureDetector(
                  onTap: () {}, // TODO: 绑定暂停逻辑
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFECECEC),
                    ),
                    child: const Icon(
                      Icons.pause,
                      size: 14,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 停止按钮
                GestureDetector(
                  onTap: () {}, // TODO: 绑定停止逻辑
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFECECEC),
                    ),
                    child: Container(
                      width: 12,
                      height: 12,
                      color: const Color(0xFFF23535),
                    ),
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

class _PrintTaskHeader extends StatelessWidget {
  const _PrintTaskHeader();

  @override
  Widget build(BuildContext context) {
    return _HeaderBar(
      child: Row(
        children: [
          const Text(
            '打印任务',
            style: TextStyle(fontSize: 14, color: Color(0xFF242424)),
          ),
          const Spacer(),
          _iconBtn(Icons.help_outline),
          const SizedBox(width: 8),
          _iconBtn(Icons.more_horiz),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
// FILAMENT PANEL
// ══════════════════════════════════════════════

class _FilamentPanel extends StatelessWidget {
  const _FilamentPanel();

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      header: const _FilamentHeader(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            // 4 个耗材色卡
            SizedBox(
              height: 140,
              child: Row(
                children: const [
                  _FilamentColorSlot(
                    label: '1',
                    color: Color(0xFF427EFF),
                    selected: true,
                  ),
                  SizedBox(width: 32),
                  _FilamentColorSlot(
                    label: '2',
                    color: Color(0xFFFF6B35),
                    selected: false,
                  ),
                  SizedBox(width: 32),
                  _FilamentColorSlot(
                    label: '3',
                    color: Color(0xFFF5A623),
                    selected: false,
                  ),
                  SizedBox(width: 32),
                  _FilamentColorSlot(
                    label: '4',
                    color: Color(0xFF7B68EE),
                    selected: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 耗材详细信息
            const _InfoRow(label: '耗材', value: 'Snapspeed PLA'),
            const _Sep(),
            const _InfoRow(label: '颜色', value: '蓝色', dotColor: Color(0xFF427EFF)),
            const _Sep(),
            const _InfoRow(label: '喷嘴温度', value: '220 °C'),
            const _Sep(),
            const _InfoRow(label: '热床温度', value: '60 °C'),
            const _Sep(),
            const _DividerLine(),
            const SizedBox(height: 12),
            // SN 码
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SN码：   XXXXXXXXXX',
                style: TextStyle(fontSize: 12, color: Color(0xFF333333)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilamentHeader extends StatelessWidget {
  const _FilamentHeader();

  @override
  Widget build(BuildContext context) {
    return _HeaderBar(
      child: Row(
        children: const [
          Text(
            '耗材',
            style: TextStyle(fontSize: 14, color: Color(0xFF242424)),
          ),
          Spacer(),
          Icon(Icons.info_outline, size: 18, color: Color(0xFF8F8F8F)),
        ],
      ),
    );
  }
}

class _FilamentColorSlot extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;

  const _FilamentColorSlot({
    required this.label,
    required this.color,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 色卡主体 — Figma: 64×100 white rounded rect + color circle
          Container(
            width: 64,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD9D9D9)),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: selected
                        ? Border.all(color: const Color(0xFF0C63E2), width: 2)
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 32,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF242424),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 标签
          Text(
            '耗材 $label',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? dotColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 172,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF242424)),
          ),
        ),
        if (dotColor != null) ...[
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          value,
          style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
        ),
      ],
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 12);
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: Color(0xFFE8E8E8));
}

// ══════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════

/// 白色圆角面板外壳 — 所有模块统一使用
///
/// Figma: Rectangle #FFFFFF + 1px border #D9D9D9 + 4px radius
class _PanelShell extends StatelessWidget {
  final Widget header;
  final Widget child;

  const _PanelShell({required this.header, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, Expanded(child: child)],
      ),
    );
  }
}

/// 标题栏 — 所有模块 header 统一规范
///
/// Figma: 40px height, #F7F8F8 fill, bottom edge #E8E8E8
class _HeaderBar extends StatelessWidget {
  final Widget child;

  const _HeaderBar({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8F8),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8E8E8), width: 1),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

/// Tab 标签 (摄像机 / Video)
class _TabLabel extends StatelessWidget {
  final String text;
  final bool active;

  const _TabLabel(this.text, {required this.active});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: active ? const Color(0xFF0D64E6) : const Color(0xFF242424),
      ),
    );
  }
}

/// 小型图标按钮
Widget _iconBtn(IconData icon) {
  return IconButton(
    onPressed: () {}, // TODO: 绑定业务逻辑
    icon: Icon(icon, size: 18),
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(),
    color: const Color(0xFF8F8F8F),
  );
}

// 设计令牌 — 从 Figma 文件 pasjCGfYDtus7cE6sqO8MO / 首页-待机状态 提取
// Figma Frame: 10977:31300   |   生成日期: 2026-06-22
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════
// 颜色令牌
// ══════════════════════════════════════════════

class AppColors {
  AppColors._();

  /// 页面背景 — 使用 1 次
  static const background = Color(0xFFEBEBEB);

  /// 面板/侧边栏背景 — 使用 58 次
  static const surface = Color(0xFFFFFFFF);

  /// 深色顶栏主色 — 使用 41 次
  static const topBarPrimary = Color(0xFF242424);

  /// 深色顶栏次色 — 使用 1 次
  static const topBarSecondary = Color(0xFF3B4547);

  /// Header 背景 — 使用 4 次
  static const headerBg = Color(0xFFF7F8F8);

  /// Header 底边 — 使用 2 次
  static const headerBorder = Color(0xFFE8E8E8);

  /// 面板边框 — 使用 19 次
  static const borderDefault = Color(0xFFD9D9D9);

  /// 主文字 — 使用频繁
  static const textPrimary = Color(0xFF242424);

  /// 次文字 — 使用 1 次
  static const textSecondary = Color(0xFF545659);

  /// 占位文字 — 使用 4 次
  static const textPlaceholder = Color(0xFFD9D9D9);

  /// 强调色 / 侧边栏激活 — 使用 4 次
  static const accent = Color(0xFF0C63E2);

  /// 侧边栏未激活背景
  static const sidebarInactiveBg = Color(0xFFF4F4F4);

  /// 控制区背景
  static const controlBg = Color(0xFFF5F6FA);

  /// 温度编号 badge
  static const tempBadge = Color(0xFF1B50FF);

  /// 摄像头暗背景
  static const cameraBg = Color(0xFF151515);

  /// 深色按钮背景
  static const buttonDark = Color(0xFF06141B);

  /// 圆形按钮外壳
  static const buttonOuter = Color(0xFF2B2E32);

  /// 进度条轨道
  static const progressTrack = Color(0xFFD9D9D9);

  /// 成功/在线绿
  static const activeGreen = Color(0xFF0ED400);

  /// 暂停按钮底色
  static const pauseBg = Color(0xFFECECEC);

  /// 停止按钮红
  static const stopRed = Color(0xFFF23535);

  /// 3D 预览背景
  static const previewBg = Color(0xFFFFCFCF);
}

// ══════════════════════════════════════════════
// 间距令牌
// ══════════════════════════════════════════════

class AppSpacing {
  AppSpacing._();

  /// 紧凑间距 — 4px
  static const double xs = 4.0;

  /// 默认组件间距 — 6px（主布局 gap）
  static const double sm = 6.0;

  /// 区块内间距 — 8px
  static const double md = 8.0;

  /// 区块间距 — 12px
  static const double lg = 12.0;
}

// ══════════════════════════════════════════════
// 圆角令牌
// ══════════════════════════════════════════════

class AppRadius {
  AppRadius._();

  /// 小圆角 — 按钮/输入框 — 4px
  static const double sm = 4.0;

  /// 中圆角 — 卡片/面板 — 6px
  static const double md = 6.0;

  /// 大圆角 — 进度条 — 30px（全圆角）
  static const double lg = 30.0;
}

// ══════════════════════════════════════════════
// 排版令牌
// ══════════════════════════════════════════════

class AppTypography {
  AppTypography._();

  /// 页面标题 — 16px / 600
  static const headlineLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );

  /// 侧边栏 / Panel 标题 — 14px / 500
  static const titleMedium = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w500,
    height: 1.14,
  );

  /// 正文 / Tab 标签 — 14px / 400
  static const bodyLarge = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    height: 1.29,
  );

  /// 次要信息 — 12px / 400
  static const bodyMedium = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    height: 1.33,
  );

  /// 控制区标签 — 10px / 500
  static const labelMedium = TextStyle(
    fontSize: 10.0,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// 进度百分比 — 28px / 600
  static const displayMedium = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w600,
    height: 1.14,
  );
}

import 'package:flutter/material.dart';

class DesignTokens {
  // ===== 强调色（#F59E0B — 暖橙，按钮、进度、选中态、链接）=====
  static const Color primary = Color(0xFFF59E0B);

  // ===== 辅助语义色 =====
  static const Color error = Color(0xFFD1453B); // warmer red
  static const Color success = Color(0xFF3B8B5E); // muted green
  static const Color warning = Color(0xFFF57C00);

  // ===== 温暖强调色（#D4A373 — 用于辅助装饰、品牌细节）=====
  static const Color warmAccent = Color(0xFFD4A373);
  static const Color warmAccentLight = Color(0xFFFEF3E2);
  // ===== 暖色装饰阴影（卡片、弹出菜单）=====
  static final BoxShadow cardShadow = BoxShadow(
    color: warmAccent.withValues(alpha: 0.08),
    blurRadius: 8,
    offset: const Offset(0, 2),
  );

  // ===== 暖色分割线（替代中性灰）=====
  static const Color dividerSubtle = Color(0x1FD4A373); // #D4A373 @ 12%

  // ===== 兼容旧引用（映射到新色值）=====
  static const Color primaryContainer = Color(0xFFFEF0D6); // warmer amber tint
  static const Color secondary = Color(0xFFD4A373);
  static const Color tertiary = Color(0xFF8D6E63);

  // ===== 间距系统 =====
  static double spacing(Spacing size) => switch (size) {
    Spacing.xs => 4.0,
    Spacing.sm => 8.0,
    Spacing.md => 16.0,
    Spacing.lg => 24.0,
    Spacing.xl => 32.0,
    Spacing.xxl => 48.0,
  };

  // ===== 圆角系统 =====
  static double radius(RadiusSize size) => switch (size) {
    RadiusSize.sm => 6.0,
    RadiusSize.md => 8.0,
    RadiusSize.lg => 12.0,
    RadiusSize.xl => 16.0,
  };
}

enum Spacing { xs, sm, md, lg, xl, xxl }

enum RadiusSize { sm, md, lg, xl }

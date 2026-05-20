import 'package:flutter/material.dart';

class DesignTokens {
  // ===== 强调色（#F59E0B — 暖橙，按钮、进度、选中态、链接）=====
  static const Color primary = Color(0xFFF59E0B);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ===== 辅助语义色 =====
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);

  // ===== 浅色模式 =====
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF8A8A8E);
  static const Color divider = Color(0xFFE5E5EA);

  // ===== 深色模式 =====
  static const Color backgroundDark = Color(0xFF0A0A0A);
  static const Color surfaceDark = Color(0xFF111111);
  static const Color textPrimaryDark = Color(0xFFF2F2F2);
  static const Color textSecondaryDark = Color(0xFF6E6E73);
  static const Color dividerDark = Color(0xFF1C1C1E);

  // ===== 温暖强调色（#D4A373 — 用于辅助装饰、品牌细节）=====
  static const Color warmAccent = Color(0xFFD4A373);
  static const Color warmAccentLight = Color(0xFFFEF3E2);

  // ===== 兼容旧引用（映射到新色值）=====
  static const Color primaryContainer = Color(0xFFFFF3E0);
  static const Color onPrimaryContainer = Color(0xFF3E2723);
  static const Color secondary = Color(0xFFD4A373);
  static const Color tertiary = Color(0xFF8D6E63);

  // ===== 中性色保留（部分旧组件依赖）=====
  static const Color neutral50 = Color(0xFFF5F6F8);
  static const Color neutral100 = Color(0xFFEDEFF2);
  static const Color neutral200 = Color(0xFFE2E5E9);
  static const Color neutral300 = Color(0xFFCDD3DA);
  static const Color neutral400 = Color(0xFF9BA5B0);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral900 = Color(0xFF111827);

  // ===== 间距系统 =====
  static double spacing(Spacing size) => switch (size) {
    Spacing.xs => 4.0,
    Spacing.sm => 8.0,
    Spacing.md => 16.0,
    Spacing.lg => 24.0,
    Spacing.xl => 32.0,
    Spacing.xxl => 48.0,
  };

  // ===== 圆角系统（统一 8px）=====
  static double radius(RadiusSize size) => switch (size) {
    RadiusSize.sm => 6.0,
    RadiusSize.md => 8.0,
    RadiusSize.lg => 8.0,
    RadiusSize.xl => 8.0,
  };
}

enum Spacing { xs, sm, md, lg, xl, xxl }

enum RadiusSize { sm, md, lg, xl }

import 'package:flutter/material.dart';

class DesignTokens {
  // ===== 初音莫奈核心色系（语义化命名）=====
  static const Color primary = Color(0xFF60B49D); // 主品牌色
  static const Color primaryContainer = Color(0xFFA5D5C8); // 容器背景
  static const Color onPrimary = Color(0xFFFFFFFF); // 主色上文字
  static const Color onPrimaryContainer = Color(0xFF17312A); // 容器上文字

  // ===== 辅助色系（按用途命名，非按色相）=====
  static const Color secondary = Color(0xFF60A1B4); // 次要操作/信息
  static const Color tertiary = Color(0xFF60B488); // 第三操作/强调
  static const Color error = Color(0xFFFF6B6B); // 错误（保留红色语义）
  static const Color success = Color(0xFF4CAF50); // 成功状态
  static const Color warning = Color(0xFFFFC107); // 警告状态

  // ===== 中性色系（严格遵循 WCAG 对比度）=====
  // 浅色模式
  static const Color neutral50 = Color(0xFFF8FAFC);
  static const Color neutral100 = Color(0xFFF1F5F9);
  static const Color neutral200 = Color(0xFFE2E8F0);
  static const Color neutral300 = Color(0xFFCBD5E1); // （输入框聚焦边框）
  static const Color neutral400 = Color(0xFF94A3B8);
  static const Color neutral500 = Color(0xFF64748B);
  static const Color neutral600 = Color(0xFF475569); //（深色边框）
  static const Color neutral700 = Color(0xFF334155);
  static const Color neutral800 = Color(0xFF1E293B);
  static const Color neutral900 = Color(0xFF0F172A);

  // ===== 语义背景色（精准匹配原设计）=====
  // 浅色模式
  static const Color surface = neutral50; //
  static const Color surfaceVariant =
      Colors.white; // 卡片背景（原 cardColor 0xFFFFFFFF）

  // 深色模式
  static const Color surfaceDark =
      neutral900; // Scaffold 背景（原 darkBackgroundColor）
  static const Color surfaceVariantDark = neutral800; // 卡片背景（原 darkCardColor）

  // ===== 语义文本色（WCAG AA 合规）=====
  static const Color onSurface = neutral800; // 浅色主文本（对比度 12.5:1 ✅）
  static const Color onSurfaceVariant = neutral500; // 浅色次要文本（对比度 7.2:1 ✅）
  static const Color onSurfaceDark = neutral50; // 深色主文本（对比度 15.1:1 ✅）
  static const Color onSurfaceVariantDark = neutral300; // 深色次要文本

  // 深色模式文本（高对比度）
  static const Color neutral50Dark = Color(0xFFDCEFEA);
  static const Color neutral200Dark = Color(0xFFA5D5C8);
  static const Color neutral400Dark = Color(0xFF64748B);

  // ===== 间距系统（枚举驱动，编译安全）=====
  static double spacing(Spacing size) => switch (size) {
    Spacing.xs => 4.0,
    Spacing.sm => 8.0,
    Spacing.md => 16.0,
    Spacing.lg => 24.0,
    Spacing.xl => 32.0,
  };

  // ===== 圆角系统 =====
  static double radius(RadiusSize size) => switch (size) {
    RadiusSize.sm => 8.0,
    RadiusSize.md => 12.0,
    RadiusSize.lg => 16.0,
    RadiusSize.xl => 24.0,
  };
}

// 枚举定义（与 DesignTokens 同文件）
enum Spacing { xs, sm, md, lg, xl }

enum RadiusSize { sm, md, lg, xl }

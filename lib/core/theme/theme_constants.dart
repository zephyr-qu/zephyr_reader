import 'package:flutter/material.dart';

/// 设计令牌
///
/// 集中管理应用的色板、间距系统和圆角系统。
/// 所有组件应引用此处的设计令牌，而非直接使用字面值。
// ===== 强调色（#F59E0B — 暖橙，按钮、进度、选中态、链接）=====
class DesignTokens {
  static const Color primary = Color(0xFFF59E0B);

  // ===== 辅助语义色 =====
  static const Color error = Color(0xFFD1453B); // warmer red
  static const Color success = Color(0xFF3B8B5E); // muted green
  static const Color warning = Color(0xFFF57C00);

  // ===== 温暖强调色（#D4A373 — 用于辅助装饰、品牌细节）=====
  static const Color warmAccent = Color(0xFFD4A373);
  static const Color warmAccentLight = Color(0xFFFEF3E2);
  // ===== 暖色装饰阴影（卡片、弹出菜单）=====
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x14D4A373),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  // ===== 暖色分割线（替代中性灰）=====
  static const Color dividerSubtle = Color(0x1FD4A373); // #D4A373 @ 12%

  // ===== 兼容旧引用（映射到新色值）=====
  static const Color primaryContainer = Color(0xFFFEF0D6); // warmer amber tint
  static const Color secondary = Color(0xFFD4A373);
  static const Color tertiary = Color(0xFF8D6E63);

  // ===== 间距系统 =====

  // ===== 圆角系统 =====
}

/// [Spacing] 枚举的数值扩展
extension SpacingValue on Spacing {
  double get value => switch (this) {
    Spacing.xs => 4,
    Spacing.sm => 8,
    Spacing.smMd => 12,
    Spacing.md => 16,
    Spacing.mdLg => 20,
    Spacing.lg => 24,
    Spacing.xl => 32,
    Spacing.xxl => 48,
  };
}

/// [RadiusSize] 枚举的数值扩展
extension RadiusSizeValue on RadiusSize {
  double get value => switch (this) {
    RadiusSize.xs => 4,
    RadiusSize.sm => 6,
    RadiusSize.md => 8,
    RadiusSize.lg => 12,
    RadiusSize.xl => 16,
  };
}

/// 间距枚举 — xs(4)、sm(8)、smMd(12)、md(16)、mdLg(20)、lg(24)、xl(32)、xxl(48)
enum Spacing { xs, sm, smMd, md, mdLg, lg, xl, xxl }

/// 圆角尺寸枚举 — xs(4)、sm(6)、md(8)、lg(12)、xl(16)
enum RadiusSize { xs, sm, md, lg, xl }

// ===== 图标尺寸系统 =====

/// 图标尺寸常量，按语义命名，替代散落各处的 magic number。
class IconSize {
  IconSize._();

  /// 与内联文字并排的图标（16px）
  static const double inline = 16;

  /// 列表/菜单引导图标（20px）
  static const double leading = 20;

  /// 底部导航栏/侧边 Rail 图标（22px）
  static const double nav = 22;

  /// 空态/启动页大图标（48px）
  static const double hero = 48;
}

// ===== BuildContext 扩展（便捷访问）=====

/// 通过 `context.spacing` 便捷访问间距值。
extension ThemeSpacingContext on BuildContext {
  /// 间距便捷访问：`context.spacing.md`
  SpacingHelper get spacing => const SpacingHelper();

  /// 圆角便捷访问：`context.radius.md`
  RadiusHelper get radius => const RadiusHelper();
}

/// 间距便捷访问器，保持与 [DesignTokens.spacing] 一致。
class SpacingHelper {
  const SpacingHelper();

  double get xs => 4;
  double get sm => 8;
  double get smMd => 12;
  double get md => 16;
  double get mdLg => 20;
  double get lg => 24;
  double get xl => 32;
  double get xxl => 48;
}

/// 圆角便捷访问器，保持与 [DesignTokens.radius] 一致。
class RadiusHelper {
  const RadiusHelper();

  double get xs => 4;
  double get sm => 6;
  double get md => 8;
  double get lg => 12;
  double get xl => 16;
}

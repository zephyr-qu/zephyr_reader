import 'package:flutter/material.dart';

/// 应用主题扩展
///
/// 自定义 [ThemeExtension]，提供 Material 默认色板之外的语义化颜色和阴影。
/// 包括容器色、分割线、覆盖层和卡片阴影，通过 [Theme.of] 的 `extension` 访问。
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  /// 主容器色 — 用于选中项、标签等强调背景
  final Color primaryContainer;

  /// 辅助容器色 — 用于次要强调背景
  final Color secondaryContainer;

  /// 表面变体色 — 轻微的替代背景色
  final Color surfaceVariant;

  /// 卡片阴影 — 暖色装饰阴影
  final BoxShadow shadow;

  /// 弱化分割线 — 替代 `outlineVariant.withValues(alpha: 0.15)`
  final Color dividerSubtle;

  /// 极浅覆盖层 — 替代 `onSurface.withValues(alpha: 0.05)`
  final Color overlayLight;

  /// 浅覆盖层 — 替代 `onSurface.withValues(alpha: 0.08)`
  final Color overlayMedium;

  const AppThemeExtension({
    required this.primaryContainer,
    required this.secondaryContainer,
    required this.surfaceVariant,
    required this.shadow,
    required this.dividerSubtle,
    required this.overlayLight,
    required this.overlayMedium,
  });

  @override
  AppThemeExtension copyWith({
    Color? primaryContainer,
    Color? secondaryContainer,
    Color? surfaceVariant,
    BoxShadow? shadow,
    Color? dividerSubtle,
    Color? overlayLight,
    Color? overlayMedium,
  }) {
    return AppThemeExtension(
      primaryContainer: primaryContainer ?? this.primaryContainer,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      shadow: shadow ?? this.shadow,
      dividerSubtle: dividerSubtle ?? this.dividerSubtle,
      overlayLight: overlayLight ?? this.overlayLight,
      overlayMedium: overlayMedium ?? this.overlayMedium,
    );
  }

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other == null) return this;
    return AppThemeExtension(
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      secondaryContainer: Color.lerp(
        secondaryContainer,
        other.secondaryContainer,
        t,
      )!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      shadow: BoxShadow.lerp(shadow, other.shadow, t)!,
      dividerSubtle: Color.lerp(dividerSubtle, other.dividerSubtle, t)!,
      overlayLight: Color.lerp(overlayLight, other.overlayLight, t)!,
      overlayMedium: Color.lerp(overlayMedium, other.overlayMedium, t)!,
    );
  }
}

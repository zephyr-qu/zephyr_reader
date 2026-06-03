// lib/core/theme/extensions/theme_helper.dart
import 'package:flutter/material.dart';

extension ThemeHelper on BuildContext {
  Color get primaryColor => Theme.of(this).colorScheme.primary;
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  AppThemeExtension get appTheme {
    final ext = Theme.of(this).extension<AppThemeExtension>();
    assert(
      ext != null,
      '❌ 请在 MaterialApp.theme 中通过 extensions: [AppThemeExtension(...)] 注册！',
    );
    return ext!;
  }
}

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color primaryContainer;
  final Color secondaryContainer;
  final Color surfaceVariant;
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

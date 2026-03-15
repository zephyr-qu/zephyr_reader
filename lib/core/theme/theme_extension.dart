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

// lib/core/theme/app_theme.dart
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color primaryContainer;
  final Color secondaryContainer;
  final Color surfaceVariant;
  final BoxShadow shadow;

  const AppThemeExtension({
    required this.primaryContainer,
    required this.secondaryContainer,
    required this.surfaceVariant,
    required this.shadow,
  });

  @override
  AppThemeExtension copyWith({
    Color? primaryContainer,
    Color? secondaryContainer,
    Color? surfaceVariant,
    BoxShadow? shadow,
  }) {
    return AppThemeExtension(
      primaryContainer: primaryContainer ?? this.primaryContainer,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      shadow: shadow ?? this.shadow,
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
    );
  }
}

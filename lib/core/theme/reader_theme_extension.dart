import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

class ReaderThemeExtension extends ThemeExtension<ReaderThemeExtension> {
  final Color textColor;
  final Color mutedColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color dividerColor;
  final Color accentColor;
  final Color ttsActiveColor;

  const ReaderThemeExtension({
    required this.textColor,
    required this.mutedColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.dividerColor,
    required this.accentColor,
    required this.ttsActiveColor,
  });

  factory ReaderThemeExtension.light() => const ReaderThemeExtension(
    textColor: Color(0xFF2C2C2C),
    mutedColor: Color(0xFF6B6B76),
    backgroundColor: Color(0xFFF8F6F0),
    surfaceColor: Color(0xFFFFFDF7),
    dividerColor: Color(0xFFEDEBE4),
    accentColor: DesignTokens.warmAccent,
    ttsActiveColor: Color(0xFF2E7D32),
  );

  factory ReaderThemeExtension.dark() => const ReaderThemeExtension(
    textColor: Color(0xFFE8E6E1),
    mutedColor: Color(0xFF8E8E99),
    backgroundColor: Color(0xFF111118),
    surfaceColor: Color(0xFF1A1A24),
    dividerColor: Color(0xFF2A2A35),
    accentColor: DesignTokens.warmAccent,
    ttsActiveColor: Color(0xFF66BB6A),
  );

  @override
  ReaderThemeExtension copyWith({
    Color? textColor,
    Color? mutedColor,
    Color? backgroundColor,
    Color? surfaceColor,
    Color? dividerColor,
    Color? accentColor,
    Color? ttsActiveColor,
  }) {
    return ReaderThemeExtension(
      textColor: textColor ?? this.textColor,
      mutedColor: mutedColor ?? this.mutedColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      dividerColor: dividerColor ?? this.dividerColor,
      accentColor: accentColor ?? this.accentColor,
      ttsActiveColor: ttsActiveColor ?? this.ttsActiveColor,
    );
  }

  @override
  ReaderThemeExtension lerp(ReaderThemeExtension? other, double t) {
    if (other == null) return this;
    return ReaderThemeExtension(
      textColor: Color.lerp(textColor, other.textColor, t)!,
      mutedColor: Color.lerp(mutedColor, other.mutedColor, t)!,
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t)!,
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t)!,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t)!,
      accentColor: Color.lerp(accentColor, other.accentColor, t)!,
      ttsActiveColor: Color.lerp(ttsActiveColor, other.ttsActiveColor, t)!,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';

/// 阅读器主题扩展
///
/// 自定义 [ThemeExtension]，定义阅读页专用的颜色体系。
/// 提供亮色、深色和护眼色（sepia）三套预设配色方案，
/// 包括文字、背景、分割线、强调色和 TTS 激活色。
class ReaderThemeExtension extends ThemeExtension<ReaderThemeExtension> {
  /// 正文文字色
  final Color textColor;

  /// 弱化文字色 — 用于辅助信息或不可交互元素
  final Color mutedColor;

  /// 背景色
  final Color backgroundColor;

  /// 表面色 — 卡片、面板等浮层背景
  final Color surfaceColor;

  /// 分割线色
  final Color dividerColor;

  /// 强调色 — 链接、选中标记等
  final Color accentColor;

  /// TTS 朗读激活色 — 正在朗读的文本高亮色
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

  /// 护眼色：暖米色底 + 棕褐文字，阅读器护眼色主题。
  factory ReaderThemeExtension.sepia() => const ReaderThemeExtension(
    textColor: Color(0xFF4A3F35),
    mutedColor: Color(0xFF8B7E6E),
    backgroundColor: Color(0xFFF8F4EA),
    surfaceColor: Color(0xFFEFE9DA),
    dividerColor: Color(0xFFD9D0BD),
    accentColor: Color(0xFFA0522D),
    ttsActiveColor: Color(0xFF2E7D32),
  );

  /// 根据 [ReaderTheme] 枚举值解析对应预设。
  factory ReaderThemeExtension.resolve(ReaderTheme theme) => switch (theme) {
    ReaderTheme.dark => ReaderThemeExtension.dark(),
    ReaderTheme.sepia => ReaderThemeExtension.sepia(),
    ReaderTheme.light => ReaderThemeExtension.light(),
  };

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

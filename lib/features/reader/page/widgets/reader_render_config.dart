import 'package:flutter/material.dart';

@immutable
/// 阅读器渲染配置。
///
/// 聚合文本颜色、背景色、字体、行距等排版参数，供各渲染器使用。
class ReaderRenderConfig {
  final Color textColor;
  final Color backgroundColor;
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final double letterSpacing;
  final double paragraphSpacing;
  final double pageMargin;
  final String searchQuery;
  final bool searchMatchHighlight;
  final bool showVocabularyMark;
  final Set<String> vocabularyWords;

  const ReaderRenderConfig({
    required this.textColor,
    required this.backgroundColor,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.letterSpacing,
    required this.paragraphSpacing,
    required this.pageMargin,
    required this.searchQuery,
    required this.searchMatchHighlight,
    required this.showVocabularyMark,
    required this.vocabularyWords,
  });

  Set<String> get effectiveVocabWords =>
      showVocabularyMark ? vocabularyWords : const {};

  // ── 字体常量与回退栈（原 FontConfig） ──
  static const String chineseFont = 'Noto Serif SC';
  static const String latinFont = 'Roboto';

  static const List<String> fallbackStack = [
    'PingFang SC',
    'Microsoft YaHei',
    'Hiragino Sans GB',
    'WenQuanYi Micro Hei',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
    'sans-serif',
  ];

  /// 构造阅读器正文字体样式。
  /// 默认使用本 config 的 `textColor` / `fontFamily` / `letterSpacing`，
  TextStyle buildTextStyle({
    Color? color,
    String? fontFamily,
    bool useLatin = false,
    double fontSizeMultiplier = 1.0,
  }) {
    return TextStyle(
      fontSize: fontSize * fontSizeMultiplier,
      height: lineHeight,
      color: color ?? textColor,
      fontFamily: fontFamily ?? _resolveFontFamily(useLatin),
      fontFamilyFallback: fallbackStack,
      letterSpacing: letterSpacing,
    );
  }

  /// 构造阅读器正文字体的 StrutStyle。
  StrutStyle buildStrutStyle({
    String? fontFamily,
    bool useLatin = false,
    double fontSizeMultiplier = 1.0,
  }) {
    return StrutStyle(
      fontFamily: fontFamily ?? _resolveFontFamily(useLatin),
      fontFamilyFallback: fallbackStack,
      fontSize: fontSize * fontSizeMultiplier * 0.95,
      height: lineHeight,
      forceStrutHeight: true,
    );
  }

  String _resolveFontFamily(bool useLatin) {
    if (fontFamily.isNotEmpty) return fontFamily;
    return useLatin ? latinFont : chineseFont;
  }
}

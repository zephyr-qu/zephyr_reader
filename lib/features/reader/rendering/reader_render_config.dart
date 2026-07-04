import 'package:flutter/material.dart';

@immutable
/// 阅读器渲染配置。
///
/// 聚合文本颜色、背景色、字体、行距等排版参数，供各渲染器使用。
class ReaderRenderConfig {
  /// 分页/翻页正文区域上下内边距（逻辑像素）。
  /// 须与 [PaginatedModeRenderer] 一致，并计入 Rust 分页有效页高。
  static const double pageContentVerticalPadding = 20.0;
  final Color textColor;
  final Color backgroundColor;
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final double letterSpacing;
  /// 段落间距（逻辑像素 dp）。传给 Rust 时自动转换为倍数（dp / fontSize）。
  final double paragraphSpacing;
  final double pageMargin;
  final bool showVocabularyMark;

  /// 用户首行缩进开关；IR 无显式 `textIndentEm` 时生效（ADR-010）。
  final bool firstLineIndent;

  /// 一行文本的像素高度（fontSize × lineHeight）。
  double get textRowHeight => fontSize * lineHeight;
  final bool baselineAlign;
  final Set<String> vocabularyWords;
  final TextAlign textAlign;

  const ReaderRenderConfig({
    required this.textColor,
    required this.backgroundColor,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.letterSpacing,
    required this.paragraphSpacing,
    required this.pageMargin,
    required this.showVocabularyMark,
    required this.vocabularyWords,
    this.firstLineIndent = true,
    this.textAlign = TextAlign.justify,
    this.baselineAlign = true,
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

  /// 与 [buildTextStyle] 使用相同字号，避免 `forceStrutHeight` 把行高压扁。
  StrutStyle buildStrutStyle({
    String? fontFamily,
    bool useLatin = false,
    double fontSizeMultiplier = 1.0,
  }) {
    final size = fontSize * fontSizeMultiplier;
    return StrutStyle(
      fontFamily: fontFamily ?? _resolveFontFamily(useLatin),
      fontFamilyFallback: fallbackStack,
      fontSize: size,
      height: lineHeight,
      forceStrutHeight: baselineAlign,
      leading: 0,
    );
  }

  /// 分页/滚动正文统一的行高行为（CJK 占满行盒）。
  static const TextHeightBehavior textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: true,
    applyHeightToLastDescent: true,
  );

  String _resolveFontFamily(bool useLatin) {
    if (fontFamily.isNotEmpty) return fontFamily;
    return useLatin ? latinFont : chineseFont;
  }
}

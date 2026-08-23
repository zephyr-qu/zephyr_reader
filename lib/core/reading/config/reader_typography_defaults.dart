/// 阅读器排版推荐默认值（Readium 百分比体系）。
///
/// 字体大小使用 Readium 百分比标度（100 = 100% = 不做缩放），
/// 与 typesetting_panel 的 slider 80–200 范围对齐。
class ReaderTypographyDefaults {
  ReaderTypographyDefaults._();

  /// 默认字号 100%（不缩放 EPUB 原本字号）。
  static const double fontSize = 100.0;

  /// 阅读页字号范围，避免过小或过大导致排版失真。
  static const double minFontSize = 80.0;
  static const double maxFontSize = 180.0;

  /// 旧设置界面的页边距范围；Readium 侧使用以 [padding] 为 1.0 的倍率。
  static const double minPadding = 12.0;
  static const double maxPadding = 36.0;

  static const double padding = 20.0;
  static const int readerBgColorIndex = 1; // 羊皮纸 #F5F0E8

  /// 默认字重（400 = 常规）。
  static const double fontWeight = 400.0;

  /// 字重可调范围（Readium 支持 100–900）。
  static const double minFontWeight = 300.0;
  static const double maxFontWeight = 700.0;

  /// Readium line-height multiplier.
  static const double lineHeight = 1.4;

  static const double minLineHeight = 1.2;
  static const double maxLineHeight = 2.0;

  /// Readium letter spacing in em units.
  static const double letterSpacing = 0.0;

  /// Readium paragraph spacing in em units.
  static const double paragraphSpacing = 0.0;

  /// Readium paragraph indent in em units.
  static const double paragraphIndent = 0.0;

  static const double minLetterSpacing = -0.05;
  static const double maxLetterSpacing = 0.2;
  static const double maxParagraphSpacing = 2.0;
  static const double maxParagraphIndent = 2.0;
}

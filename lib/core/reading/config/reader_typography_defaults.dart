/// 阅读器排版推荐默认值（Readium 百分比体系）。
///
/// 字体大小使用 Readium 百分比标度（100 = 100% = 不做缩放），
/// 与 typesetting_panel 的 slider 80–200 范围对齐。
class ReaderTypographyDefaults {
  ReaderTypographyDefaults._();

  /// 默认字号 100%（不缩放 EPUB 原本字号）。
  static const double fontSize = 100.0;

  /// 旧设置界面的页边距范围；Readium 侧使用以 [padding] 为 1.0 的倍率。
  static const double minPadding = 8.0;
  static const double maxPadding = 40.0;

  static const double padding = 20.0;
  static const int readerBgColorIndex = 1; // 羊皮纸 #F5F0E8

  /// 默认字重（400 = 常规）。
  static const double fontWeight = 400.0;

  /// 字重可调范围（Readium 支持 100–900）。
  static const double minFontWeight = 300.0;
  static const double maxFontWeight = 700.0;
}

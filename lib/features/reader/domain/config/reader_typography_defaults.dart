/// 阅读器排版推荐默认值（横排滚动 / 分页通用，偏中文长篇）。
///
/// 设计依据：手机单手阅读、18sp 正文字号、1.8 行高约 32px 行距，
/// 段落间距 16px 与行高协调，边距 20 留出拇指安全区。
class ReaderTypographyDefaults {
  ReaderTypographyDefaults._();

  static const double fontSize = 18.0;
  /// 中文长篇阅读推荐 1.8（约 32px @ 18sp），与 Rust `line_spacing` 对齐。
  static const double lineHeight = 1.8;
  static const double paragraphSpacing = 16.0;
  static const double padding = 20.0;
  static const double letterSpacing = 0.0;
  static const double autoSpaceRatio = 0.25;
  static const int readerBgColorIndex = 1; // 羊皮纸 #F5F0E8
}

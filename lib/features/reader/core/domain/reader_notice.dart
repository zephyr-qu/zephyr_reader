/// 阅读器需向用户展示的轻量通知（由 UI 层翻译为 toast）。
enum ReaderNotice {
  /// EPUB 章节过大，已降级为纯文本显示（无图片/样式）。
  epubRichSkipped,
}

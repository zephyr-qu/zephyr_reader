import 'package:flutter/material.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

/// 滚动拼接用单章加载结果（不依赖仓库 currentRich* 单例）。
typedef ScrollChapterPayload = ({
  String content,
  List<RichParagraph>? richParagraphs,
  TextSpan? richRootSpan,
  bool epubRichSkipped,
});

/// 纯文本章节 payload。
ScrollChapterPayload scrollPlainPayload(
  String content, {
  bool epubRichSkipped = false,
}) =>
    (
      content: content,
      richParagraphs: null,
      richRootSpan: null,
      epubRichSkipped: epubRichSkipped,
    );


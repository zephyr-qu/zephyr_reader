import 'package:flutter/material.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

/// 滚动拼接用单章加载结果（不依赖仓库 currentRich* 单例）。
typedef ScrollChapterPayload = ({
  String content,
  List<RichParagraph>? richParagraphs,
  TextSpan? richRootSpan,
  bool epubRichSkipped,
  ChapterContentIr? chapterIr,
  String? chapterFilePath,
});

/// 纯文本章节 payload。
ScrollChapterPayload scrollPlainPayload(
  String content, {
  bool epubRichSkipped = false,
  ChapterContentIr? chapterIr,
  String? chapterFilePath,
}) => (
  content: content,
  richParagraphs: null,
  richRootSpan: null,
  epubRichSkipped: epubRichSkipped,
  chapterIr: chapterIr,
  chapterFilePath: chapterFilePath,
);

/// IR 章节 payload（scroll 主路径，ADR-009）。
ScrollChapterPayload scrollIrPayload({
  required ChapterContentIr chapterIr,
  required String chapterFilePath,
}) => (
  content: chapterIr.plainText,
  richParagraphs: null,
  richRootSpan: null,
  epubRichSkipped: false,
  chapterIr: chapterIr,
  chapterFilePath: chapterFilePath,
);

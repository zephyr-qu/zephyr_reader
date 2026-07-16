import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';

/// 滚动拼接用单章加载结果（不依赖仓库 current* 单例）。
typedef ScrollChapterPayload = ({
  String content,
  bool epubRichSkipped,
  ReaderChapterIr? chapterIr,
  String? chapterFilePath,
});

/// 纯文本章节 payload。
ScrollChapterPayload scrollPlainPayload(
  String content, {
  bool epubRichSkipped = false,
  ReaderChapterIr? chapterIr,
  String? chapterFilePath,
}) => (
  content: content,
  epubRichSkipped: epubRichSkipped,
  chapterIr: chapterIr,
  chapterFilePath: chapterFilePath,
);

/// IR 章节 payload（scroll 主路径，ADR-009）。
ScrollChapterPayload scrollIrPayload({
  required ReaderChapterIr chapterIr,
  required String chapterFilePath,
}) => (
  content: chapterIr.plainText,
  epubRichSkipped: false,
  chapterIr: chapterIr,
  chapterFilePath: chapterFilePath,
);

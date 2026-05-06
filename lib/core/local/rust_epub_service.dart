/// Rust EPUB 解析服务
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as rust_core;
import 'package:zephyr_reader/src/rust/api/epub.dart' as rust;
import 'package:zephyr_reader/src/rust/ffi/types.dart';

@LazySingleton()
class RustEpubService {
  bool isEpubFile(String filePath) => rust.isEpubFile(filePath: filePath);

  rust.ApiResultEpubMetadata getEpubMetadata(String filePath) =>
      rust.getEpubMetadata(filePath: filePath);

  rust.ApiResultRichChapterContent parseEpubChapterRich({
    required String filePath,
    required int chapterIndex,
  }) =>
      rust.parseEpubChapterRich(filePath: filePath, chapterIndex: chapterIndex);

  rust_core.ApiResultVecPageContent getEpubChapterContent({
    required String filePath,
    required int chapterId,
    required TypesetConfig config,
  }) => rust.getEpubChapterContent(
    filePath: filePath,
    chapterId: chapterId,
    config: config,
  );

  rust.ApiResultVecRichParagraph getEpubChapterRichContent({
    required String filePath,
    required int chapterId,
    required TypesetConfig config,
  }) => rust.getEpubChapterRichContent(
    filePath: filePath,
    chapterId: chapterId,
    config: config,
  );

  List<PageContent> paginateEpubRichContent({
    required List<RichParagraph> paragraphs,
    required int chapterIndex,
    required TypesetConfig config,
  }) => rust.paginateEpubRichContent(
    paragraphs: paragraphs,
    chapterIndex: chapterIndex,
    config: config,
  );
}

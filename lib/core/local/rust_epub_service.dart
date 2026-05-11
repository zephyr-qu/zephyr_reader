/// Rust EPUB 解析服务
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/epub.dart' as rust;
import 'package:zephyr_reader/src/rust/domain/types.dart';

@LazySingleton()
class RustEpubService {
  Future<EpubMetadata> getEpubMetadata(String filePath) async =>
      rust.getEpubMetadata(filePath: filePath);

  Future<RichChapterContent> parseEpubChapterRich({
    required String filePath,
    required int chapterIndex,
  }) async =>
      rust.parseEpubChapterRich(
          filePath: filePath, chapterIndex: chapterIndex);

  Future<List<RichParagraph>> getEpubChapterRichContent({
    required String filePath,
    required int chapterIndex,
    required TypesetConfig config,
  }) async =>
      await rust.getEpubChapterRichContent(
              filePath: filePath,
              chapterIndex: chapterIndex,
              config: config);

  List<PageContent> paginateEpubRichContent({
    required List<RichParagraph> paragraphs,
    required int chapterIndex,
    required TypesetConfig config,
  }) =>
      rust.paginateEpubRichContent(
        paragraphs: paragraphs,
        chapterIndex: chapterIndex,
        config: config,
      );
}

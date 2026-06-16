import 'package:flutter/material.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 章节内容仓库抽象。
abstract class ChapterContentRepository {
  Future<List<Chapter>> getChapters(String bookId);

  Future<String> loadContent(
    String bookId,
    int chapterId, {
    ReadingMode? readingMode,
  });

  Future<String> loadFirstSpine(String bookId, int chapterId);

  Future<void> preload(String bookId, int chapterId);

  Future<void> preloadNextChapterFirstPage(
    String bookId,
    int chapterIndex, {
    double fontSize = 16,
    double lineHeight = 1.6,
    double width = 400,
    double height = 600,
    double padding = 20,
  });

  void clearPreloadedNextChapter();

  bool get hasPreloadedNextChapter;

  String? getPreloadedNextChapterContent(int chapterIndex, {int pageIndex = 0});

  /// 当前章节的富文本内容（EPUB/MD）。
  TextSpan? get currentRichContent;

  /// 当前章节的富文本段落。
  List<RichParagraph>? get currentRichParagraphs;

  /// 预加载完成时递增，供 UI 监听重建。
  ValueNotifier<int> get preloadGeneration;
}

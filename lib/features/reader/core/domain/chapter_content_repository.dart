import 'package:flutter/material.dart' show ValueNotifier;
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/data/next_chapter_staging.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_payload.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/features/reader/data/ir_types.dart';
import 'package:zephyr_reader/src/rust/domain/chapter/models.dart';

/// 章节内容仓库抽象。
abstract class ChapterContentRepository {
  Future<List<Chapter>> getChapters(String bookId);

  Future<String> loadContent(
    String bookId,
    int chapterId, {
    ReadingMode? readingMode,
  });

  /// 加载单章滚动拼接数据。
  Future<ScrollChapterPayload> loadScrollSegment(
    String bookId,
    int chapterId, {
    ReadingMode? readingMode,
  });

  Future<void> preload(String bookId, int chapterId);

  /// 当前章节的 IR 块流（scroll 主路径）。
  ReaderChapterIr? get currentChapterIr;

  /// 当前章节对应书籍文件路径（EPUB 图片解码用）。
  String? get currentChapterFilePath;

  /// 预加载完成时递增，供 UI 监听重建。
  ValueNotifier<int> get preloadGeneration;

  /// 后台预加载的下一章分页 staging。
  NextChapterStaging? get nextChapterStaging;

  /// 后台预加载的上一章分页 staging（末页）。
  NextChapterStaging? get prevChapterStaging;

  Future<void> preloadNextChapterStaging(
    String bookId,
    int chapterIndex, {
    double fontSize = 16,
    double lineHeight = 1.6,
    double width = 400,
    double height = 600,
    double padding = 20,
    double devicePixelRatio = 1.0,
    String fontFamily = 'Noto Sans SC',
  });

  /// 后台预加载上一章分页 staging（末页）。
  Future<void> preloadPreviousChapterStaging(
    String bookId,
    int chapterIndex, {
    double fontSize = 16,
    double lineHeight = 1.6,
    double width = 400,
    double height = 600,
    double padding = 20,
    double devicePixelRatio = 1.0,
    String fontFamily = 'Noto Sans SC',
  });

  /// 清除预加载 staging。
  void clearNextChapterStaging();

  /// 清除相邻双向 staging。
  void clearAdjacentStaging();

  /// 同步当前 UI 排版参数，供 EPUB 富文本加载与分页 staging 共用。
  void syncChapterTypesetLayout(PaginationParams params);

  /// 取出并清除「EPUB 富文本已降级」标记（每次加载最多消费一次）。
  bool consumeEpubRichSkippedNotice();
}

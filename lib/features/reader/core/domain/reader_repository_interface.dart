import 'package:flutter/material.dart';
import 'package:zephyr_reader/features/reader/core/domain/progress_repository.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/features/reader/core/data/next_chapter_staging.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_payload.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';

export 'package:zephyr_reader/features/reader/core/domain/progress_repository.dart'
    show ReadingProgressData;

/// 阅读器数据仓库抽象接口。
///
/// 定义应用层依赖的契约，[ReaderRepository] 实现此接口。
/// 接口位于 domain 层，实现位于 data/repositories 层。
abstract class ReaderRepositoryInterface {
  // ==================== 章节和内容 ====================

  /// 获取书籍章节列表。
  Future<List<Chapter>> getChapters(String bookId);

  /// 加载章节纯文本内容。
  Future<String> loadChapterContent(
    String bookId,
    int chapterId, {
    ReadingMode? readingMode,
  });

  /// 滚动跨章拼接：加载单章 payload，不覆盖当前章富文本缓存。
  Future<ScrollChapterPayload> loadScrollSegment(
    String bookId,
    int chapterId, {
    ReadingMode? readingMode,
  });

  /// 上次分页的 configHash；null 表示无 session。
  int? get sessionConfigHash;

  /// 当前分页会话对应的章节索引；null 表示无 session。
  int? get sessionChapterIndex;

  /// 当前分页结果是否为部分分页。
  bool get sessionIsPartial;

  /// 分页引擎模式。
  ChapterPaginationMode get sessionMode;

  /// 分页 session 文件路径（EPUB 图片用）。
  String? get sessionFilePath;

  /// In-place repaginate：复用现有 session handle，更新 config。
  /// handle 不存在时退化到 [beginPaginate]（用真实 bookId/chapterIndex）。
  Future<({int totalPages, bool isPartial})> repaginateInPlace({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  });

  /// 预加载章节内容到缓存。
  Future<void> preloadChapter(String bookId, int chapterId);

  /// 同步 UI 排版参数到章节内容仓库（EPUB 富文本 / staging 共用）。
  void syncChapterTypesetLayout(PaginationParams params);

  /// 取出并清除「EPUB 富文本已降级」标记。
  bool consumeEpubRichSkippedNotice();

  // ==================== 缓存和页面内容 ====================

  /// 当前章节的富文本内容（EPUB）。
  TextSpan? get currentRichContent;

  /// 当前章节的富文本段落（EPUB）。
  List<RichParagraph>? get currentRichParagraphs;

  /// P4-1：当前章 IR（scroll）。
  ChapterContentIr? get currentChapterIr;

  /// 当前章书籍文件路径。
  String? get currentChapterFilePath;

  /// 页面描述符列表（轻量级）。
  List<PageDescriptor>? get descriptors;

  /// 预加载生成计数器。
  ValueNotifier<int> get preloadGeneration;

  /// 手动预热单页缓存（用于分段读取）。
  void warmPageCache(int pageIndex, String content);

  /// 确保指定页面及其周围页面的内容已缓存。
  void ensurePageWindow(int centerPage);

  /// 章级 charOffset → pageIndex（session 可用时走 Rust 精确解析）。
  int? resolvePageIndexForCharOffset(int charOffset);

  /// 释放 Rust 分页会话并清空本地页缓存。
  void disposePagination();

  /// 当前分页会话的下一章预加载 staging。
  NextChapterStaging? get nextChapterStaging;

  /// 当前分页会话的上一章预加载 staging（末页）。
  NextChapterStaging? get prevChapterStaging;

  /// 预加载上一章 descriptors + 末页 content。
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


  /// 预加载下一章 descriptors + 首页 content。
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

  /// 清除预加载 staging。
  void clearNextChapterStaging();

  /// 清除相邻双向 staging。
  void clearAdjacentStaging();

  /// 创建分页会话并分页。maxChars=null 表示全章。
  Future<({int totalPages, bool isPartial})> beginPaginate({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  });

  /// 尝试从 Rust STREAMER_CACHE adopt 现有 session（零重 paginate）。
  /// 未命中时退化到 [beginPaginate]（full createPaginationSession）。
  Future<({int totalPages, bool isPartial})> beginPaginateFromCache({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  });

  /// 在同一会话上扩展到全章。
  Future<({int totalPages, bool isPartial})> expandToFullChapter({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
  });
  // ==================== 阅读进度 ====================

  /// 加载书籍的阅读进度。
  Future<ReadingProgressData?> loadReadingProgress(String bookId);

}

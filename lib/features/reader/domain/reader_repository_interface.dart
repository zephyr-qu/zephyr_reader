import 'package:flutter/material.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import '../../../core/reader/reader_config.dart';

/// 阅读进度数据。
class ReadingProgressData {
  final String bookId;
  final int chapterIndex;
  final int charOffset;
  final int pageIndex;
  final int totalPages;
  final int readingTimeSeconds;
  final DateTime lastReadAt;
  const ReadingProgressData({
    required this.bookId,
    required this.chapterIndex,
    required this.charOffset,
    required this.pageIndex,
    required this.totalPages,
    required this.readingTimeSeconds,
    required this.lastReadAt,
  });
}

/// 阅读器数据仓库抽象接口。
///
/// 定义应用层依赖的契约，[ReaderRepository] 实现此接口。
/// 接口位于 domain 层，实现位于 data/repositories 层。
abstract class ReaderRepositoryInterface {
  // ==================== 章节和内容 ====================

  /// 获取书籍章节列表。
  Future<List<Chapter>> getChapters(String bookId);

  /// 加载章节纯文本内容。
  Future<String> loadChapterContent(String bookId, int chapterId,
      {ReadingMode? readingMode});

  /// 快速获取章节首段文本。
  Future<String> loadChapterFirstSpine(String bookId, int chapterId);

  /// 预加载章节内容到缓存。
  Future<void> preloadChapter(String bookId, int chapterId);

  /// 预加载下一章节首页，用于跨章节翻页动画。
  Future<void> preloadNextChapterFirstPage(
    String bookId,
    int chapterIndex, {
    double fontSize = 16,
    double lineHeight = 1.6,
    double width = 400,
    double height = 600,
    double padding = 20,
  });

  /// 是否有预加载的下一章首页。
  bool get hasPreloadedNextChapter;

  /// 获取预加载的下一章指定页内容。
  String? getPreloadedNextChapterContent(int chapterIndex, {int pageIndex = 0});

  /// 清除预加载的下一章缓存。
  void clearPreloadedNextChapter();

  // ==================== 分页排版 ====================

  /// Dart 估算分页（毫秒级，无需 TextPainter）。
  List<PageInfo> paginateApproximate(
    String content, {
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
    required double padding,
  });

  /// Rust 全量分页排版（返回页面总数，0 表示失败）。
  Future<int> paginateChapter({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
  });

  /// Rust 局部分页排版（50K 字符上限），用于首屏快速分页。
  Future<({int totalPages, bool isPartial})> paginateChapterPartial({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
  });

  /// 完整分页加载（从 Rust 获取轻量级描述符，文本按需加载）。
  /// 返回 [PageInfo] 列表。
  Future<List<PageInfo>> calculatePages({
    required String bookId,
    required int chapterId,
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
    required double padding,
  });

  // ==================== 缓存和页面内容 ====================

  /// 当前章节的分页结果（Dart 估算路径的降级数据）。
  List<PageInfo>? currentPages;

  /// 当前章节的富文本内容（EPUB）。
  TextSpan? currentRichContent;

  /// 当前章节的富文本段落（EPUB）。
  List<RichParagraph>? currentRichParagraphs;

  /// 页面描述符列表（轻量级）。
  List<PageDescriptor>? get descriptors;

  /// 预加载生成计数器。
  ValueNotifier<int> get preloadGeneration;

  /// 获取缓存的指定页内容。
  String? getPageContent(int pageIndex);

  /// 手动预热单页缓存（用于分段读取）。
  void warmPageCache(int pageIndex, String content);

  /// 确保指定页面及其周围页面的内容已缓存。
  void ensurePageWindow(int centerPage);

  // ==================== 阅读进度 ====================

  /// 加载书籍的阅读进度。
  Future<ReadingProgressData?> loadReadingProgress(String bookId);
}

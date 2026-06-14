/// 阅读器数据仓库，封装 Rust FFI 调用。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/data/rich_text_converter.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/chapter.dart' as chapter_api;
import 'package:zephyr_reader/src/rust/api/data/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/api/epub.dart' as epub_api;
import 'package:zephyr_reader/src/rust/api/md.dart' as md_api;
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 阅读进度数据
class ReadingProgressData {
  final String bookId;
  final int chapterIndex;
  final int charOffset;
  final int pageIndex;
  final int totalPages;
  final int readingTimeSeconds;
  final DateTime lastReadAt;
  ReadingProgressData({
    required this.bookId,
    required this.chapterIndex,
    required this.charOffset,
    required this.pageIndex,
    required this.totalPages,
    required this.readingTimeSeconds,
    required this.lastReadAt,
  });
}

@Injectable()
class ReaderRepository {
  ReadingProgressData? _currentProgress;

  /// 当前章节的分页结果
  List<PageInfo>? currentPages;

  /// 当前章节的富文本内容（EPUB）
  TextSpan? currentRichContent;
  List<RichParagraph>? currentRichParagraphs;

  /// 页面描述符列表（轻量级，不包含文本内容）
  List<PageDescriptor>? _descriptors;

  /// 排版配置哈希，用于按需获取页面内容
  BigInt? _configHash;

  /// 当前使用的文件路径
  String? _filePath;

  /// 当前章节索引
  int? _chapterIndex;

  /// 页面内容缓存（页码 → 文本内容）
  final Map<int, String> _pageCache = {};

  final _pagination = PaginationEngine();

  /// 书籍对象缓存 — 避免同一阅读会话中重复通过 FFI 查询 DB。
  String? _cachedBookId;
  Book? _cachedBook;

  /// 预加载的下一章首页内容缓存
  int? _preloadedNextChapterIdx;
  String? _preloadedNextPageContent;

  /// 每次预加载完成时递增，供 UI 监听重建。
  final preloadGeneration = ValueNotifier<int>(0);

  /// 是否有预加载的下一章首页
  bool get hasPreloadedNextChapter =>
      _preloadedNextChapterIdx != null && _preloadedNextPageContent != null;

  /// 获取预加载的下一章指定页内容（[pageIndex] 相对下一章首页 0）
  String? getPreloadedNextChapterContent(
    int chapterIndex, {
    int pageIndex = 0,
  }) {
    if (_preloadedNextChapterIdx == chapterIndex && pageIndex == 0) {
      return _preloadedNextPageContent;
    }
    return null;
  }

  /// 预加载下一章节的首页文本，用于跨章节翻页动画。
  Future<void> preloadNextChapterFirstPage(
    String bookId,
    int chapterIndex, {
    double fontSize = 16,
    double lineHeight = 1.6,
    double width = 400,
    double height = 600,
    double padding = 20,
  }) async {
    try {
      final text = await loadChapterFirstSpine(bookId, chapterIndex);
      final pages = paginateApproximate(
        text,
        fontSize: fontSize,
        lineHeight: lineHeight,
        width: width,
        height: height,
        padding: padding,
      );
      _preloadedNextChapterIdx = chapterIndex;
      _preloadedNextPageContent = pages.isNotEmpty ? pages[0].content : text;
      preloadGeneration.value++; // 通知 UI 重建以使用新的预加载内容
    } catch (e) {
      Logging.debug('[Preload] next chapter first page failed: $e');
    }
  }

  void clearPreloadedNextChapter() {
    _preloadedNextChapterIdx = null;
    _preloadedNextPageContent = null;
  }

  ReaderRepository();

  final _richTextConverter = const RichTextConverter();

  /// 获取书籍元数据，优先返回缓存对象。
  Future<Book> _getBook(String bookId) async {
    if (_cachedBookId == bookId && _cachedBook != null) {
      return _cachedBook!;
    }
    final book = await book_api.getBook(bookId: bookId);
    if (book == null) throw Exception('Book not found: $bookId');
    _cachedBook = book;
    _cachedBookId = bookId;
    _filePath = book.filePath;
    return book;
  }

  /// 公开 getter：页面描述符列表
  List<PageDescriptor>? get descriptors => _descriptors;


  /// 轻量级分页排版（只获取页面描述符，文本按需加载）。
  ///
  /// 调用 Rust `paginate_chapter` 获取轻量级页面描述符列表，
  /// 返回页面总数，0 表示失败。
  /// 私有共享分页核心：构建 config，调用 PaginationEngine，更新状态。
  Future<PaginateResult> _paginateChapter({
    required String bookId,
    required int chapterIndex,
    required TypesetConfig config,
    BigInt? maxChars,
  }) async {
    final book = await _getBook(bookId);
    if (book.filePath.isEmpty) {
      throw Exception('_paginateChapter: book not found for bookId=$bookId');
    }
    final result = await _pagination.paginateChapter(
      filePath: book.filePath,
      chapterIndex: chapterIndex,
      config: config,
      maxChars: maxChars,
    );
    _filePath = book.filePath;
    _chapterIndex = chapterIndex;
    _descriptors = result.descriptors;
    _configHash = result.configHash;
    return result;
  }

  void _preloadPageRange(int count) {
    final total = _descriptors?.length ?? 0;
    final limit = count.clamp(0, total);
    for (int i = 0; i < limit; i++) {
      _fetchPageSync(i);
    }
  }

  /// 完整分页排版（所有字符）。
  ///
  /// 在部分分页之后调用。保留已有 pageCache，不再清空。
  /// 只对新扩展的页面进行预加载。
  Future<int> paginateChapter({
    required String bookId,
    required int chapterIndex,
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
    required double padding,
    double devicePixelRatio = 1.0,
    CalibrationData? calibration,
    String fontFamily = 'Noto Sans SC',
    double letterSpacing = 0,
    double paragraphSpacing = 16,
    bool punctuationSqueeze = true,
  }) async {
    try {
      final config = buildTypesetConfig(
        width: width,
        height: height,
        fontSize: fontSize,
        lineHeight: lineHeight,
        padding: padding,
        devicePixelRatio: devicePixelRatio,
        calibration: calibration,
        fontFamily: fontFamily,
        letterSpacing: letterSpacing,
        paragraphSpacing: paragraphSpacing,
        punctuationSqueeze: punctuationSqueeze,
      );
      final oldLength = _descriptors?.length ?? 0;
      final result = await _paginateChapter(
        bookId: bookId,
        chapterIndex: chapterIndex,
        config: config,
      );
      // 保留 partial 阶段的 pageCache 不变，只预加载新增页
      final preloadCount = 5.clamp(0, result.descriptors.length);
      for (int i = oldLength; i < preloadCount; i++) {
        _fetchPageSync(i);
      }
      return result.descriptors.length;
    } catch (e) {
      Logging.error('paginateChapter error: $e');
      return 0;
    }
  }

  /// 快速分页：只读取前 N 字符进行惰性分页（只转换必要的 spine）。
  ///
  /// 相比完整 `paginateChapter`（可能需 5s+），此方法在 ~300ms 内返回
  /// 最初的 ~100-200 页的真实描述符，让用户可以立即翻页。
  /// 返回 `(totalPages, isPartial)`，调用方根据 `isPartial` 决定是否需补全。
  Future<({int totalPages, bool isPartial})> paginateChapterPartial({
    required String bookId,
    required int chapterIndex,
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
    required double padding,
    double devicePixelRatio = 1.0,
    CalibrationData? calibration,
    String fontFamily = 'Noto Sans SC',
    double letterSpacing = 0,
    double paragraphSpacing = 16,
    bool punctuationSqueeze = true,
  }) async {
    try {
      final config = buildTypesetConfig(
        width: width,
        height: height,
        fontSize: fontSize,
        lineHeight: lineHeight,
        padding: padding,
        devicePixelRatio: devicePixelRatio,
        calibration: calibration,
        fontFamily: fontFamily,
        letterSpacing: letterSpacing,
        paragraphSpacing: paragraphSpacing,
        punctuationSqueeze: punctuationSqueeze,
      );
      final result = await _paginateChapter(
        bookId: bookId,
        chapterIndex: chapterIndex,
        config: config,
        maxChars: PaginationEngine.partialMaxChars,
      );
      _pageCache.clear();
      _preloadPageRange(5);
      return (totalPages: result.descriptors.length, isPartial: result.isPartial);
    } catch (e) {
      Logging.error('paginateChapterPartial error: $e');
      return (totalPages: 0, isPartial: false);
    }
  }

  String? getPageContent(int pageIndex) {
    if (_pageCache.containsKey(pageIndex)) {
      return _pageCache[pageIndex];
    }
    // 回退到 currentPages（Dart 估算分页的降级路径）
    if (currentPages != null && pageIndex < currentPages!.length) {
      return currentPages![pageIndex].content;
    }
    return null;
  }

  /// 同步获取单页内容并写入缓存。
  void _fetchPageSync(int pageIndex) {
    if (_pageCache.containsKey(pageIndex)) return;
    if (_filePath == null ||
        _chapterIndex == null ||
        _configHash == null ||
        _descriptors == null) {
      return;
    }
    if (pageIndex < 0 || pageIndex >= _descriptors!.length) return;

    try {
      final content = core_api.getPageContent(
        filePath: _filePath!,
        chapterIndex: _chapterIndex!,
        configHash: _configHash!,
        pageIndex: pageIndex,
      );
      if (content.isNotEmpty) {
        _pageCache[pageIndex] = content;
      }
    } catch (e) {
      Logging.error('_fetchPageSync error for page $pageIndex: $e');
    }
  }

  /// 确保指定页面及其周围页面的内容已缓存。
  ///
  /// 同步获取 `centerPage`，同时异步预加载周围 ±3 页。
  void ensurePageWindow(int centerPage) {
    if (_descriptors == null) return;

    // 同步获取当前页
    _fetchPageSync(centerPage);

    // 异步预加载周围页
    _prefetchSurrounding(centerPage);
  }

  /// 异步预加载指定页面周围的 ±3 页，并清理远离的缓存。
  void _prefetchSurrounding(int center) {
    if (_descriptors == null) return;
    final total = _descriptors!.length;
    final start = math.max(0, center - 3);
    final end = math.min(total - 1, center + 3);

    // 异步获取周围页（使用 Future.microtask 避免阻塞 UI）
    Future.microtask(() {
      for (int i = start; i <= end; i++) {
        _fetchPageSync(i);
      }
    });

    // 清理远离的缓存页（距离 >5 的页面）
    _pageCache.removeWhere((key, _) => (key - center).abs() > 5);
  }

  Future<List<Chapter>> getChapters(String bookId) async {
    return chapter_api.listChaptersByBook(bookId: bookId);
  }

  /// 快速获取章节首段文本（只读第一个 spine，不做分页）。
  ///
  /// 用于分段读取的首屏渲染，通常在 ~100ms 内完成。
  /// 返回文本通常是章节前 2000 字符，用于第 0 页的近似渲染。
  Future<String> loadChapterFirstSpine(String bookId, int chapterId) async {
    final book = await _getBook(bookId);
    if (book.filePath.isEmpty) {
      throw Exception('Book not found: $bookId');
    }
    final result = await core_api.getChapterFirstSpineOnly(
      filePath: book.filePath,
      chapterIndex: chapterId,
    );
    return result.text;
  }
  // ===== From ChapterContentService =====

  Future<String> loadChapterContent(String bookId, int chapterId,
      {ReadingMode? readingMode}) async {
    final sw = Stopwatch()..start();
    try {
      final book = await _getBook(bookId);
      if (book.filePath.isEmpty) {
        throw Exception('Book not found: $bookId');
      }

      final filePath = book.filePath;

      // 2. 并行启动：getChapter（纯文本）和 EPUB 富文本（如果适用）
      final isEpub = filePath.toLowerCase().endsWith('.epub');
      final isPaginated = readingMode == ReadingMode.pagination;

      // 同步构建 TypesetConfig（无 FFI 调用，不阻塞）
      Future<List<RichParagraph>>? epubRichFuture;
      // 仅滚动/双语模式需要 EPUB 富文本排版；分页模式下跳过以节省时间
      if (isEpub && !isPaginated) {
        final config = buildTypesetConfig(
          width: 400,
          height: 600,
          fontSize: 16,
          lineHeight: 1.6,
          padding: 20,
          devicePixelRatio: 1.0,
          fontFamily: 'Noto Sans SC',
        );
        epubRichFuture = epub_api
            .getEpubChapterRichContent(
              filePath: filePath,
              chapterIndex: chapterId,
              config: config,
            )
            .catchError((_) => <RichParagraph>[]);
      }

      // 两个 Future 同时发出 — 无顺序依赖
      final results = await Future.wait([
        core_api.getChapter(filePath: filePath, chapterIndex: chapterId),
        if (epubRichFuture != null)
          epubRichFuture
        else
          Future<Object?>.value(null),
      ]);
      var content = (results[0] as core_api.ChapterContent).when(
        raw: (text) => text,
        pages: (pages) => pages.map((p) => p.content).join('\n\n'),
      );

      // 处理 EPUB 富文本结果
      if (!isPaginated && isEpub && content.length > 500 * 1024) {
        Logging.warning(
          'loadChapterContent: content too large (${content.length} bytes), '
          'discarding rich text typesetting result',
        );
        currentRichContent = null;
        currentRichParagraphs = null;
      } else if (epubRichFuture != null && results[1] is List<RichParagraph>) {
        try {
          final paragraphs = results[1] as List<RichParagraph>;
          if (paragraphs.isNotEmpty) {
            final result = _richTextConverter.toTextSpan(paragraphs);
            content = result.$2;
            currentRichContent = result.$1;
            currentRichParagraphs = paragraphs;
          }
        } catch (e) {
          Logging.error('loadChapterContent EPUB rich typeset failed: $e');
        }
      }

      // 3. 对 MD 额外获取富文本排版内容（需等待 content 就绪，保持顺序）
      final isMd = filePath.toLowerCase().endsWith('.md');
      if (isMd) {
        try {
          final paragraphs = await md_api.getMdChapterRichContent(
            filePath: filePath,
            chapterIndex: chapterId,
          );
          if (paragraphs.isNotEmpty) {
            final result = _richTextConverter.toTextSpan(paragraphs);
            content = result.$2;
            currentRichContent = result.$1;
            currentRichParagraphs = paragraphs;
          }
        } catch (e) {
          Logging.error('loadChapterContent MD rich typeset failed: $e');
        }
      }

      if (content.isEmpty) {
        throw Exception('Chapter content is empty');
      }

      final tTotal = sw.elapsedMilliseconds;
      Logging.info(
        '[Timing] loadChapterContent total: ${tTotal}ms '
        '(EPUB=$isEpub MD=$isMd)',
      );

      return content;
    } catch (e) {
      Logging.error('loadChapterContent error: $e');
      throw Exception('Failed to load chapter content: $e');
    }
  }

  Future<List<PageInfo>> calculatePages({
    required String bookId,
    required int chapterId,
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
    required double padding,
  }) async {
    // 统一走字符估算分页：毫秒级完成，SelectableText 渲染时自行精确换行
    final content = await loadChapterContent(bookId, chapterId);
    final pages = _paginateApproximate(
      content,
      fontSize: fontSize,
      lineHeight: lineHeight,
      width: width,
      height: height,
      padding: padding,
    );
    currentPages = pages;
    return pages;
  }

  /// 字符估算分页（无需 TextPainter，毫秒级）
  List<PageInfo> _paginateApproximate(
    String content, {
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
    required double padding,
  }) {
    return PaginationEngine.paginateApproximate(
      content,
      fontSize: fontSize,
      lineHeight: lineHeight,
      width: width,
      height: height,
      padding: padding,
    );
  }

  /// 预加载章节内容（静默失败）
  Future<void> preloadChapter(String bookId, int chapterId) async {
    try {
      await loadChapterContent(bookId, chapterId);
    } catch (e) {
      Logging.error('章节预加载失败', exception: e);
    }
  }

  Future<ReadingProgressData?> loadReadingProgress(String bookId) async {
    if (_currentProgress != null && _currentProgress!.bookId == bookId) {
      return _currentProgress;
    }
    final rp = await progress_api.getProgress(bookId: bookId);
    if (rp == null) return null;
    _currentProgress = ReadingProgressData(
      bookId: bookId,
      chapterIndex: rp.chapterIndex,
      charOffset: rp.charOffset.toInt(),
      pageIndex: rp.pageIndex,
      totalPages: rp.totalPages,
      readingTimeSeconds: rp.readingTimeSeconds.toInt(),
      lastReadAt: rp.lastReadAt,
    );
    return _currentProgress;
  }

  /// 对任意文本做近似分页（用于首屏快速估算）。
  List<PageInfo> paginateApproximate(
    String content, {
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
    required double padding,
  }) {
    return _paginateApproximate(
      content,
      fontSize: fontSize,
      lineHeight: lineHeight,
      width: width,
      height: height,
      padding: padding,
    );
  }

  /// 手动预热单个页面缓存（用于分段读取首屏）。
  void warmPageCache(int pageIndex, String content) {
    _pageCache[pageIndex] = content;
  }
}

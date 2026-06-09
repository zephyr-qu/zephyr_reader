/// 阅读器数据仓库，封装 Rust FFI 调用。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/chapter.dart' as chapter_api;
import 'package:zephyr_reader/src/rust/api/data/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/api/epub.dart' as epub_api;
import 'package:zephyr_reader/src/rust/api/md.dart' as md_api;
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 分页信息
class PageInfo {
  final int pageIndex;
  final String content;
  final int startOffset;
  final int endOffset;
  PageInfo({
    required this.pageIndex,
    required this.content,
    required this.startOffset,
    required this.endOffset,
  });
}

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

  ReaderRepository();

  /// 公开 getter：页面描述符列表
  List<PageDescriptor>? get descriptors => _descriptors;

  /// 带 KV 缓存的分页排版
  ///
  /// 返回 (pages, cacheHit, isFallback)。
  /// isFallback 时 pages 为空，调用方应回退到 _paginateApproximate。
  Future<({List<PageInfo> pages, bool cacheHit, bool isFallback})>
  getPaginatedChapterPages({
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
      final book = await book_api.getBook(bookId: bookId);
      if (book == null || book.filePath.isEmpty) {
        Logging.error(
          'getPaginatedChapterPages: book not found for bookId=$bookId',
        );
        return (pages: <PageInfo>[], cacheHit: false, isFallback: true);
      }

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

      final pageContents = await core_api.paginateAllContent(
        filePath: book.filePath,
        chapterIndex: chapterIndex,
        config: config,
      );

      final pages = pageContents
          .map(
            (pc) => PageInfo(
              pageIndex: pc.pageIndex,
              content: pc.content,
              startOffset: pc.startOffset.toInt(),
              endOffset: pc.endOffset.toInt(),
            ),
          )
          .toList();

      currentPages = pages;
      return (pages: pages, cacheHit: false, isFallback: false);
    } catch (e) {
      Logging.error('getPaginatedChapterPages error: $e');
      return (pages: <PageInfo>[], cacheHit: false, isFallback: true);
    }
  }

  /// 轻量级分页排版（只获取页面描述符，文本按需加载）。
  ///
  /// 调用 Rust `paginate_chapter` 获取轻量级页面描述符列表，
  /// 预加载前 5 页内容到 `_pageCache`。
  /// 返回页面总数，0 表示失败。
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
    final sw = Stopwatch()..start();
    try {
      final book = await book_api.getBook(bookId: bookId);
      if (book == null || book.filePath.isEmpty) {
        Logging.error('paginateChapter: book not found for bookId=$bookId');
        return 0;
      }
      final tGetBook = sw.elapsedMilliseconds;

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
      final tBuildConfig = sw.elapsedMilliseconds;

      final result = await core_api.paginateChapter(
        filePath: book.filePath,
        chapterIndex: chapterIndex,
        config: config,
      );
      final tRustPaginate = sw.elapsedMilliseconds;
      Logging.info(
        '[Timing] paginateChapter: getBook=${tGetBook}ms '
        'buildConfig=${tBuildConfig - tGetBook}ms '
        'rustPaginate=${tRustPaginate - tBuildConfig}ms',
      );

      _filePath = book.filePath;
      _chapterIndex = chapterIndex;
      _descriptors = result.descriptors;
      _configHash = result.configHash;
      _pageCache.clear();

      // 预加载前 5 页到缓存
      final preloadCount = 5.clamp(0, result.descriptors.length);
      for (int i = 0; i < preloadCount; i++) {
        _fetchPageSync(i);
      }
      final tPreload = sw.elapsedMilliseconds;
      if (tPreload - tRustPaginate > 10) {
        Logging.info(
          '[Timing] paginateChapter: preloadFirst5Pages=${tPreload - tRustPaginate}ms',
        );
      }

      return result.descriptors.length;
    } catch (e) {
      Logging.error('paginateChapter error: $e');
      return 0;
    }
  }

  /// 获取页面内容（优先从缓存查找）。
  /// 返回 `null` 表示内容尚未缓存，渲染器应显示占位符。
  String? getPageContent(int pageIndex) {
    return _pageCache[pageIndex];
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
  // ===== From ChapterContentService =====

  Future<String> loadChapterContent(String bookId, int chapterId) async {
    final sw = Stopwatch()..start();
    try {
      final book = await book_api.getBook(bookId: bookId);
      if (book == null || book.filePath.isEmpty) {
        throw Exception('Book not found: $bookId');
      }
      final tGetBook = sw.elapsedMilliseconds;

      final filePath = book.filePath;

      // 1. 通过 Rust core API 获取章节内容（统一处理 EPUB/TXT/MD）
      final chapterContent = await core_api.getChapter(
        filePath: filePath,
        chapterIndex: chapterId,
      );
      final tGetChapter = sw.elapsedMilliseconds;
      Logging.info(
        '[Timing] loadChapterContent: getBook=${tGetBook}ms '
        'getChapter=${tGetChapter - tGetBook}ms',
      );

      var content = chapterContent.when(
        raw: (text) => text,
        pages: (pages) => pages.map((p) => p.content).join('\n\n'),
      );

      // 2. 对 EPUB 额外获取富文本排版内容
      final isEpub = filePath.toLowerCase().endsWith('.epub');
      if (isEpub) {
        try {
          final config = buildTypesetConfig(
            width: 400,
            height: 600,
            fontSize: 16,
            lineHeight: 1.6,
            padding: 20,
            devicePixelRatio: 1.0,
            fontFamily: 'Noto Sans SC',
          );
          final paragraphs = await epub_api.getEpubChapterRichContent(
            filePath: filePath,
            chapterIndex: chapterId,
            config: config,
          );
          if (paragraphs.isNotEmpty) {
            final result = _richParagraphsToRichText(paragraphs);
            content = result.$2;
            currentRichContent = result.$1;
            currentRichParagraphs = paragraphs;
          }
        } catch (e) {
          Logging.error('loadChapterContent EPUB rich typeset failed: $e');
        }
      }
      // 3. 对 MD 额外获取富文本排版内容
      final isMd = filePath.toLowerCase().endsWith('.md');
      if (isMd) {
        try {
          final paragraphs = await md_api.getMdChapterRichContent(
            filePath: filePath,
            chapterIndex: chapterId,
          );
          if (paragraphs.isNotEmpty) {
            final result = _richParagraphsToRichText(paragraphs);
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

  TextStyle _spanToStyle(RichTextSpan span) {
    final base = span.when(
      plain: (text, fontSize, color) => const TextStyle(),
      bold: (text, fontSize, color) =>
          const TextStyle(fontWeight: FontWeight.bold),
      italic: (text, fontSize, color) =>
          const TextStyle(fontStyle: FontStyle.italic),
      boldItalic: (text, fontSize, color) => const TextStyle(
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      ),
      underline: (text, fontSize, color) =>
          const TextStyle(decoration: TextDecoration.underline),
      strikethrough: (text, fontSize, color) =>
          const TextStyle(decoration: TextDecoration.lineThrough),
      code: (text, fontSize, color) => const TextStyle(fontFamily: 'monospace'),
      link: (text, url, fontSize, color) =>
          const TextStyle(decoration: TextDecoration.underline),
    );
    if (span.fontSize == null && span.color == null) return base;
    return base.copyWith(
      fontSize: span.fontSize,
      color: span.color != null ? _parseCssColor(span.color!) : null,
    );
  }

  Color? _parseCssColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      if (h.length == 6) {
        final r = int.parse(h.substring(0, 2), radix: 16);
        final g = int.parse(h.substring(2, 4), radix: 16);
        final b = int.parse(h.substring(4, 6), radix: 16);
        return Color.fromARGB(255, r, g, b);
      }
      if (h.length == 3) {
        final r = int.parse(h[0] * 2, radix: 16);
        final g = int.parse(h[1] * 2, radix: 16);
        final b = int.parse(h[2] * 2, radix: 16);
        return Color.fromARGB(255, r, g, b);
      }
    } catch (e) {
      Logging.error('解析颜色失败', exception: e);
    }
    return null;
  }

  /// 生成段落级样式（CSS block 属性 + 标题回退）
  TextStyle _paragraphBlockStyle(
    RichParagraph p, {
    required double baseFontSize,
    required double baseLineHeight,
  }) {
    TextStyle style = TextStyle(fontSize: baseFontSize, height: baseLineHeight);
    if (p.lineHeight != null) {
      style = style.copyWith(height: p.lineHeight);
    }
    if (p.isHeading && p.headingLevel > 0) {
      final headingFs = switch (p.headingLevel) {
        1 => 24.0,
        2 => 20.0,
        3 => 18.0,
        4 => 16.0,
        _ => 14.0,
      };
      if (style.fontSize == null || style.fontSize == baseFontSize) {
        style = style.copyWith(fontSize: headingFs);
      }
      style = style.copyWith(fontWeight: FontWeight.bold);
    }
    return style;
  }

  /// 将 RichParagraph 列表转换为 TextSpan 树（保留样式），同时返回纯文本
  (TextSpan, String) _richParagraphsToRichText(
    List<RichParagraph> paragraphs, {
    double baseFontSize = 16,
    double baseLineHeight = 1.6,
  }) {
    final children = <InlineSpan>[];
    final plainParts = <String>[];
    for (int i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      if (p.isImage) continue;

      final paraText = p.spans.map((s) => s.text).join();
      if (paraText.isEmpty) continue;

      final blockStyle = _paragraphBlockStyle(
        p,
        baseFontSize: baseFontSize,
        baseLineHeight: baseLineHeight,
      );
      final spanChildren = p.spans
          .map((s) => TextSpan(text: s.text, style: _spanToStyle(s)))
          .toList();

      if (blockStyle != const TextStyle()) {
        children.add(TextSpan(style: blockStyle, children: spanChildren));
      } else {
        children.addAll(spanChildren);
      }
      plainParts.add(paraText);

      if (i < paragraphs.length - 1) {
        children.add(const TextSpan(text: '\n\n'));
      }
    }
    final plain = plainParts.where((t) => t.isNotEmpty).join('\n\n');
    return (TextSpan(children: children), plain);
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
    final maxWidth = width - padding * 2;
    final availableHeight = height - padding * 2;
    final charsPerLine = (maxWidth / fontSize).floor().clamp(10, 200);
    final linesPerPage = (availableHeight / (fontSize * lineHeight))
        .floor()
        .clamp(1, 100);
    final charsPerPage = charsPerLine * linesPerPage;

    final pages = <PageInfo>[];
    var offset = 0;
    var pageIndex = 0;

    while (offset < content.length) {
      var end = offset + charsPerPage;
      if (end >= content.length) {
        end = content.length;
      } else {
        // 在段落边界处断开，避免断词
        final searchStart = (end - (charsPerLine ~/ 2)).clamp(
          0,
          content.length,
        );
        final newlinePos = content.lastIndexOf('\n', end);
        if (newlinePos > searchStart) {
          end = newlinePos + 1;
        } else {
          final paraBreak = content.lastIndexOf('\n\n', end);
          if (paraBreak > searchStart) {
            end = paraBreak + 2;
          }
        }
      }

      pages.add(
        PageInfo(
          pageIndex: pageIndex,
          content: content.substring(offset, end),
          startOffset: offset,
          endOffset: end,
        ),
      );
      offset = end;
      pageIndex++;
    }

    if (pages.isEmpty) {
      pages.add(
        PageInfo(
          pageIndex: 0,
          content: content,
          startOffset: 0,
          endOffset: content.length,
        ),
      );
    }
    return pages;
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
}

/// 阅读器仓库

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/bookmark.dart' as bookmark_api;
import 'package:zephyr_reader/src/rust/api/data/chapter.dart' as chapter_api;
import 'package:zephyr_reader/src/rust/api/data/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/api/epub.dart' as epub;
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 分页信息
class PageInfo {
  final int pageIndex;
  final String content;
  final TextSpan? richContent;
  final int startOffset;
  final int endOffset;
  PageInfo({
    required this.pageIndex,
    required this.content,
    this.richContent,
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
  double get progressPercent =>
      totalPages > 0 ? (pageIndex + 1) / totalPages : 0.0;
}

@Injectable()
class ReaderRepository {
  ReadingProgressData? _currentProgress;

  /// 当前章节的分页结果
  List<PageInfo>? currentPages;

  /// 当前章节的富文本内容（EPUB）
  TextSpan? currentRichContent;
  List<RichParagraph>? currentRichParagraphs;

  ReaderRepository();

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
              richContent: null,
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


  Future<Chapter?> getChapter(String bookId, int chapterIndex) async {
    try {
      return await chapter_api.getChapterByIndex(
        bookId: bookId,
        chapterIndex: chapterIndex,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Chapter>> getChapters(String bookId) async {
    return chapter_api.listChaptersByBook(bookId: bookId);
  }

  Future<Bookmark> addBookmark(
    String bookId,
    int chapterIndex,
    int position,
  ) async {
    return bookmark_api.createBookmark(
      bookId: bookId,
      chapterIndex: chapterIndex,
      charOffset: position,
      title: '书签',
    );
  }

  Future<List<Bookmark>> getBookmarks(String bookId) async {
    return bookmark_api.listBookmarksByBook(bookId: bookId);
  }

  Future<bool> deleteBookmark(String bookmarkId) async {
    try {
      await bookmark_api.deleteBookmark(bookmarkId: bookmarkId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ===== From ChapterContentService =====

  Future<String> loadChapterContent(String bookId, int chapterId) async {

    try {
      final book = await book_api.getBook(bookId: bookId);
      if (book == null || book.filePath.isEmpty) {
        throw Exception('Book not found: $bookId');
      }

      final filePath = book.filePath;

      // 1. 通过 Rust core API 获取章节内容（统一处理 EPUB/TXT/MD）
      final chapterContent = await core_api.getChapter(
        filePath: filePath,
        chapterIndex: chapterId,
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
          final paragraphs = await epub.getEpubChapterRichContent(
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

      if (content.isEmpty) {
        throw Exception('Chapter content is empty');
      }

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
      link: (text, url, fontSize, color) => const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
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
          richContent: null,
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
          richContent: null,
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

  // ===== From ReadingProgressService =====

  Future<void> updateReadingProgress({
    required String bookId,
    required int chapterId,
    required int charOffset,
    required int pageIndex,
    required int totalPages,
    int readingTimeSeconds = 0,
  }) async {
    final now = DateTime.now();
    final pct = totalPages > 0
        ? ((pageIndex + 1) / totalPages).clamp(0.0, 1.0)
        : 0.0;
    await progress_api.upsertProgress(
      progress: ReadingProgress(
        bookId: bookId,
        chapterIndex: chapterId,
        chunkIndex: 0,
        charOffset: charOffset,
        pageIndex: pageIndex,
        totalPages: totalPages,
        progress: pct,
        readingTimeSeconds: readingTimeSeconds,
        lastReadAt: now,
        isCompleted: pct >= 1.0,
      ),
    );
    _currentProgress = ReadingProgressData(
      bookId: bookId,
      chapterIndex: chapterId,
      charOffset: charOffset,
      pageIndex: pageIndex,
      totalPages: totalPages,
      readingTimeSeconds: readingTimeSeconds,
      lastReadAt: now,
    );
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

  ReadingProgressData? get currentProgress => _currentProgress;

  Future<void> clearReadingProgress(String bookId) async {
    await progress_api.clearProgress(bookId: bookId);
    if (_currentProgress?.bookId == bookId) _currentProgress = null;
  }


  void clearProgressCache() => _currentProgress = null;
}

/// 阅读器仓库
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_core_service.dart';
import 'package:zephyr_reader/core/local/rust_epub_service.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/src/rust/domain/types.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 分页信息
class PageInfo {
  final int pageIndex;
  final String content;
  final TextSpan? richContent;
  final int startOffset;
  final int endOffset;
  PageInfo({required this.pageIndex, required this.content, this.richContent, required this.startOffset, required this.endOffset});
}

/// 章节内容缓存项
class ChapterCacheItem {
  final String content;
  final List<PageInfo> pages;
  final DateTime loadedAt;
  ChapterCacheItem({required this.content, required this.pages, required this.loadedAt});
}

/// 阅读进度数据
class ReadingProgressData {
  final String bookId;
  final int chapterIndex;
  final int pageIndex;
  final int totalPages;
  final int readingTimeSeconds;
  final DateTime lastReadAt;
  ReadingProgressData({required this.bookId, required this.chapterIndex, required this.pageIndex, required this.totalPages, required this.readingTimeSeconds, required this.lastReadAt});
  double get progressPercent => totalPages > 0 ? (pageIndex + 1) / totalPages : 0.0;
  String get progressText => '${(progressPercent * 100).toStringAsFixed(1)}%';
}

@Injectable()
class ReaderRepository {
  final RustStorageService _storage;
  final RustEpubService _epubService;
  final RustCoreService _coreService;
  final Map<String, Map<int, ChapterCacheItem>> _cache = {};
  final Map<String, Map<int, TextSpan>> _richContentCache = {};
  final Map<String, Map<int, List<RichParagraph>>> _richParagraphCache = {};
  static const int maxCacheSize = 10;
  ReadingProgressData? _currentProgress;

  ReaderRepository(this._storage, this._epubService, this._coreService);

  Future<EpubMetadata?> getEpubMetadata(String filePath) async {
    try {
      return await _epubService.getEpubMetadata(filePath);
    } catch (_) {
      return null;
    }
  }

  
  Future<Chapter?> getChapter(int bookId, int chapterIndex) async {
    final chapters = await _storage.getChaptersByBook('book_$bookId');
    try {
      return chapters.firstWhere((c) => c.chapterIndex == chapterIndex);
    } catch (_) {
      return null;
    }
  }

  Future<List<Chapter>> getChapters(int bookId) async {
    return _storage.getChaptersByBook('book_$bookId');
  }

  Future<void> saveReadingHistory(
    String bookId,
    int chapterId,
    int position,
    int duration,
  ) async {
    final now = DateTime.now();
    await _storage.recordReadingSession(ReadingSession(
      id: 'session_${now.millisecondsSinceEpoch}',
      bookId: bookId,
      chapterIndex: chapterId,
      startCharOffset: 0,
      endCharOffset: position,
      startedAt: now,
      endedAt: now,
      durationSeconds: duration,
    ));
  }

  Future<GlobalStats?> getReadingHistory(int bookId) async {
    return _storage.getGlobalReadingStats();
  }

  Future<int> addBookmark(
    String bookId,
    int chapterId,
    int position,
  ) async {
    final bookmark = Bookmark(
      id: 'bm_${DateTime.now().millisecondsSinceEpoch}',
      bookId: bookId,
      chapterIndex: chapterId,
      charOffset: position,
      title: '书签',
      createdAt: DateTime.now(),
    );
    await _storage.createBookmark(bookmark);
    return bookmark.id.hashCode;
  }

  Future<List<Bookmark>> getBookmarks(String bookId) async {
    return _storage.getBookmarks(bookId);
  }

  Future<bool> deleteBookmark(String bookmarkId) async {
    try {
      await _storage.deleteBookmark(bookmarkId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getChapterContent(String contentFile) async {
    final file = File(contentFile);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  // ===== From ChapterContentService =====

  Future<String> loadChapterContent(String bookId, int chapterId, {String? contentFilePath}) async {
    debugPrint('loadChapterContent >>> bookId=$bookId chapterId=$chapterId contentFilePath=$contentFilePath');
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.containsKey(chapterId)) {
      final cached = _cache[cacheKey]![chapterId]!;
      debugPrint('loadChapterContent <<< cache hit, content len=${cached.content.length}');
      return cached.content;
    }
    try {
      String content = '';
      String? source;

      if (contentFilePath != null && contentFilePath.isNotEmpty) {
        final file = File(contentFilePath);
        if (await file.exists()) {
          content = await file.readAsString();
          source = contentFilePath;
          debugPrint('loadChapterContent 从 contentFilePath 读取: path=$contentFilePath len=${content.length}');
        } else {
          debugPrint('loadChapterContent contentFilePath 不存在: $contentFilePath');
        }
      }

      if (content.isEmpty) {
        final chapters = await _storage.getChaptersByBook(bookId);
        debugPrint('loadChapterContent 查询 chapters 表: bookId=$bookId 总数=${chapters.length}');
        for (int i = 0; i < chapters.length && i < 10; i++) {
          debugPrint('loadChapterContent   chapter[$i]: idx=${chapters[i].chapterIndex} title="${chapters[i].title}"');
        }
        var ch = chapters.where((c) => c.chapterIndex == chapterId).firstOrNull;
        if (ch == null && chapters.isNotEmpty) {
          debugPrint('loadChapterContent chapterId=$chapterId 未找到，使用 chapters[0] (idx=${chapters.first.chapterIndex})');
          ch = chapters.first;
        }
        if (ch != null) {
          chapterId = ch.chapterIndex;
          debugPrint('loadChapterContent 找到章节: chapterIndex=$chapterId contentFile=${ch.contentFile} startIndex=${ch.startIndex} endIndex=${ch.endIndex}');
          if (ch.contentFile.isNotEmpty) {
            final isEpub = ch.contentFile.toLowerCase().endsWith('.epub');
            if (isEpub) {
              try {
                try {
                  final meta = await _epubService.getEpubMetadata(ch.contentFile);
                  debugPrint('loadChapterContent EPUB 诊断: spine=${meta.spine.length} items');
                  for (int i = 0; i < meta.spine.length && i < 15; i++) {
                    debugPrint('loadChapterContent EPUB 诊断:   spine[$i]=${meta.spine[i]}');
                  }
                  debugPrint('loadChapterContent EPUB 诊断: toc=${meta.toc.length} items');
                  for (final item in meta.toc) {
                    debugPrint('loadChapterContent EPUB 诊断:   toc label="${item.label}" href="${item.href}" level=${item.level}');
                  }
                } catch (e) {
                  debugPrint('loadChapterContent EPUB 诊断 获取 metadata 失败: $e');
                }
                // 对比: 通用路径能否读到内容
                try {
                  final raw = await _coreService.getChapter(ch.contentFile, chapterId);
                  debugPrint('loadChapterContent EPUB 诊断 coreService.getChapter: type=${raw.runtimeType}');
                } catch (e) {
                  debugPrint('loadChapterContent EPUB 诊断 coreService.getChapter 失败: $e');
                }
                const config = TypesetConfig(
                  pageWidth: 400,
                  pageHeight: 600,
                  fontSize: 16,
                  lineSpacing: 1.6,
                  letterSpacing: 0,
                  paragraphSpacing: 16,
                  firstLineIndent: 2,
                  language: LanguageType.chinese,
                  enableHyphenation: false,
                );
                final paragraphs = await _epubService.getEpubChapterRichContent(
                  filePath: ch.contentFile,
                  chapterIndex: chapterId,
                  config: config,
                );
                debugPrint('loadChapterContent EPUB getEpubChapterRichContent: paragraphs=${paragraphs.length}');
                if (paragraphs.isNotEmpty) {
                  final firstParaSpans = paragraphs.first.spans;
                  debugPrint('loadChapterContent first para: spans=${firstParaSpans.length} indent=${paragraphs.first.indent} isHeading=${paragraphs.first.isHeading}');
                  if (firstParaSpans.isNotEmpty) {
                    debugPrint('loadChapterContent first span text="${firstParaSpans.first.text.substring(0, (firstParaSpans.first.text.length).clamp(0, 80))}"');
                  }
                }
                final (richSpan, plainText) = _richParagraphsToRichText(paragraphs);
                content = plainText;
                _richContentCache[cacheKey] ??= {};
                _richContentCache[cacheKey]![chapterId] = richSpan;
                _richParagraphCache[cacheKey] ??= {};
                _richParagraphCache[cacheKey]![chapterId] = paragraphs;
                source = 'RichEpubAPI(${ch.contentFile})';
                debugPrint('loadChapterContent EPUB rich typeset 成功: len=${content.length}');
              } catch (e) {
                debugPrint('loadChapterContent EPUB rich typeset 失败: $e');
              }
            }
            if (content.isEmpty && !isEpub) {
              final file = File(ch.contentFile);
              if (await file.exists()) {
                if (ch.endIndex > ch.startIndex) {
                  final raf = await file.open(mode: FileMode.read);
                  await raf.setPosition(ch.startIndex);
                  final bytes = await raf.read(ch.endIndex - ch.startIndex);
                  await raf.close();
                  content = utf8.decode(bytes, allowMalformed: true);
                  source = '${ch.contentFile}[${ch.startIndex}-${ch.endIndex}]';
                  debugPrint('loadChapterContent 按字节范围读取: $source len=${content.length}');
                } else {
                  content = await file.readAsString();
                  source = ch.contentFile;
                  debugPrint('loadChapterContent 读取完整文件: ${ch.contentFile} len=${content.length}');
                }
              } else {
                debugPrint('loadChapterContent contentFile 不存在: ${ch.contentFile}');
              }
            }
          }
        } else {
          debugPrint('loadChapterContent 未找到 chapterId=$chapterId 对应的章节');
        }
      }

      if (content.isEmpty) {
        debugPrint('loadChapterContent <<< 章节内容为空, 抛出异常');
        throw Exception('章节内容为空');
      }
      _updateCache(cacheKey, chapterId, content, []);
      debugPrint('loadChapterContent <<< 成功, source=$source len=${content.length}');
      return content;
    } catch (e) {
      debugPrint('loadChapterContent <<< 异常: $e');
      throw Exception('加载章节内容失败：$e');
    }
  }

  TextStyle _spanToStyle(RichTextSpan span) {
    final base = span.when(
      plain: (text, fontSize, color) => const TextStyle(),
      bold: (text, fontSize, color) => const TextStyle(fontWeight: FontWeight.bold),
      italic: (text, fontSize, color) => const TextStyle(fontStyle: FontStyle.italic),
      boldItalic: (text, fontSize, color) =>
          const TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
      underline: (text, fontSize, color) =>
          const TextStyle(decoration: TextDecoration.underline),
      strikethrough: (text, fontSize, color) =>
          const TextStyle(decoration: TextDecoration.lineThrough),
      code: (text, fontSize, color) => const TextStyle(fontFamily: 'monospace'),
      link: (text, url, fontSize, color) =>
          const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
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
    } catch (_) {}
    return null;
  }

  /// 生成段落级样式（CSS block 属性 + 标题回退）
  TextStyle _paragraphBlockStyle(RichParagraph p, {required double baseFontSize, required double baseLineHeight}) {
    TextStyle style = TextStyle(fontSize: baseFontSize, height: baseLineHeight);
    if (p.lineHeight != null) {
      style = style.copyWith(height: p.lineHeight);
    }
    if (p.isHeading && p.headingLevel > 0) {
      final headingFs = switch (p.headingLevel) { 1 => 24.0, 2 => 20.0, 3 => 18.0, 4 => 16.0, _ => 14.0 };
      if (style.fontSize == null || style.fontSize == baseFontSize) {
        style = style.copyWith(fontSize: headingFs);
      }
      style = style.copyWith(fontWeight: FontWeight.bold);
    }
    return style;
  }

  /// 将 RichParagraph 列表转换为 TextSpan 树（保留样式），同时返回纯文本
  (TextSpan, String) _richParagraphsToRichText(List<RichParagraph> paragraphs,
      {double baseFontSize = 16, double baseLineHeight = 1.6}) {
    final children = <InlineSpan>[];
    final plainParts = <String>[];
    for (int i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      if (p.isImage) continue;

      final paraText = p.spans.map((s) => s.text).join();
      if (paraText.isEmpty) continue;

      final blockStyle = _paragraphBlockStyle(p, baseFontSize: baseFontSize, baseLineHeight: baseLineHeight);
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
    required String bookId, required int chapterId,
    required double fontSize, required double lineHeight,
    required double width, required double height, required double padding,
  }) async {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.containsKey(chapterId)) {
      final cached = _cache[cacheKey]![chapterId]!;
      if (cached.pages.isNotEmpty) return cached.pages;
    }
    final content = await loadChapterContent(bookId, chapterId);

    // 统一走字符估算分页：毫秒级完成，SelectableText 渲染时自行精确换行
    final pages = _paginateApproximate(
      content,
      fontSize: fontSize,
      lineHeight: lineHeight,
      width: width,
      height: height,
      padding: padding,
    );

    if (pages.isNotEmpty) _updateCache(cacheKey, chapterId, content, pages);
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
    final linesPerPage = (availableHeight / (fontSize * lineHeight)).floor().clamp(1, 100);
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
        final searchStart = (end - (charsPerLine ~/ 2)).clamp(0, content.length);
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

      pages.add(PageInfo(
        pageIndex: pageIndex,
        content: content.substring(offset, end),
        richContent: null,
        startOffset: offset,
        endOffset: end,
      ));
      offset = end;
      pageIndex++;
    }

    if (pages.isEmpty) {
      pages.add(PageInfo(
        pageIndex: 0,
        content: content,
        richContent: null,
        startOffset: 0,
        endOffset: content.length,
      ));
    }
    return pages;
  }

  void _updateCache(String cacheKey, int chapterId, String content, List<PageInfo> pages) {
    if (_cache.length >= maxCacheSize) _clearOldestCache();
    if (!_cache.containsKey(cacheKey)) _cache[cacheKey] = {};
    _cache[cacheKey]![chapterId] = ChapterCacheItem(content: content, pages: pages, loadedAt: DateTime.now());
  }

  void _clearOldestCache() {
    if (_cache.isEmpty) return;
    String? oldestKey;
    DateTime? oldestTime;
    for (final entry in _cache.entries) {
      for (final chapterEntry in entry.value.entries) {
        if (oldestTime == null || chapterEntry.value.loadedAt.isBefore(oldestTime)) {
          oldestTime = chapterEntry.value.loadedAt;
          oldestKey = entry.key;
        }
      }
    }
    if (oldestKey != null) _cache.remove(oldestKey);
  }

  /// 预加载章节内容到缓存（静默失败，不抛异常）
  Future<void> preloadChapter(String bookId, int chapterId) async {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.containsKey(chapterId)) {
      return;
    }
    try {
      await loadChapterContent(bookId, chapterId);
    } catch (_) {
      // 预加载失败静默忽略
    }
  }

  void clearBookCache(int bookId) {
    final key = bookId.toString();
    _cache.remove(key);
    _richContentCache.remove(key);
    _richParagraphCache.remove(key);
  }
  void clearAllCache() {
    _cache.clear();
    _richContentCache.clear();
    _richParagraphCache.clear();
  }

  String? getCachedContent(int bookId, int chapterId) {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.content;
    }
    return null;
  }

  TextSpan? getCachedRichTextSpan(String bookId, int chapterId) {
    return _richContentCache[bookId]?[chapterId];
  }

  List<RichParagraph>? getCachedRichParagraphs(String bookId, int chapterId) {
    return _richParagraphCache[bookId]?[chapterId];
  }

  List<PageInfo>? getCachedPages(String bookId, int chapterId) {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.pages;
    }
    return null;
  }

  /// 章节级 GC：只保留当前章节前后 N 章的缓存
  void gcChapterCache(String bookId, int currentChapter, {int keepRange = 5}) {
    final key = bookId.toString();
    final minKeep = currentChapter - keepRange;
    final maxKeep = currentChapter + keepRange;

    void clean(Map map) {
      final bookCache = map[key];
      if (bookCache == null) return;
      bookCache.removeWhere((k, _) {
        final ci = k as int;
        return ci < minKeep || ci > maxKeep;
      });
    }

    clean(_cache);
    clean(_richContentCache);
    clean(_richParagraphCache);
  }

  String? getPageContent(int bookId, int chapterId, int pageIndex) {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.containsKey(chapterId)) {
      final pages = _cache[cacheKey]![chapterId]!.pages;
      if (pageIndex >= 0 && pageIndex < pages.length) return pages[pageIndex].content;
    }
    return null;
  }

  // ===== From ReadingProgressService =====

  Future<void> updateReadingProgress({
    required String bookId, required int chapterId,
    required int pageIndex, required int totalPages,
    int readingTimeSeconds = 0,
  }) async {
    final now = DateTime.now();
    final progress = (pageIndex + 1) / (totalPages > 0 ? totalPages : 1);
    await _storage.saveReadingProgress(ReadingProgress(
      bookId: bookId, chapterIndex: chapterId,
      charOffset: 0, progress: progress.clamp(0.0, 1.0),
      readingTimeSeconds: readingTimeSeconds, lastReadAt: now,
      isCompleted: progress >= 1.0,
    ));
    _currentProgress = ReadingProgressData(bookId: bookId, chapterIndex: chapterId, pageIndex: pageIndex, totalPages: totalPages, readingTimeSeconds: readingTimeSeconds, lastReadAt: now);
  }

  Future<ReadingProgressData?> loadReadingProgress(String bookId) async {
    if (_currentProgress != null && _currentProgress!.bookId == bookId) return _currentProgress;
    final progress = await _storage.getReadingProgress(bookId);
    if (progress == null) return null;
    _currentProgress = ReadingProgressData(bookId: bookId, chapterIndex: progress.chapterIndex, pageIndex: 0, totalPages: 0, readingTimeSeconds: progress.readingTimeSeconds.toInt(), lastReadAt: progress.lastReadAt);
    return _currentProgress;
  }

  ReadingProgressData? get currentProgress => _currentProgress;

  Future<void> clearReadingProgress(String bookId) async {
    await _storage.clearReadingProgress(bookId);
    if (_currentProgress?.bookId == bookId) _currentProgress = null;
  }

  Future<List<ReadingProgressData>> getAllReadingProgress() async {
    final books = await _storage.getAllBooks();
    final result = <ReadingProgressData>[];
    for (final book in books) {
      final progress = await _storage.getReadingProgress(book.bookId);
      if (progress != null) {
        result.add(ReadingProgressData(bookId: book.bookId, chapterIndex: progress.chapterIndex, pageIndex: 0, totalPages: 0, readingTimeSeconds: progress.readingTimeSeconds.toInt(), lastReadAt: progress.lastReadAt));
      }
    }
    return result;
  }

  void clearProgressCache() => _currentProgress = null;
}

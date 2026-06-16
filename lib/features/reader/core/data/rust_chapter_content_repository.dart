import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/data/next_chapter_staging.dart';
import 'package:zephyr_reader/features/reader/core/domain/chapter_content_repository.dart';
import 'package:zephyr_reader/features/reader/data/rich_text_converter.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/chapter.dart' as chapter_api;
import 'package:zephyr_reader/src/rust/api/epub.dart' as epub_api;
import 'package:zephyr_reader/src/rust/api/md.dart' as md_api;
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@Injectable(as: ChapterContentRepository)
class RustChapterContentRepository implements ChapterContentRepository {
  RustChapterContentRepository();

  TextSpan? _currentRichContent;
  List<RichParagraph>? _currentRichParagraphs;

  String? _cachedBookId;
  Book? _cachedBook;

  int? _preloadedNextChapterIdx;
  String? _preloadedNextPageContent;
  NextChapterStaging? _nextChapterStaging;
  /// staging 预加载 generation 计数器，用于丢弃过期结果。
  int _stagingGen = 0;

  @override
  final preloadGeneration = ValueNotifier<int>(0);

  final _richTextConverter = const RichTextConverter();

  @override
  TextSpan? get currentRichContent => _currentRichContent;

  @override
  List<RichParagraph>? get currentRichParagraphs => _currentRichParagraphs;

  @override
  bool get hasPreloadedNextChapter =>
      _preloadedNextChapterIdx != null && _preloadedNextPageContent != null;

  Future<Book> _getBook(String bookId) async {
    if (_cachedBookId == bookId && _cachedBook != null) {
      return _cachedBook!;
    }
    final book = await book_api.getBook(bookId: bookId);
    if (book == null) throw Exception('Book not found: $bookId');
    _cachedBook = book;
    _cachedBookId = bookId;
    return book;
  }

  @override
  Future<List<Chapter>> getChapters(String bookId) async {
    return chapter_api.listChaptersByBook(bookId: bookId);
  }

  @override
  Future<String> loadFirstSpine(String bookId, int chapterId) async {
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

  @override
  Future<String> loadContent(
    String bookId,
    int chapterId, {
    ReadingMode? readingMode,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final book = await _getBook(bookId);
      if (book.filePath.isEmpty) {
        throw Exception('Book not found: $bookId');
      }

      final filePath = book.filePath;
      final isEpub = filePath.toLowerCase().endsWith('.epub');
      final isPaginated = readingMode == ReadingMode.pagination;

      Future<List<RichParagraph>>? epubRichFuture;
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

      if (!isPaginated && isEpub && content.length > 500 * 1024) {
        Logging.warning(
          'loadContent: content too large (${content.length} bytes), '
          'discarding rich text typesetting result',
        );
        _currentRichContent = null;
        _currentRichParagraphs = null;
      } else if (epubRichFuture != null && results[1] is List<RichParagraph>) {
        try {
          final paragraphs = results[1] as List<RichParagraph>;
          if (paragraphs.isNotEmpty) {
            final result = _richTextConverter.toTextSpan(paragraphs);
            content = result.$2;
            _currentRichContent = result.$1;
            _currentRichParagraphs = paragraphs;
          }
        } catch (e) {
          Logging.error('loadContent EPUB rich typeset failed: $e');
        }
      }

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
            _currentRichContent = result.$1;
            _currentRichParagraphs = paragraphs;
          }
        } catch (e) {
          Logging.error('loadContent MD rich typeset failed: $e');
        }
      }

      if (content.isEmpty) {
        throw Exception('Chapter content is empty');
      }

      final tTotal = sw.elapsedMilliseconds;
      Logging.info(
        '[Timing] loadContent total: ${tTotal}ms '
        '(EPUB=$isEpub MD=$isMd)',
      );

      return content;
    } catch (e) {
      Logging.error('loadContent error: $e');
      throw Exception('Failed to load chapter content: $e');
    }
  }

  Future<String> _loadRawContent(String bookId, int chapterId) async {
    final book = await _getBook(bookId);
    if (book.filePath.isEmpty) {
      throw Exception('Book not found: $bookId');
    }
    final result = await core_api.getChapter(
      filePath: book.filePath,
      chapterIndex: chapterId,
    );
    return result.when(
      raw: (text) => text,
      pages: (pages) => pages.map((p) => p.content).join('\n\n'),
    );
  }

  @override
  Future<void> preload(String bookId, int chapterId) async {
    try {
      await _loadRawContent(bookId, chapterId);
    } catch (e) {
      Logging.error('章节预加载失败', exception: e);
    }
  }

  @override
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
      _preloadedNextChapterIdx = chapterIndex;
      _preloadedNextPageContent = await loadFirstSpine(bookId, chapterIndex);
      preloadGeneration.value++;
    } catch (e) {
      Logging.debug('[Preload] next chapter first page failed: $e');
    }
  }

  @override
  String? getPreloadedNextChapterContent(
    int chapterIndex, {
    int pageIndex = 0,
  }) {
    if (_preloadedNextChapterIdx == chapterIndex && pageIndex == 0) {
      return _preloadedNextPageContent;
    }
    return null;
  }

  @override
  void clearPreloadedNextChapter() {
    _preloadedNextChapterIdx = null;
    _preloadedNextPageContent = null;
  }

  @override
  NextChapterStaging? get nextChapterStaging => _nextChapterStaging;

  @override
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
  }) async {
    final gen = ++_stagingGen;
    final sw = Stopwatch()..start();
    try {
      final book = await _getBook(bookId);
      if (book.filePath.isEmpty) return;

      final config = buildTypesetConfig(
        width: width,
        height: height,
        fontSize: fontSize,
        lineHeight: lineHeight,
        padding: padding,
        devicePixelRatio: devicePixelRatio,
        fontFamily: fontFamily,
      );

      final result = await core_api.paginateChapter(
        filePath: book.filePath,
        chapterIndex: chapterIndex,
        config: config,
        maxChars: BigInt.from(2000),
      );
      if (gen != _stagingGen) return;

      Logging.info(
        '[Timing] preloadNextChapterStaging: ${sw.elapsedMilliseconds}ms '
        '(chapter=$chapterIndex, isPartial=${result.isPartial}, pages=${result.descriptors.length})',
      );

      final firstContent = core_api.getPageContent(
        filePath: book.filePath,
        chapterIndex: chapterIndex,
        configHash: result.configHash,
        pageIndex: 0,
      );
      if (gen != _stagingGen) return;

      _nextChapterStaging = NextChapterStaging(
        chapterIndex: chapterIndex,
        configHash: result.configHash.toInt(),
        descriptors: result.descriptors,
        firstPageContent: firstContent,
        isPartial: result.isPartial,
      );
      preloadGeneration.value++;
      Logging.info(
        '[Timing] preloadNextChapterStaging complete: ${sw.elapsedMilliseconds}ms '
        '(staging ready for chapter=$chapterIndex)',
      );
    } catch (e) {
      if (gen == _stagingGen) _nextChapterStaging = null;
      Logging.debug('[Preload] next chapter staging failed: $e');
    }
  }

  @override
  void clearNextChapterStaging() {
    _stagingGen++;
    _nextChapterStaging = null;
  }
}

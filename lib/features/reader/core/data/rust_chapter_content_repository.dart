import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_typography_defaults.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/data/next_chapter_staging.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_payload.dart';
import 'package:zephyr_reader/features/reader/core/domain/chapter_content_repository.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/features/reader/data/rich_text_converter.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/flutter_staging_preloader.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/pagination_staging_store.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/api/types.dart' as types_api;
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/chapter.dart' as chapter_api;
import 'package:zephyr_reader/src/rust/api/epub.dart' as epub_api;
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@Injectable(as: ChapterContentRepository)
class RustChapterContentRepository implements ChapterContentRepository {
  RustChapterContentRepository(this._config);

  final ReaderConfig _config;
  PaginationParams? _layoutParams;
  bool _pendingEpubRichSkipped = false;

  TextSpan? _currentRichContent;
  List<RichParagraph>? _currentRichParagraphs;
  ChapterContentIr? _currentChapterIr;
  String? _currentChapterFilePath;

  String? _cachedBookId;
  Book? _cachedBook;

  NextChapterStaging? _nextChapterStaging;
  NextChapterStaging? _prevChapterStaging;

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
  ChapterContentIr? get currentChapterIr => _currentChapterIr;

  @override
  String? get currentChapterFilePath => _currentChapterFilePath;

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
  Future<String> loadContent(
    String bookId,
    int chapterId, {
    ReadingMode? readingMode,
  }) async {
    final payload = await _loadChapterPayload(
      bookId,
      chapterId,
      readingMode: readingMode,
    );
    _applyCurrentRich(chapterId, payload);
    _setChapterFilePath((await _getBook(bookId)).filePath);
    return payload.content;
  }

  @override
  Future<ScrollChapterPayload> loadScrollSegment(
    String bookId,
    int chapterId, {
    ReadingMode? readingMode,
  }) => _loadChapterPayload(bookId, chapterId, readingMode: readingMode);

  /// 仅双语模式需要 EPUB 富文本；scroll 走 IR；分页路径只用 plain。
  static bool _needsRichContent(ReadingMode? mode) =>
      mode == ReadingMode.bilingual;

  void _applyCurrentRich(int chapterId, ScrollChapterPayload payload) {
    _currentRichContent = payload.richRootSpan;
    _currentRichParagraphs = payload.richParagraphs;
    _currentChapterIr = payload.chapterIr;
  }

  void _setChapterFilePath(String? path) {
    _currentChapterFilePath = path;
  }

  /// scroll 模式优先走 IR（EPUB/TXT）；双语仍走 rich 路径。
  /// M2: book_id 替代 file_path（ADR-014）。
  Future<ScrollChapterPayload?> _tryLoadScrollIr({
    required String bookId,
    required int chapterId,
    required ReadingMode? readingMode,
  }) async {
    if (readingMode != ReadingMode.scroll) return null;
    final book = await _getBook(bookId);
    // Rust 侧 resolve_book_path 负责 bookId → filePath 解析；
    // filePath 在此仅用于本地 scrollIrPayload 构造，不传给 FFI
    final filePath = book.filePath;

    final sw = Stopwatch()..start();
    try {
      final ir = await core_api.getChapterContentIr(
        bookId: bookId,
        chapterIndex: chapterId,
      );
      if (ir.blocks.isEmpty || ir.plainText.isEmpty) return null;
      Logging.info(
        '[Timing] loadChapterIr: ${sw.elapsedMilliseconds}ms blocks=${ir.blocks.length}',
      );
      return scrollIrPayload(chapterIr: ir, chapterFilePath: filePath);
    } catch (e) {
      Logging.warning('loadChapterPayload IR failed, fallback rich/plain: $e');
      return null;
    }
  }

  @override
  void syncChapterTypesetLayout(PaginationParams params) {
    _layoutParams = params;
  }

  @override
  bool consumeEpubRichSkippedNotice() {
    final pending = _pendingEpubRichSkipped;
    _pendingEpubRichSkipped = false;
    return pending;
  }

  void _flagEpubRichSkipped(bool skipped) {
    if (skipped) _pendingEpubRichSkipped = true;
  }

  TypesetConfig _buildTypesetFromParams(PaginationParams p) {
    final layoutInsets = paginatedTypesetLayoutInsets(
      fontSize: p.fontSize,
      lineHeight: p.lineHeight,
      paragraphSpacing: p.paragraphSpacing,
      measuredLineHeightDp: null,
    );
    return buildTypesetConfig(
      width: p.width,
      height: p.height,
      fontSize: p.fontSize,
      lineHeight: p.lineHeight,
      padding: p.padding,
      contentVerticalPadding: layoutInsets.contentVerticalPadding,
      pageHeightLineBuffer: layoutInsets.pageHeightLineBuffer,
      devicePixelRatio: p.devicePixelRatio,
      fontFamily: p.fontFamily,
      letterSpacing: p.letterSpacing,
      paragraphSpacing: p.paragraphSpacing,
      punctuationSqueeze: p.punctuationSqueeze,
      language: p.language,
      autoSpaceRatio: p.autoSpaceRatio,
      firstLineIndent: p.firstLineIndent ? 2 : 0,
    );
  }

  TypesetConfig _resolveTypesetConfig() {
    final p = _layoutParams;
    if (p != null) {
      return _buildTypesetFromParams(p);
    }
    return buildTypesetConfig(
      width: 400,
      height: 600,
      fontSize: _config.fontSize.value,
      lineHeight: _config.lineHeight.value,
      padding: _config.padding.value,
      devicePixelRatio: _layoutParams?.devicePixelRatio ?? 1.0,
      contentVerticalPadding: paginatedTypesetLayoutInsets(
        fontSize: _config.fontSize.value,
        lineHeight: _config.lineHeight.value,
        paragraphSpacing: _config.paragraphSpacing.value,
        measuredLineHeightDp: null,
      ).contentVerticalPadding,
      pageHeightLineBuffer: paginatedTypesetLayoutInsets(
        fontSize: _config.fontSize.value,
        lineHeight: _config.lineHeight.value,
        paragraphSpacing: _config.paragraphSpacing.value,
        measuredLineHeightDp: null,
      ).pageHeightLineBuffer,
      fontFamily: 'Noto Sans SC',
      letterSpacing: _config.letterSpacing.value,
      paragraphSpacing: _config.paragraphSpacing.value,
      punctuationSqueeze: _config.punctuationSqueeze.value,
      language: _config.language.value,
      autoSpaceRatio: _config.autoSpaceRatio.value,
      firstLineIndent: _config.firstLineIndent.value ? 2 : 0,
    );
  }

  PaginationParams _resolveStagingParams({
    double fontSize = ReaderTypographyDefaults.fontSize,
    double lineHeight = ReaderTypographyDefaults.lineHeight,
    double width = 400,
    double height = 600,
    double padding = ReaderTypographyDefaults.padding,
    double devicePixelRatio = 1.0,
    String fontFamily = 'Noto Sans SC',
  }) {
    final p = _layoutParams;
    if (p != null) {
      return PaginationParams(
        fontSize: p.fontSize,
        lineHeight: p.lineHeight,
        width: p.width,
        height: p.height,
        padding: p.padding,
        devicePixelRatio: p.devicePixelRatio,
        fontFamily: p.fontFamily,
        letterSpacing: p.letterSpacing,
        paragraphSpacing: p.paragraphSpacing,
        punctuationSqueeze: p.punctuationSqueeze,
        firstLineIndent: p.firstLineIndent,
        language: p.language,
        autoSpaceRatio: p.autoSpaceRatio,
      );
    }
    return PaginationParams(
      fontSize: fontSize,
      lineHeight: lineHeight,
      width: width,
      height: height,
      padding: padding,
      devicePixelRatio: devicePixelRatio,
      fontFamily: fontFamily,
      paragraphSpacing: _config.paragraphSpacing.value,
      punctuationSqueeze: _config.punctuationSqueeze.value,
      firstLineIndent: _config.firstLineIndent.value,
      language: _config.language.value,
      autoSpaceRatio: _config.autoSpaceRatio.value,
      letterSpacing: _config.letterSpacing.value,
    );
  }

  Future<ScrollChapterPayload> _loadChapterPayload(
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

      if (readingMode == ReadingMode.scroll) {
        return _loadScrollModePayload(
          bookId: bookId,
          chapterId: chapterId,
          sw: sw,
        );
      }

      return _loadRichCapablePayload(
        filePath: filePath,
        chapterId: chapterId,
        readingMode: readingMode,
        sw: sw,
      );
    } catch (e) {
      Logging.error('loadContent error: $e');
      throw Exception('Failed to load chapter content: $e');
    }
  }

  /// Scroll 主路径：IR → plain 回退；不走 rich / epubRichSkipped（ADR-009 Phase D）。
  Future<ScrollChapterPayload> _loadScrollModePayload({
    required String bookId,
    required int chapterId,
    required Stopwatch sw,
  }) async {
    // M2: 从 bookId 统一解析 filePath，供 Rust IR / plain 回退路径共用
    final book = await _getBook(bookId);
    final filePath = book.filePath;

    final irPayload = await _tryLoadScrollIr(
      bookId: bookId,
      chapterId: chapterId,
      readingMode: ReadingMode.scroll,
    );
    if (irPayload != null) {
      _flagEpubRichSkipped(false);
      _applyCurrentRich(chapterId, irPayload);
      _setChapterFilePath(filePath);
      return irPayload;
    }

    final content = await _fetchPlainChapterContent(filePath, chapterId);
    Logging.info(
      '[Timing] loadScrollPayload plain fallback: ${sw.elapsedMilliseconds}ms',
    );
    final plainPayload = scrollPlainPayload(content, chapterFilePath: filePath);
    _flagEpubRichSkipped(false);
    _applyCurrentRich(chapterId, plainPayload);
    _setChapterFilePath(filePath);
    return plainPayload;
  }

  Future<String> _fetchPlainChapterContent(
    String filePath,
    int chapterId,
  ) async {
    final result = await core_api.getChapter(
      filePath: filePath,
      chapterIndex: chapterId,
    );
    final content = result.when(
      raw: (text) => text,
      pages: (pages) => pages.map((p) => p.content).join('\n\n'),
    );
    if (content.isEmpty) {
      throw Exception('Chapter content is empty');
    }
    return content;
  }

  /// 双语 / 默认路径：可加载 EPUB rich；大章可触发 epubRichSkipped。
  Future<ScrollChapterPayload> _loadRichCapablePayload({
    required String filePath,
    required int chapterId,
    ReadingMode? readingMode,
    required Stopwatch sw,
  }) async {
    final loadRich = _needsRichContent(readingMode);
    final isEpub = filePath.toLowerCase().endsWith('.epub');

    Future<List<RichParagraph>>? epubRichFuture;
    if (isEpub && loadRich) {
      final config = _resolveTypesetConfig();
      epubRichFuture = epub_api
          .getEpubChapterRichContent(
            filePath: filePath,
            chapterIndex: chapterId,
            config: config,
          )
          .catchError((Object e) {
            Logging.warning(
              'getEpubChapterRichContent failed, falling back to plain text: $e',
            );
            return <RichParagraph>[];
          });
    }

    final results = await Future.wait([
      core_api.getChapter(filePath: filePath, chapterIndex: chapterId),
      if (epubRichFuture != null)
        epubRichFuture
      else
        Future<Object?>.value(null),
    ]);
    var content = (results[0] as types_api.ChapterContent).when(
      raw: (text) => text,
      pages: (pages) => pages.map((p) => p.content).join('\n\n'),
    );

    var epubRichSkipped = false;
    if (isEpub && content.length > 500 * 1024) {
      Logging.warning(
        'loadContent: content too large (${content.length} bytes), '
        'discarding rich text typesetting result',
      );
      epubRichSkipped = true;
    } else if (epubRichFuture != null && results[1] is List<RichParagraph>) {
      try {
        final paragraphs = results[1] as List<RichParagraph>;
        if (paragraphs.isNotEmpty) {
          final result = _richTextConverter.toTextSpan(paragraphs);
          content = result.$2;
          _flagEpubRichSkipped(false);
          return (
            content: content,
            richParagraphs: paragraphs,
            richRootSpan: result.$1,
            epubRichSkipped: false,
            chapterIr: null,
            chapterFilePath: filePath,
          );
        }
      } catch (e) {
        Logging.error('loadContent EPUB rich typeset failed: $e');
      }
    }

    if (content.isEmpty) {
      throw Exception('Chapter content is empty');
    }

    Logging.info(
      '[Timing] loadContent total: ${sw.elapsedMilliseconds}ms '
      '(EPUB=$isEpub)',
    );

    _flagEpubRichSkipped(epubRichSkipped);
    return scrollPlainPayload(
      content,
      epubRichSkipped: epubRichSkipped,
      chapterFilePath: filePath,
    );
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
  NextChapterStaging? get nextChapterStaging => _nextChapterStaging;

  @override
  NextChapterStaging? get prevChapterStaging => _prevChapterStaging;

  // ADR-016：原 Rust paginateChapter staging（_buildStaging）已移除；见 FlutterStagingPreloader。

  @override
  Future<void> preloadNextChapterStaging(
    String bookId,
    int chapterIndex, {
    double fontSize = 16,
    double lineHeight = ReaderTypographyDefaults.lineHeight,
    double width = 400,
    double height = 600,
    double padding = 20,
    double devicePixelRatio = 1.0,
    String fontFamily = 'Noto Sans SC',
  }) async {
    // ADR-016：staging 仅走 Flutter 精确预装箱。
    final gen = ++_stagingGen;
    final p = _resolveStagingParams(
      fontSize: fontSize,
      lineHeight: lineHeight,
      width: width,
      height: height,
      padding: padding,
      devicePixelRatio: devicePixelRatio,
      fontFamily: fontFamily,
    );
    final staging = await FlutterStagingPreloader.preload(
      bookId: bookId,
      chapterIndex: chapterIndex,
      params: p,
      forNext: true,
    );
    if (gen != _stagingGen) return;
    _nextChapterStaging = staging;
    if (staging != null) preloadGeneration.value++;
  }

  @override
  Future<void> preloadPreviousChapterStaging(
    String bookId,
    int chapterIndex, {
    double fontSize = 16,
    double lineHeight = ReaderTypographyDefaults.lineHeight,
    double width = 400,
    double height = 600,
    double padding = 20,
    double devicePixelRatio = 1.0,
    String fontFamily = 'Noto Sans SC',
  }) async {
    // ADR-016：staging 仅走 Flutter 精确预装箱。
    final gen = ++_stagingGen;
    final p = _resolveStagingParams(
      fontSize: fontSize,
      lineHeight: lineHeight,
      width: width,
      height: height,
      padding: padding,
      devicePixelRatio: devicePixelRatio,
      fontFamily: fontFamily,
    );
    final staging = await FlutterStagingPreloader.preload(
      bookId: bookId,
      chapterIndex: chapterIndex,
      params: p,
      forNext: false,
    );
    if (gen != _stagingGen) return;
    _prevChapterStaging = staging;
    if (staging != null) preloadGeneration.value++;
  }

  @override
  void clearNextChapterStaging() {
    _stagingGen++;
    _nextChapterStaging = null;
    PaginationStagingStore.clearNext();
  }

  @override
  void clearAdjacentStaging() {
    _stagingGen++;
    _nextChapterStaging = null;
    _prevChapterStaging = null;
    PaginationStagingStore.clearAll();
  }
}

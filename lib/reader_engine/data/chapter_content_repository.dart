import 'package:flutter/material.dart' show ValueNotifier;
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/reader_engine/shared/next_chapter_staging.dart';
import 'package:zephyr_reader/reader_engine/shared/config/reader_config.dart';
import 'package:zephyr_reader/reader_engine/shared/config/reader_typography_defaults.dart';
import 'package:zephyr_reader/reader_engine/pagination/flutter_staging_preloader.dart';
import 'package:zephyr_reader/reader_engine/pagination/pagination_staging_store.dart';
import 'package:zephyr_reader/reader_engine/scroll/scroll_chapter_payload.dart';
import 'package:zephyr_reader/reader_engine/shared/pagination_params.dart';
import 'package:zephyr_reader/reader_engine/shared/ir_types.dart';
import 'package:zephyr_reader/src/rust/api/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/chapter.dart' as chapter_api;
import 'package:zephyr_reader/src/rust/api/reader.dart' as reader_api;
import 'package:zephyr_reader/src/rust/domain/book/models.dart';
import 'package:zephyr_reader/src/rust/domain/chapter/models.dart';

/// 章节内容仓库。
@Injectable()
class ChapterContentRepository {
  ChapterContentRepository(this._config);

  final ReaderConfig _config;
  PaginationParams? _layoutParams;
  bool _pendingEpubRichSkipped = false;

  ReaderChapterIr? _currentChapterIr;
  String? _currentChapterFilePath;

  String? _cachedBookId;
  Book? _cachedBook;

  NextChapterStaging? _nextChapterStaging;
  NextChapterStaging? _prevChapterStaging;

  /// staging 预加载 generation 计数器，用于丢弃过期结果。
  int _stagingGen = 0;

  final preloadGeneration = ValueNotifier<int>(0);

  ReaderChapterIr? get currentChapterIr => _currentChapterIr;

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

  Future<List<Chapter>> getChapters(String bookId) async {
    return chapter_api.listChaptersByBook(bookId: bookId);
  }

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
    _applyCurrentIr(payload);
    _setChapterFilePath((await _getBook(bookId)).filePath);
    return payload.content;
  }

  /// 加载单章滚动拼接数据。
  Future<ScrollChapterPayload> loadScrollSegment(
    String bookId,
    int chapterId, {
    ReadingMode? readingMode,
  }) => _loadChapterPayload(bookId, chapterId, readingMode: readingMode);

  void _applyCurrentIr(ScrollChapterPayload payload) {
    _currentChapterIr = payload.chapterIr;
  }

  void _setChapterFilePath(String? path) {
    _currentChapterFilePath = path;
  }

  /// 尝试加载 scroll IR（EPUB/TXT）。
  Future<ScrollChapterPayload?> _tryLoadScrollIr({
    required String bookId,
    required int chapterId,
    required ReadingMode? readingMode,
  }) async {
    if (readingMode != ReadingMode.scroll) return null;
    final book = await _getBook(bookId);
    final filePath = book.filePath;

    final sw = Stopwatch()..start();
    try {
      final ir = await reader_api.getChapterContentIr(
        bookId: bookId,
        chapterIndex: chapterId,
      );
      if (ir.blocks.isEmpty || ir.plainText.isEmpty) return null;
      Logging.info(
        '[Timing] loadChapterIr: ${sw.elapsedMilliseconds}ms blocks=${ir.blocks.length}',
      );
      return scrollIrPayload(
        chapterIr: convertChapterIrFromFrb(ir),
        chapterFilePath: filePath,
      );
    } catch (e) {
      Logging.warning('loadChapterPayload IR failed, fallback rich/plain: $e');
      return null;
    }
  }

  void syncChapterTypesetLayout(PaginationParams params) {
    _layoutParams = params;
  }

  bool consumeEpubRichSkippedNotice() {
    final pending = _pendingEpubRichSkipped;
    _pendingEpubRichSkipped = false;
    return pending;
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
        bookId: bookId,
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

  /// Scroll 主路径：IR → plain 回退。
  Future<ScrollChapterPayload> _loadScrollModePayload({
    required String bookId,
    required int chapterId,
    required Stopwatch sw,
  }) async {
    final book = await _getBook(bookId);
    final filePath = book.filePath;

    final irPayload = await _tryLoadScrollIr(
      bookId: bookId,
      chapterId: chapterId,
      readingMode: ReadingMode.scroll,
    );
    if (irPayload != null) {
      _applyCurrentIr(irPayload);
      _setChapterFilePath(filePath);
      return irPayload;
    }

    final content = await _fetchPlainChapterContent(filePath, chapterId);
    Logging.info(
      '[Timing] loadScrollPayload plain fallback: ${sw.elapsedMilliseconds}ms',
    );
    final plainPayload = scrollPlainPayload(content, chapterFilePath: filePath);
    _applyCurrentIr(plainPayload);
    _setChapterFilePath(filePath);
    return plainPayload;
  }

  Future<String> _fetchPlainChapterContent(
    String filePath,
    int chapterId,
  ) async {
    final content = await reader_api.getChapter(
      filePath: filePath,
      chapterIndex: chapterId,
    );
    if (content.isEmpty) {
      throw Exception('Chapter content is empty');
    }
    return content;
  }

  /// 双语 / 默认路径：通过 IR 加载。
  Future<ScrollChapterPayload> _loadRichCapablePayload({
    required String bookId,
    required String filePath,
    required int chapterId,
    ReadingMode? readingMode,
    required Stopwatch sw,
  }) async {
    final isEpub = filePath.toLowerCase().endsWith('.epub');

    Future<dynamic> contentIrFuture;
    if (isEpub && readingMode == ReadingMode.bilingual) {
      contentIrFuture = reader_api.getChapterContentIr(
        bookId: bookId,
        chapterIndex: chapterId,
      );
    } else {
      contentIrFuture = Future.error('no IR requested');
    }

    final results = await Future.wait([
      reader_api.getChapter(filePath: filePath, chapterIndex: chapterId),
      contentIrFuture
          .then<ReaderChapterIr?>((v) => convertChapterIrFromFrb(v))
          .catchError((_) {
            Logging.warning(
              'getChapterContentIr failed, falling back to plain text',
            );
            return null;
          }),
    ]);
    final content = results[0] as String;
    final ir = results[1] as ReaderChapterIr?;

    if (ir != null && ir.blocks.isNotEmpty) {
      Logging.info(
        '[Timing] loadRichCapablePayload IR: ${sw.elapsedMilliseconds}ms '
        'blocks=${ir.blocks.length}',
      );
      return scrollIrPayload(chapterIr: ir, chapterFilePath: filePath);
    }

    if (content.isEmpty) {
      throw Exception('Chapter content is empty');
    }

    Logging.info(
      '[Timing] loadContent total: ${sw.elapsedMilliseconds}ms '
      '(EPUB=$isEpub)',
    );

    return scrollPlainPayload(content, chapterFilePath: filePath);
  }

  Future<String> _loadRawContent(String bookId, int chapterId) async {
    final book = await _getBook(bookId);
    if (book.filePath.isEmpty) {
      throw Exception('Book not found: $bookId');
    }
    final result = await reader_api.getChapter(
      filePath: book.filePath,
      chapterIndex: chapterId,
    );
    return result;
  }

  Future<void> preload(String bookId, int chapterId) async {
    try {
      await _loadRawContent(bookId, chapterId);
    } catch (e) {
      Logging.error('章节预加载失败', exception: e);
    }
  }

  NextChapterStaging? get nextChapterStaging => _nextChapterStaging;

  NextChapterStaging? get prevChapterStaging => _prevChapterStaging;

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

  void clearNextChapterStaging() {
    _stagingGen++;
    _nextChapterStaging = null;
    PaginationStagingStore.clearNext();
  }

  void clearAdjacentStaging() {
    _stagingGen++;
    _nextChapterStaging = null;
    _prevChapterStaging = null;
    PaginationStagingStore.clearAll();
  }
}

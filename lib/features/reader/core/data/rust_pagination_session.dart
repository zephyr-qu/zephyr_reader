import 'dart:async';
import 'dart:math' as math;
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/data/page_content_cache.dart';
import 'package:zephyr_reader/features/reader/core/domain/pagination_session.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class RustPaginationSession implements PaginationSession {
  List<PageDescriptor>? _descriptors;
  int? _sessionConfigHash;
  core_api.PaginationSessionHandle? _handle;
  final _contentCache = PageContentCache();

  String? _cachedBookId;
  Book? _cachedBook;

  @override
  List<PageDescriptor>? get descriptors => _descriptors;

  /// 上次分页的 configHash；null 表示无 session。
  @override
  int? get sessionConfigHash => _sessionConfigHash;
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

  TypesetConfig _buildConfig(PaginationParams p) => buildTypesetConfig(
    width: p.width,
    height: p.height,
    fontSize: p.fontSize,
    lineHeight: p.lineHeight,
    padding: p.padding,
    devicePixelRatio: p.devicePixelRatio,
    calibration: p.calibration,
    fontFamily: p.fontFamily,
    letterSpacing: p.letterSpacing,
    paragraphSpacing: p.paragraphSpacing,
    punctuationSqueeze: p.punctuationSqueeze,
    firstLineIndent: p.firstLineIndent ? 2 : 0,
    enableHyphenation: p.enableHyphenation,
    language: p.language,
    autoSpaceRatio: p.autoSpaceRatio,
  );

  void _releaseHandle() {
    final handle = _handle;
    if (handle == null) return;
    try {
      core_api.disposePaginationSession(handle: handle);
    } catch (e) {
      Logging.error('disposePaginationSession error: $e');
    }
    _handle = null;
  }

  void _applyPaginateResult(PaginateResult result) {
    _descriptors = result.descriptors;
    _sessionConfigHash = result.configHash.toInt();
  }

  Future<PaginateResult> _createSession({
    required String bookId,
    required int chapterIndex,
    required TypesetConfig config,
    BigInt? maxChars,
  }) async {
    final book = await _getBook(bookId);
    if (book.filePath.isEmpty) {
      throw Exception('_createSession: book not found for bookId=$bookId');
    }

    _releaseHandle();
    _contentCache.clear();

    final sw = Stopwatch()..start();
    final (handle, result) = await core_api.createPaginationSession(
      filePath: book.filePath,
      chapterIndex: chapterIndex,
      config: config,
      maxChars: maxChars,
    );
    Logging.info(
      '[Timing] createPaginationSession: ${sw.elapsedMilliseconds}ms '
      '(maxChars=${maxChars ?? "full"}, isPartial=${result.isPartial}, pages=${result.descriptors.length})',
    );

    _handle = handle;
    _applyPaginateResult(result);
    return result;
  }

  void _preloadPageRange(int count) {
    final total = _descriptors?.length ?? 0;
    final limit = count.clamp(0, total);
    for (int i = 0; i < limit; i++) {
      _fetchPageSync(i);
    }
  }


  @override
  Future<({int totalPages, bool isPartial})> beginPaginate({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  }) async {
    try {
      final result = await _createSession(
        bookId: bookId,
        chapterIndex: chapterIndex,
        config: _buildConfig(params),
        maxChars: maxChars,
      );
      _preloadPageRange(5);
      return (
        totalPages: result.descriptors.length,
        isPartial: result.isPartial,
      );
    } catch (e) {
      Logging.error('beginPaginate error: $e');
      return (totalPages: 0, isPartial: false);
    }
  }

  @override
  Future<({int totalPages, bool isPartial})> expandToFullChapter({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
  }) async {
    try {
      final oldLength = _descriptors?.length ?? 0;
      final newConfig = _buildConfig(params);
      late final PaginateResult result;

      if (_handle != null) {
        final sw = Stopwatch()..start();
        result = await core_api.paginateSessionFull(
          handle: _handle!,
          config: newConfig,
        );
        Logging.info(
          '[Timing] paginateSessionFull: ${sw.elapsedMilliseconds}ms '
          '(pages=${result.descriptors.length})',
        );
      } else {
        result = await _createSession(
          bookId: bookId,
          chapterIndex: chapterIndex,
          config: newConfig,
        );
      }

      _applyPaginateResult(result);
      final preloadCount = 5.clamp(0, result.descriptors.length);
      for (int i = oldLength; i < preloadCount; i++) {
        unawaited(_fetchPageSync(i));
      }
      return (
        totalPages: result.descriptors.length,
        isPartial: result.isPartial,
      );
    } catch (e) {
      Logging.error('expandToFullChapter error: $e');
      return (totalPages: 0, isPartial: false);
    }
  }

  /// In-place re-pagination: reuses the same Rust session handle, swaps in
  /// the new config (or the same one if [maxChars] only differs).
  /// Caller must have a valid handle (i.e. [beginPaginate] was called first).
  @override
  Future<({int totalPages, bool isPartial})> repaginateInPlace({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  }) async {
    final handle = _handle;
    if (handle == null) {
      // 无 handle → 退化到 beginPaginate（用真实 bookId/chapterIndex）
      Logging.warning('repaginateInPlace: no handle, falling back to beginPaginate');
      return beginPaginate(
        bookId: bookId,
        chapterIndex: chapterIndex,
        params: params,
        maxChars: maxChars,
      );
    }
    try {
      final newConfig = _buildConfig(params);
      final oldHash = _sessionConfigHash;
      final sw = Stopwatch()..start();
      final result = await core_api.repaginateSession(
        handle: handle,
        config: newConfig,
        maxChars: maxChars,
      );
      Logging.info(
        '[Timing] repaginateSession: ${sw.elapsedMilliseconds}ms '
        '(pages=${result.descriptors.length})',
      );

      _applyPaginateResult(result);
      // Config 变更时清空页缓存（页边界可能变了）
      if (oldHash != result.configHash.toInt()) {
        _contentCache.clear();
      }
      final preloadCount = 5.clamp(0, result.descriptors.length);
      for (int i = 0; i < preloadCount; i++) {
        unawaited(_fetchPageSync(i));
      }
      return (
        totalPages: result.descriptors.length,
        isPartial: result.isPartial,
      );
    } catch (e) {
      Logging.error('repaginateInPlace error: $e');
      return (totalPages: 0, isPartial: false);
    }
  }

  @override
  String? pageContent(int pageIndex) => _contentCache.get(pageIndex);

  Future<void> _fetchPageSync(int pageIndex) async {
    if (_contentCache.containsKey(pageIndex)) return;
    final handle = _handle;
    if (handle == null || _descriptors == null) return;
    if (pageIndex < 0 || pageIndex >= _descriptors!.length) return;

    try {
      final content = await core_api.getSessionPageContent(
        handle: handle,
        pageIndex: pageIndex,
      );
      if (content.isNotEmpty) {
        _contentCache.put(pageIndex, content);
      }
    } catch (e) {
      Logging.error('_fetchPageSync error for page $pageIndex: $e');
    }
  }

  @override
  void ensureWindow(int centerPage) {
    if (_descriptors == null) return;

    _fetchPageSync(centerPage);
    _prefetchSurrounding(centerPage);
  }

  void _prefetchSurrounding(int center) {
    if (_descriptors == null) return;
    final total = _descriptors!.length;
    final start = math.max(0, center - 3);
    final end = math.min(total - 1, center + 3);

    Future.microtask(() {
      for (int i = start; i <= end; i++) {
        _fetchPageSync(i);
      }
    });

    _contentCache.trimAround(center);
  }

  @override
  void warmPageCache(int pageIndex, String content) =>
      _contentCache.warm(pageIndex, content);

  @override
  void dispose() {
    _releaseHandle();
    _descriptors = null;
    _sessionConfigHash = null;
    _contentCache.clear();
    _cachedBook = null;
    _cachedBookId = null;
  }
}


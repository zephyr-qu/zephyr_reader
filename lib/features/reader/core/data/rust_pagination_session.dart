import 'dart:async';
import 'dart:math' as math;
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/data/page_content_cache.dart';
import 'package:zephyr_reader/features/reader/core/domain/pagination_session.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/reading/types.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class RustPaginationSession implements PaginationSession {
  List<PageDescriptor>? _descriptors;
  int? _sessionConfigHash;
  int? _sessionChapterIndex;
  bool _sessionIsPartial = false;
  PaginationSessionHandle? _handle;
  final _contentCache = PageContentCache();

  String? _cachedBookId;
  Book? _cachedBook;

  @override
  List<PageDescriptor>? get descriptors => _descriptors;

  /// 上次分页的 configHash；null 表示无 session。
  @override
  int? get sessionConfigHash => _sessionConfigHash;

  @override
  int? get sessionChapterIndex => _sessionChapterIndex;

  @override
  bool get sessionIsPartial => _sessionIsPartial;
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

  void _applyPaginateResult(PaginateResult result, {int? chapterIndex}) {
    final descriptorsChanged = _descriptors != result.descriptors ||
        _sessionIsPartial != result.isPartial ||
        _sessionConfigHash != result.configHash.toInt();
    _descriptors = result.descriptors;
    _sessionConfigHash = result.configHash.toInt();
    _sessionIsPartial = result.isPartial;
    if (chapterIndex != null) _sessionChapterIndex = chapterIndex;
    // 分页边界变化后必须清空页文本缓存，否则 partial→full 或重排版后会
    // 用旧页内容配新 descriptors，导致空白页或重复行。
    if (descriptorsChanged) {
      _contentCache.clear();
    }
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
    _applyPaginateResult(result, chapterIndex: chapterIndex);
    return result;
  }

  Future<void> _preloadPageRange(int count) async {
    final total = _descriptors?.length ?? 0;
    final limit = count.clamp(0, total);
    for (int i = 0; i < limit; i++) {
      await _fetchAndCachePage(i);
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
      await _preloadPageRange(5);
      return (
        totalPages: result.descriptors.length,
        isPartial: result.isPartial,
      );
    } catch (e, st) {
      Logging.error('beginPaginate error: $e', exception: e, stackTrace: st);
      rethrow;
    }
  }

  /// Try to adopt an existing streamer from cache (zero-paginate path).
  @override
  Future<({int totalPages, bool isPartial})> beginPaginateFromCache({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  }) async {
    try {
      final book = await _getBook(bookId);
      if (book.filePath.isEmpty) {
        throw Exception('beginPaginateFromCache: book not found for bookId=$bookId');
      }
      final config = _buildConfig(params);

      _releaseHandle();
      _contentCache.clear();

      final sw = Stopwatch()..start();
      final (handle, result) = await core_api.createPaginationSessionAdopt(
        filePath: book.filePath,
        chapterIndex: chapterIndex,
        config: config,
      );
      Logging.info(
        '[Timing] createPaginationSessionAdopt: HIT ${sw.elapsedMilliseconds}ms '
        '(pages=${result.descriptors.length}, isPartial=${result.isPartial})',
      );

      _handle = handle;
      _applyPaginateResult(result, chapterIndex: chapterIndex);
      return (
        totalPages: result.descriptors.length,
        isPartial: result.isPartial,
      );
    } catch (e) {
      Logging.info(
        '[Timing] createPaginationSessionAdopt: MISS ($e), falling back',
      );
      return beginPaginate(
        bookId: bookId,
        chapterIndex: chapterIndex,
        params: params,
        maxChars: maxChars,
      );
    }
  }

  @override
  Future<({int totalPages, bool isPartial})> expandToFullChapter({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
  }) async {
    try {
      final newConfig = _buildConfig(params);
      late final PaginateResult result;

      if (_handle != null) {
        final sw = Stopwatch()..start();
        // config hash 未变 → 复用 session 已有 config，避免重复 validate
        final newHash = core_api.computeConfigHash(config: newConfig);
        final configArg =
            (newHash.toInt() == _sessionConfigHash) ? null : newConfig;
        result = await core_api.paginateSessionFull(
          handle: _handle!,
          config: configArg,
        );
        Logging.info(
          '[Timing] paginateSessionFull: ${sw.elapsedMilliseconds}ms '
          '(pages=${result.descriptors.length}, config=${configArg == null ? "reuse" : "new"})',
        );
      } else {
        result = await _createSession(
          bookId: bookId,
          chapterIndex: chapterIndex,
          config: newConfig,
        );
      }

      _applyPaginateResult(result, chapterIndex: chapterIndex);
      await _preloadPageRange(5);
      return (
        totalPages: result.descriptors.length,
        isPartial: result.isPartial,
      );
    } catch (e, st) {
      Logging.error('expandToFullChapter error: $e', exception: e, stackTrace: st);
      rethrow;
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
      Logging.warning(
        'repaginateInPlace: no handle, falling back to beginPaginate',
      );
      return beginPaginate(
        bookId: bookId,
        chapterIndex: chapterIndex,
        params: params,
        maxChars: maxChars,
      );
    }
    try {
      final newConfig = _buildConfig(params);
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

      _applyPaginateResult(result, chapterIndex: chapterIndex);
      await _preloadPageRange(5);
      return (
        totalPages: result.descriptors.length,
        isPartial: result.isPartial,
      );
    } catch (e, st) {
      Logging.error('repaginateInPlace error: $e', exception: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  String? pageContent(int pageIndex) {
    final cached = _contentCache.get(pageIndex);
    if (cached != null) {
      Logging.debug('[Session] pageContent HIT  page=$pageIndex (${cached.length} chars)');
    } else {
      Logging.debug('[Session] pageContent MISS page=$pageIndex');
    }
    return cached;
  }

  /// Async fetch-and-cache for a single page.
  /// Returns null on invalid state or fetch error.
  Future<String?> _fetchAndCachePage(int pageIndex) async {
    if (_contentCache.containsKey(pageIndex)) return _contentCache.get(pageIndex);
    final handle = _handle;
    if (handle == null || _descriptors == null) return null;
    if (pageIndex < 0 || pageIndex >= _descriptors!.length) return null;
    Logging.info('[Session] fetch page=$pageIndex start');
    try {
      final content = await Future.microtask(() => core_api.getSessionPageContent(
        handle: handle,
        pageIndex: pageIndex,
      ));
      if (content.isNotEmpty) {
        _contentCache.put(pageIndex, content);
      }
      Logging.info('[Session] fetch page=$pageIndex done (${content.length} chars)');
      return content.isEmpty ? null : content;
    } catch (e) {
      Logging.error('_fetchAndCachePage error for page $pageIndex: $e');
      return null;
    }
  }


  @override
  void ensureWindow(int centerPage) {
    if (_descriptors == null) return;
    Logging.info('[Session] ensureWindow center=$centerPage total=${_descriptors!.length}');

    unawaited(_fetchAndCachePage(centerPage));
    _prefetchSurrounding(centerPage);
  }

  void _prefetchSurrounding(int center) {
    if (_descriptors == null) return;
    final total = _descriptors!.length;
    final start = math.max(0, center - 3);
    final end = math.min(total - 1, center + 3);
    Logging.debug('[Session] prefetch surrounding pages=$start..$end (center=$center total=$total)');

    Future.microtask(() async {
      for (int i = start; i <= end; i++) {
        await _fetchAndCachePage(i);
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
    _sessionChapterIndex = null;
    _sessionIsPartial = false;
    _contentCache.clear();
    _cachedBook = null;
    _cachedBookId = null;
  }
}

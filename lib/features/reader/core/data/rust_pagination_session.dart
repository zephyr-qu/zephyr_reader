import 'dart:async';
import 'dart:math' as math;
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/data/epub_block_image_cache.dart';
import 'package:zephyr_reader/features/reader/core/data/page_blocks_cache.dart';
import 'package:zephyr_reader/features/reader/core/data/page_content_cache.dart';
import 'package:zephyr_reader/features/reader/core/domain/pagination_session.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/reading/types.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/domain/types/block_pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class RustPaginationSession implements PaginationSession {
  RustPaginationSession({this._onCacheUpdated});

  final void Function()? _onCacheUpdated;

  List<PageDescriptor>? _descriptors;
  BigInt? _sessionConfigHash;
  int? _sessionChapterIndex;
  bool _sessionIsPartial = false;
  ChapterPaginationMode _sessionMode = ChapterPaginationMode.plainText;
  String? _sessionFilePath;
  int _imageMaxWidthPx = 800;
  PaginationSessionHandle? _handle;
  final _contentCache = PageContentCache();
  final _blocksCache = PageBlocksCache();

  String? _cachedBookId;
  Book? _cachedBook;

  @override
  List<PageDescriptor>? get descriptors => _descriptors;

  /// 上次分页的 configHash（BigInt，不做 u64 截断）；null 表示无 session。
  @override
  BigInt? get sessionConfigHash => _sessionConfigHash;

  @override
  int? get sessionChapterIndex => _sessionChapterIndex;

  @override
  bool get sessionIsPartial => _sessionIsPartial;

  @override
  ChapterPaginationMode get sessionMode => _sessionMode;

  /// 当前 session 绑定的 EPUB/TXT 文件路径（图片 decode 用）。
  @override
  String? get sessionFilePath => _sessionFilePath;
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

  void _syncImageMaxWidth(PaginationParams params) {
    _imageMaxWidthPx = (params.width - 2 * params.padding).round().clamp(
      1,
      4096,
    );
  }

  void _prefetchBlockImages(List<PageBlockSlice> blocks) {
    final path = _sessionFilePath;
    if (path == null || path.isEmpty) return;
    epubBlockImageCache.prefetchBlocks(
      filePath: path,
      blocks: blocks,
      maxWidthPx: _imageMaxWidthPx,
    );
  }

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
    final oldCount = _descriptors?.length ?? 0;
    final oldMode = _sessionMode;
    final oldPartial = _sessionIsPartial;

    final descriptorsChanged =
        _descriptors != result.descriptors ||
        oldPartial != result.isPartial ||
        _sessionConfigHash != result.configHash;
    _descriptors = result.descriptors;
    _sessionConfigHash = result.configHash;
    _sessionIsPartial = result.isPartial;
    _sessionMode = result.mode;
    if (chapterIndex != null) _sessionChapterIndex = chapterIndex;
    if (descriptorsChanged) {
      _contentCache.clear();
      _blocksCache.clear();
      epubBlockImageCache.clear();
    }

    final newCount = result.descriptors.length;
    final countChanged = oldCount != newCount;
    final modeChanged = oldMode != result.mode;
    final partialChanged = oldPartial != result.isPartial;
    if (countChanged || modeChanged || partialChanged) {
      Logging.info(
        '[LayoutChange] ch=$_sessionChapterIndex '
        'pages $oldCount→$newCount'
        ' mode ${oldMode.name}→${result.mode.name}'
        ' partial $oldPartial→${result.isPartial}'
        ' ${descriptorsChanged ? "cacheCleared" : "cacheKept"}',
      );
    }
  }

  void _notifyCacheUpdated() {
    _onCacheUpdated?.call();
  }

  Future<PaginateResult> _createSession({
    required String bookId,
    required int chapterIndex,
    required TypesetConfig config,
    BigInt? maxChars,
  }) async {
    // M2: book_id → file_path 解析移入 Rust 侧；Dart 仅保留 filePath 用于图片解码。
    final book = await _getBook(bookId);
    if (book.filePath.isEmpty) {
      throw Exception('_createSession: book not found for bookId=$bookId');
    }

    _releaseHandle();
    _contentCache.clear();
    _blocksCache.clear();
    epubBlockImageCache.clear();

    final sw = Stopwatch()..start();
    final (handle, result) = await core_api.createPaginationSession(
      bookId: bookId,
      chapterIndex: chapterIndex,
      config: config,
      maxChars: maxChars,
    );
    Logging.info(
      '[FirstLoad] createSession chapter=$chapterIndex ${sw.elapsedMilliseconds}ms'
      ' pages=${result.descriptors.length} partial=${result.isPartial}'
      ' mode=${result.mode} maxChars=${maxChars ?? "full"}',
    );

    _handle = handle;
    _sessionFilePath = book.filePath;
    _applyPaginateResult(result, chapterIndex: chapterIndex);
    return result;
  }

  Future<void> _preloadPageRange(int count) async {
    final total = _descriptors?.length ?? 0;
    final limit = count.clamp(0, total);
    if (limit == 0) return;

    await _prefetchPageBundle(0);
    if (limit > 1) {
      await Future.wait([
        for (int i = 1; i < limit; i++) _prefetchPageBundle(i),
      ]);
    }
    _notifyCacheUpdated();
    Logging.info('[FirstLoad] preloadPageRange count=$limit total=$total');
  }

  @override
  Future<({int totalPages, bool isPartial})> beginPaginate({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  }) async {
    try {
      _syncImageMaxWidth(params);
      final result = await _createSession(
        bookId: bookId,
        chapterIndex: chapterIndex,
        config: _buildConfig(params),
        maxChars: maxChars,
      );
      await _preloadPageRange(5);
      Logging.info(
        '[FirstLoad] beginPaginate done chapter=$chapterIndex'
        ' pages=${result.descriptors.length} partial=${result.isPartial}',
      );
      return (
        totalPages: result.descriptors.length,
        isPartial: result.isPartial,
      );
    } catch (e, st) {
      Logging.error(
        '[FirstLoad] beginPaginate error: $e',
        exception: e,
        stackTrace: st,
      );
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
        throw Exception(
          'beginPaginateFromCache: book not found for bookId=$bookId',
        );
      }
      _syncImageMaxWidth(params);
      final config = _buildConfig(params);

      _releaseHandle();
      _contentCache.clear();
      _blocksCache.clear();
      epubBlockImageCache.clear();

      final sw = Stopwatch()..start();
      final (handle, result) = await core_api.createPaginationSessionAdopt(
        bookId: bookId,
        chapterIndex: chapterIndex,
        config: config,
      );
      Logging.info(
        '[ChapterTransition] adoptStaging ch=$chapterIndex ${sw.elapsedMilliseconds}ms'
        ' pages=${result.descriptors.length} partial=${result.isPartial}'
        ' mode=${result.mode}',
      );

      // P0: all chapters now require block path. If adopt returns
      // any non-contentBlocks engine (stale plainText cache from pre-P0
      // preload or pre-P0 sled), recreate as block session.
      if (result.mode != ChapterPaginationMode.contentBlocks) {
        Logging.info(
          '[ChapterTransition] adoptNonBlock ch=$chapterIndex mode=${result.mode} partial=${result.isPartial} → recreate block session',
        );
        _releaseHandle();
        return beginPaginate(
          bookId: bookId,
          chapterIndex: chapterIndex,
          params: params,
          maxChars: null,
        );
      }

      _handle = handle;
      _sessionFilePath = book.filePath;
      _applyPaginateResult(result, chapterIndex: chapterIndex);
      await _preloadPageRange(5);
      return (
        totalPages: result.descriptors.length,
        isPartial: result.isPartial,
      );
    } catch (e) {
      Logging.info(
        '[ChapterTransition] adoptStaging MISS ($e), fallback to beginPaginate',
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
      _syncImageMaxWidth(params);
      final newConfig = _buildConfig(params);
      late final PaginateResult result;

      if (_handle != null) {
        final sw = Stopwatch()..start();
        // config hash 未变 → 复用 session 已有 config，避免重复 validate
        final newHash = core_api.computeConfigHash(config: newConfig);
        final configArg = (newHash == _sessionConfigHash) ? null : newConfig;
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
      Logging.error(
        'expandToFullChapter error: $e',
        exception: e,
        stackTrace: st,
      );
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
      _syncImageMaxWidth(params);
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
      Logging.error(
        'repaginateInPlace error: $e',
        exception: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<({int totalPages, bool isPartial})> applySessionCalibration({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  }) async {
    final handle = _handle;
    final calibration = params.calibration;
    if (handle == null || calibration == null) {
      Logging.warning(
        'applySessionCalibration: missing handle or calibration, '
        'falling back to repaginateInPlace',
      );
      return repaginateInPlace(
        bookId: bookId,
        chapterIndex: chapterIndex,
        params: params,
        maxChars: maxChars,
      );
    }
    try {
      _syncImageMaxWidth(params);
      final sw = Stopwatch()..start();
      final result = await core_api.applySessionCalibration(
        handle: handle,
        calibration: calibrationToRust(calibration),
        maxChars: maxChars,
      );
      Logging.info(
        '[Timing] applySessionCalibration: ${sw.elapsedMilliseconds}ms '
        '(pages=${result.descriptors.length})',
      );

      _applyPaginateResult(result, chapterIndex: chapterIndex);
      await _preloadPageRange(5);
      return (
        totalPages: result.descriptors.length,
        isPartial: result.isPartial,
      );
    } catch (e, st) {
      Logging.error(
        'applySessionCalibration error: $e',
        exception: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<String?> fetchPageContent(int pageIndex) =>
      _fetchAndCachePage(pageIndex);

  @override
  List<PageBlockSlice>? pageBlocks(int pageIndex) {
    final cached = _blocksCache.get(pageIndex);
    return cached;
  }

  @override
  String? pageContent(int pageIndex) {
    final cached = _contentCache.get(pageIndex);
    return cached;
  }

  Future<List<PageBlockSlice>?> _fetchAndCacheBlocks(int pageIndex) async {
    if (_blocksCache.containsKey(pageIndex)) {
      final cached = _blocksCache.get(pageIndex);
      if (cached != null) {
        _prefetchBlockImages(cached);
      }
      return cached;
    }
    final handle = _handle;
    if (handle == null || _descriptors == null) return null;
    if (pageIndex < 0 || pageIndex >= _descriptors!.length) return null;
    if (_sessionMode != ChapterPaginationMode.contentBlocks) return const [];

    try {
      final blocks = await Future.microtask(
        () =>
            core_api.getSessionPageBlocks(handle: handle, pageIndex: pageIndex),
      );
      _blocksCache.put(pageIndex, blocks);
      Logging.info(
        '[Session] fetch blocks page=$pageIndex count=${blocks.length}',
      );
      _prefetchBlockImages(blocks);
      _notifyCacheUpdated();
      return blocks;
    } catch (e) {
      Logging.error('_fetchAndCacheBlocks error for page $pageIndex: $e');
      return null;
    }
  }

  /// Async fetch-and-cache for a single page.
  /// Returns null on invalid state or fetch error.
  Future<String?> _fetchAndCachePage(int pageIndex) async {
    if (_contentCache.containsKey(pageIndex)) {
      return _contentCache.get(pageIndex);
    }
    final handle = _handle;
    if (handle == null || _descriptors == null) return null;
    if (pageIndex < 0 || pageIndex >= _descriptors!.length) return null;
    try {
      final content = await Future.microtask(
        () => core_api.getSessionPageContent(
          handle: handle,
          pageIndex: pageIndex,
        ),
      );
      if (content.isNotEmpty) {
        _contentCache.put(pageIndex, content);
      }
      Logging.info(
        '[Session] fetch page=$pageIndex done (${content.length} chars)',
      );
      if (content.isNotEmpty) {
        _notifyCacheUpdated();
      }
      return content.isEmpty ? null : content;
    } catch (e) {
      Logging.error('_fetchAndCachePage error for page $pageIndex: $e');
      return null;
    }
  }

  @override
  void ensureWindow(int centerPage) {
    if (_descriptors == null) return;
    Logging.info(
      '[Session] ensureWindow center=$centerPage total=${_descriptors!.length}',
    );

    unawaited(_fetchAndCachePage(centerPage));
    if (_sessionMode == ChapterPaginationMode.contentBlocks) {
      unawaited(_fetchAndCacheBlocks(centerPage));
    }
    _prefetchSurrounding(centerPage);
  }

  void _prefetchSurrounding(int center) {
    if (_descriptors == null) return;
    final total = _descriptors!.length;
    final start = math.max(0, center - 3);
    final end = math.min(total - 1, center + 3);
    Future.microtask(() async {
      await _prefetchPageBundle(center);
      final others = <int>[
        for (int i = start; i <= end; i++)
          if (i != center) i,
      ];
      if (others.isNotEmpty) {
        await Future.wait(others.map(_prefetchPageBundle));
      }
    });

    _contentCache.trimAround(center);
    _blocksCache.trimAround(center);
  }

  Future<void> _prefetchPageBundle(int pageIndex) async {
    await _fetchAndCachePage(pageIndex);
    if (_sessionMode == ChapterPaginationMode.contentBlocks) {
      await _fetchAndCacheBlocks(pageIndex);
    }
  }

  @override
  void warmPageCache(int pageIndex, String content) =>
      _contentCache.warm(pageIndex, content);

  @override
  int? resolvePageIndexForCharOffset(int charOffset) {
    final handle = _handle;
    if (handle == null) return null;
    try {
      return core_api.sessionCharOffsetToPageIndex(
        handle: handle,
        charOffset: charOffset,
      );
    } catch (e) {
      Logging.warning(
        '[Session] resolvePageIndexForCharOffset off=$charOffset: $e',
      );
      return null;
    }
  }

  @override
  void dispose() {
    _releaseHandle();
    _descriptors = null;
    _sessionConfigHash = null;
    _sessionChapterIndex = null;
    _sessionIsPartial = false;
    _sessionMode = ChapterPaginationMode.plainText;
    _sessionFilePath = null;
    _contentCache.clear();
    _blocksCache.clear();
    epubBlockImageCache.clear();
    _cachedBook = null;
    _cachedBookId = null;
  }
}

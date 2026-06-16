import 'dart:math' as math;

import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/domain/pagination_session.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class RustPaginationSession implements PaginationSession {
  List<PageDescriptor>? _descriptors;
  List<PageInfo>? _approximatePages;
  core_api.PaginationSessionHandle? _handle;
  final Map<int, String> _pageCache = {};

  String? _cachedBookId;
  Book? _cachedBook;

  @override
  List<PageDescriptor>? get descriptors => _descriptors;

  @override
  List<PageInfo>? get approximatePages => _approximatePages;

  @override
  set approximatePages(List<PageInfo>? pages) => _approximatePages = pages;

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
    _pageCache.clear();

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
  Future<int> paginateFull({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
  }) async {
    try {
      final oldLength = _descriptors?.length ?? 0;
      final PaginateResult result;

      if (_handle != null) {
        final sw = Stopwatch()..start();
        result = await core_api.paginateSessionFull(handle: _handle!);
        Logging.info(
          '[Timing] paginateSessionFull: ${sw.elapsedMilliseconds}ms '
          '(pages=${result.descriptors.length})',
        );
      } else {
        result = await _createSession(
          bookId: bookId,
          chapterIndex: chapterIndex,
          config: _buildConfig(params),
        );
      }

      _applyPaginateResult(result);
      final preloadCount = 5.clamp(0, result.descriptors.length);
      for (int i = oldLength; i < preloadCount; i++) {
        _fetchPageSync(i);
      }
      return result.descriptors.length;
    } catch (e) {
      Logging.error('paginateFull error: $e');
      return 0;
    }
  }

  @override
  Future<({int totalPages, bool isPartial})> paginatePartial({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
  }) async {
    try {
      final result = await _createSession(
        bookId: bookId,
        chapterIndex: chapterIndex,
        config: _buildConfig(params),
        maxChars: PaginationEngine.partialMaxChars,
      );
      _preloadPageRange(5);
      return (
        totalPages: result.descriptors.length,
        isPartial: result.isPartial,
      );
    } catch (e) {
      Logging.error('paginatePartial error: $e');
      return (totalPages: 0, isPartial: false);
    }
  }

  @override
  String? pageContent(int pageIndex) {
    if (_pageCache.containsKey(pageIndex)) {
      return _pageCache[pageIndex];
    }
    if (_approximatePages != null && pageIndex < _approximatePages!.length) {
      return _approximatePages![pageIndex].content;
    }
    return null;
  }

  void _fetchPageSync(int pageIndex) {
    if (_pageCache.containsKey(pageIndex)) return;
    final handle = _handle;
    if (handle == null || _descriptors == null) return;
    if (pageIndex < 0 || pageIndex >= _descriptors!.length) return;

    try {
      final content = core_api.getSessionPageContent(
        handle: handle,
        pageIndex: pageIndex,
      );
      if (content.isNotEmpty) {
        _pageCache[pageIndex] = content;
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

    _pageCache.removeWhere((key, _) => (key - center).abs() > 5);
  }

  @override
  void warmPageCache(int pageIndex, String content) {
    _pageCache[pageIndex] = content;
  }

  @override
  void dispose() {
    _releaseHandle();
    _descriptors = null;
    _approximatePages = null;
    _pageCache.clear();
    _cachedBook = null;
    _cachedBookId = null;
  }
}

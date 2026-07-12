import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/data/epub_block_image_cache.dart';
import 'package:zephyr_reader/features/reader/core/domain/pagination_session.dart';
import 'package:zephyr_reader/features/reader/data/line_break_extractor.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/pagination_progress_hook.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/flutter_block_paginator.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/active_chapter_ir.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/packed_page.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/pagination_staging_store.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/pagination_viewport_metrics.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/domain/types/block_pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// Flutter 精确分页会话（ADR-016）：只拉 IR，本地装箱；不创建 Rust pagination session。
///
/// **T3**：主 isolate 分块 `paginateAsync`（TextPainter 不能进普通 isolate）+
/// generation 取消；`maxChars` 首屏截断后由 [expandToFullChapter] 补全。
class FlutterPaginationSession implements PaginationSession {
  FlutterPaginationSession({this._onCacheUpdated});

  final void Function()? _onCacheUpdated;

  /// expand 过程中推进 UI 总页数（翻页不会卡在首屏页数）。
  /// 优先 [onPaginationProgress]，否则 [paginationProgressHook]。
  void Function(int totalPages, bool isPartial)? onPaginationProgress;

  List<PageDescriptor>? _descriptors;
  final Map<int, String> _pageCache = {};
  final Map<int, List<PageBlockSlice>> _blockCache = {};
  ChapterContentIr? _ir;
  int? _chapterIndex;
  BigInt? _configHash;
  String? _sessionFilePath;
  int _imageMaxWidthPx = 400;
  bool _sessionIsPartial = false;
  int _paginateGen = 0;

  @override
  ChapterPaginationMode get sessionMode => ChapterPaginationMode.contentBlocks;

  @override
  List<PageDescriptor>? get descriptors => _descriptors;

  @override
  BigInt? get sessionConfigHash => _configHash;

  @override
  int? get sessionChapterIndex => _chapterIndex;

  @override
  bool get sessionIsPartial => _sessionIsPartial;

  @override
  String? get sessionFilePath => _sessionFilePath;

  @override
  List<PageBlockSlice>? pageBlocks(int pageIndex) => _blockCache[pageIndex];

  @override
  String? pageContent(int pageIndex) => _pageCache[pageIndex];

  @override
  Future<String?> fetchPageContent(int pageIndex) async =>
      pageContent(pageIndex);

  @override
  Future<({int totalPages, bool isPartial})> beginPaginate({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  }) => _paginateFromIr(
    bookId: bookId,
    chapterIndex: chapterIndex,
    params: params,
    maxChars: maxChars,
  );

  @override
  Future<({int totalPages, bool isPartial})> beginPaginateFromCache({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  }) async {
    final forward = PaginationStagingStore.next?.chapterIndex == chapterIndex;
    final backward = PaginationStagingStore.prev?.chapterIndex == chapterIndex;
    if (forward || backward) {
      final ready = PaginationStagingStore.takeForChapter(
        chapterIndex,
        forward: forward,
      );
      if (ready != null) {
        return installFromReady(ready);
      }
    }
    return beginPaginate(
      bookId: bookId,
      chapterIndex: chapterIndex,
      params: params,
      maxChars: maxChars,
    );
  }

  @override
  Future<({int totalPages, bool isPartial})> repaginateInPlace({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  }) => beginPaginate(
    bookId: bookId,
    chapterIndex: chapterIndex,
    params: params,
    maxChars: maxChars,
  );

  @override
  Future<({int totalPages, bool isPartial})> expandToFullChapter({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
  }) async {
    if (!_sessionIsPartial) {
      final n = _descriptors?.length ?? 0;
      return (totalPages: n, isPartial: false);
    }
    final ir = _ir;
    if (ir == null || _chapterIndex != chapterIndex) {
      return _paginateFromIr(
        bookId: bookId,
        chapterIndex: chapterIndex,
        params: params,
        maxChars: null,
      );
    }
    Logging.info(
      '[FlutterPagination] expandToFullChapter chapter=$chapterIndex '
      '(reuse IR, no re-fetch)',
    );
    return _installPages(
      ir: ir,
      chapterIndex: chapterIndex,
      params: params,
      maxChars: null,
      filePath: _sessionFilePath,
    );
  }

  @override
  void ensureWindow(int centerPage) {
    if (_descriptors == null || _ir == null) return;
    final plain = _ir!.plainText;
    for (var i = centerPage - 2; i <= centerPage + 2; i++) {
      if (i < 0 || i >= _descriptors!.length) continue;
      if (!_pageCache.containsKey(i)) {
        final d = _descriptors![i];
        final end = d.endOffset.clamp(0, plain.length);
        final start = d.startOffset.clamp(0, end);
        _pageCache[i] = plain.substring(start, end);
      }
      final blocks = _blockCache[i];
      if (blocks != null) {
        _prefetchBlockImages(blocks);
      }
    }
  }

  @override
  void warmPageCache(int pageIndex, String content) {
    _pageCache[pageIndex] = content;
  }

  @override
  int? resolvePageIndexForCharOffset(int charOffset) {
    final descriptors = _descriptors;
    if (descriptors == null || descriptors.isEmpty) return null;
    return PaginationEngine.resolvePageIndexForOffset(descriptors, charOffset);
  }

  @override
  void dispose() {
    _paginateGen++;
    _descriptors = null;
    _pageCache.clear();
    _blockCache.clear();
    _ir = null;
    _chapterIndex = null;
    _configHash = null;
    _sessionFilePath = null;
    _sessionIsPartial = false;
    ActiveChapterIr.clear();
    epubBlockImageCache.clear();
  }

  Future<Book> _getBook(String bookId) async {
    final book = await book_api.getBook(bookId: bookId);
    if (book == null) {
      throw Exception('SpikeSession: book not found for bookId=$bookId');
    }
    return book;
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

  Future<({int totalPages, bool isPartial})> _paginateFromIr({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  }) async {
    Logging.info(
      '[FlutterPagination] paginate book=$bookId chapter=$chapterIndex '
      'maxChars=${maxChars ?? "full"} (no Rust pagination FFI)',
    );

    final book = await _getBook(bookId);
    if (book.filePath.isEmpty) {
      throw Exception('SpikeSession: book not found for bookId=$bookId');
    }
    _sessionFilePath = book.filePath;
    _imageMaxWidthPx = (params.width - 2 * params.padding).round().clamp(
      1,
      4096,
    );
    epubBlockImageCache.clear();

    final ir = await core_api.getChapterContentIr(
      bookId: bookId,
      chapterIndex: chapterIndex,
    );

    return _installPages(
      ir: ir,
      chapterIndex: chapterIndex,
      params: params,
      maxChars: maxChars,
      filePath: book.filePath,
    );
  }

  Future<({int totalPages, bool isPartial})> _installPages({
    required ChapterContentIr ir,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
    String? filePath,
  }) async {
    final gen = ++_paginateGen;
    final contentWidth =
        (PaginationViewportMetrics.contentWidthDp ??
                (params.width - 2 * params.padding))
            .clamp(1.0, 4096.0);
    final vPad = ReaderRenderConfig.pageContentVerticalPadding;
    final estimatedHeight = (params.height - 2 * vPad).clamp(1.0, 8192.0);
    // 实测 body 高度不得被 params.height 截断——估矮时正是底空来源。
    final measured = PaginationViewportMetrics.contentHeightDp;
    final contentHeight = (measured ?? estimatedHeight).clamp(1.0, 8192.0);
    Logging.info(
      '[FlutterPagination] pack body '
      '${contentWidth.toStringAsFixed(0)}x${contentHeight.toStringAsFixed(0)} '
      'measured=${measured?.toStringAsFixed(0) ?? "null"} '
      'estH=${estimatedHeight.toStringAsFixed(0)} '
      'paramsH=${params.height.toStringAsFixed(0)}',
    );

    final renderConfig = lineBreakMeasureRenderConfig(
      fontSize: params.fontSize,
      lineHeight: params.lineHeight,
      fontFamily: params.fontFamily,
      letterSpacing: params.letterSpacing,
      paragraphSpacing: params.paragraphSpacing,
      pageMargin: params.padding,
      firstLineIndent: params.firstLineIndent,
      baselineAlign: true,
    );

    late final FlutterPaginateOutcome outcome;
    try {
      outcome = await FlutterBlockPaginator.paginateAsync(
        ir,
        config: renderConfig,
        contentWidthDp: contentWidth,
        contentHeightDp: contentHeight,
        stopAfterPlainOffset: maxChars?.toInt(),
        isCancelled: () => gen != _paginateGen,
        onProgress: maxChars == null
            ? (pages, partial) {
                if (gen != _paginateGen) return;
                _sessionIsPartial = partial;
                _applyPages(pages);
                ensureWindow(0);
                _onCacheUpdated?.call();
                onPaginationProgress?.call(pages.length, partial);
                paginationProgressHook?.call(pages.length, partial);
              }
            : null,
      );
    } on PaginationCancelledException {
      Logging.info('[FlutterPagination] paginate cancelled gen=$gen');
      return (
        totalPages: _descriptors?.length ?? 0,
        isPartial: _sessionIsPartial,
      );
    }

    if (gen != _paginateGen) {
      return (
        totalPages: _descriptors?.length ?? 0,
        isPartial: _sessionIsPartial,
      );
    }

    _chapterIndex = chapterIndex;
    _ir = ir;
    ActiveChapterIr.set(ir);
    _configHash = BigInt.zero;
    if (filePath != null) _sessionFilePath = filePath;
    _sessionIsPartial = outcome.isPartial;
    _applyPages(outcome.pages);
    ensureWindow(0);
    _onCacheUpdated?.call();

    Logging.info(
      '[FlutterPagination] done pages=${outcome.pages.length} '
      'partial=${outcome.isPartial} '
      'plainLen=${ir.plainText.length} blocks=${ir.blocks.length} '
      'body=${contentWidth.toStringAsFixed(0)}x${contentHeight.toStringAsFixed(0)}',
    );
    return (totalPages: outcome.pages.length, isPartial: outcome.isPartial);
  }

  void _applyPages(List<PackedPage> pages) {
    _descriptors = [
      for (final p in pages)
        PageDescriptor(
          pageIndex: p.pageIndex,
          startOffset: p.startOffset,
          endOffset: p.endOffset,
          firstParagraphIndex: 0,
          lastParagraphIndex: 0,
          isLastPage: p.isLastPage,
        ),
    ];
    _pageCache.clear();
    _blockCache
      ..clear()
      ..addEntries(
        pages.map((p) => MapEntry(p.pageIndex, slicesToPageBlocks(p.slices))),
      );
  }

  /// 从精确预装箱结果安装 session（staging promote，零重装箱）。
  ({int totalPages, bool isPartial}) installFromReady(
    PaginationChapterReady ready,
  ) {
    Logging.info(
      '[FlutterPagination] installFromReady chapter=${ready.chapterIndex} '
      'pages=${ready.pages.length}',
    );
    _paginateGen++;
    _chapterIndex = ready.chapterIndex;
    _ir = ready.ir;
    ActiveChapterIr.set(ready.ir);
    _sessionFilePath = ready.filePath;
    _configHash = BigInt.zero;
    _sessionIsPartial = false;
    _imageMaxWidthPx = ready.contentWidthDp.round().clamp(1, 4096);
    _applyPages(ready.pages);
    ensureWindow(0);
    _onCacheUpdated?.call();
    return (totalPages: ready.pages.length, isPartial: false);
  }

  static List<PageBlockSlice> slicesToPageBlocks(
    List<PackedBlockSlice> slices,
  ) {
    return [
      for (final s in slices)
        if (s.isImage)
          PageBlockSlice.image(
            PageImageBlockSlice(
              blockIndex: s.blockIndex,
              assetId: s.assetId ?? '',
              layout: s.imageLayout ?? ImageBlockLayout.inlineContain,
              alt: s.alt,
            ),
          )
        else
          PageBlockSlice.text(
            PageTextBlockSlice(
              blockIndex: s.blockIndex,
              text: s.text,
              isBlockStart: s.isBlockStart,
              isBlockEnd: s.isBlockEnd,
              style:
                  s.style ??
                  const TextBlockStyle(isHeading: false, headingLevel: 0),
              spans: s.spans,
            ),
          ),
    ];
  }
}

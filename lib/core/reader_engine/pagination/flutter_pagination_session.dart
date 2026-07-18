import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_key.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_snapshot.dart';
import 'package:zephyr_reader/core/reader_engine/layout/block_layout.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_spec.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/page_plan.dart'
    show PageFragment, PagePlan;
import 'package:zephyr_reader/core/reader_engine/rendering/image_cache.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/line_break_extractor.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/engine_utils.dart';
import 'package:zephyr_reader/core/reader_engine/shared/pagination_params.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/flutter_block_paginator.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/pagination_staging_store.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/pagination_viewport_metrics.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/api/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/reader.dart' as reader_api;
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';
import 'package:zephyr_reader/src/rust/domain/book/models.dart';

class PaginationSession {
  PaginationSession({this._onCacheUpdated});

  final void Function()? _onCacheUpdated;

  // ── 原子状态（Phase 5+6）──
  LayoutSnapshot? _layoutSnapshot;

  // ── 上下文（不参与布局状态）──
  int? _chapterIndex;
  String? _sessionFilePath;
  int _imageMaxWidthPx = 400;
  int _paginateGen = 0;

  LayoutSnapshot? get layoutSnapshot => _layoutSnapshot;

  /// 底层页面快照列表（PagePlan）。
  List<PagePlan>? get pagePlans => _layoutSnapshot?.pages;
  BigInt? get sessionConfigHash => _layoutSnapshot?.key.hash;
  int? get sessionChapterIndex => _chapterIndex;
  bool get sessionIsPartial =>
      _layoutSnapshot == null ? false : !_layoutSnapshot!.isComplete;
  String? get sessionFilePath => _sessionFilePath;

  PagePlan? pagePlan(int pageIndex) {
    final pages = _layoutSnapshot?.pages;
    if (pages == null || pageIndex < 0 || pageIndex >= pages.length) {
      return null;
    }
    return pages[pageIndex];
  }

  String? pageContent(int pageIndex) {
    final snapshot = _layoutSnapshot;
    if (snapshot == null || pageIndex >= snapshot.pages.length) {
      return null;
    }
    final p = snapshot.pages[pageIndex];
    return snapshot.chapter.plainText.substring(
      p.startUtf16.clamp(0, snapshot.chapter.plainText.length),
      p.endUtf16.clamp(0, snapshot.chapter.plainText.length),
    );
  }

  Future<String?> fetchPageContent(int pageIndex) async =>
      pageContent(pageIndex);

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
        bookId: bookId,
        configHash: layoutKeyForPaginationParams(params).hash,
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

  Future<({int totalPages, bool isPartial})> repaginateInPlace({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  }) async {
    final ir = _layoutSnapshot?.chapter;
    if (ir != null && _chapterIndex == chapterIndex) {
      Logging.info(
        '[FlutterPagination] repaginateInPlace chapter=$chapterIndex '
        '(reuse IR, skip FFI)',
      );
      return _installPages(
        ir: ir,
        chapterIndex: chapterIndex,
        params: params,
        maxChars: maxChars,
        filePath: _sessionFilePath,
      );
    }
    return beginPaginate(
      bookId: bookId,
      chapterIndex: chapterIndex,
      params: params,
      maxChars: maxChars,
    );
  }

  Future<({int totalPages, bool isPartial})> expandToFullChapter({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    void Function(int totalPages, bool isPartial)? onProgress,
  }) async {
    if (!sessionIsPartial) {
      final n = pagePlans?.length ?? 0;
      return (totalPages: n, isPartial: false);
    }
    final ir = _layoutSnapshot?.chapter;
    if (ir == null || _chapterIndex != chapterIndex) {
      return _paginateFromIr(
        bookId: bookId,
        chapterIndex: chapterIndex,
        params: params,
        maxChars: null,
        onProgress: onProgress,
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
      onProgress: onProgress,
    );
  }

  void ensureWindow(int centerPage) {
    final snapshot = _layoutSnapshot;
    if (snapshot == null) return;
    final pages = snapshot.pages;
    for (var i = centerPage - 2; i <= centerPage + 2; i++) {
      if (i < 0 || i >= pages.length) continue;
      final page = pages[i];
      final fragments = page.fragments;
      if (fragments.any((f) => f.isImage)) {
        _prefetchBlockImages(fragments);
      }
    }
  }

  int? resolvePageIndexForCharOffset(int charOffset) {
    final pages = _layoutSnapshot?.pages;
    if (pages == null || pages.isEmpty) return null;
    return PaginationUtils.resolvePageIndexForPagePlan(pages, charOffset);
  }

  void dispose() {
    _paginateGen++;
    _layoutSnapshot = null;
    _chapterIndex = null;
    _sessionFilePath = null;
    _imageMaxWidthPx = 400;
    epubBlockImageCache.clear();
  }

  Future<Book> _getBook(String bookId) async {
    final book = await book_api.getBook(bookId: bookId);
    if (book == null) {
      throw Exception(
        'FlutterPaginationSession: book not found for bookId=$bookId',
      );
    }
    return book;
  }

  void _prefetchBlockImages(List<PageFragment> fragments) {
    final path = _sessionFilePath;
    if (path == null || path.isEmpty) return;
    epubBlockImageCache.prefetchBlocks(
      filePath: path,
      fragments: fragments,
      maxWidthPx: _imageMaxWidthPx,
    );
  }

  Future<({int totalPages, bool isPartial})> _paginateFromIr({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
    void Function(int totalPages, bool isPartial)? onProgress,
  }) async {
    Logging.info(
      '[FlutterPagination] paginate book=$bookId chapter=$chapterIndex '
      'maxChars=${maxChars ?? "full"} (no Rust pagination FFI)',
    );

    final book = await _getBook(bookId);
    if (book.filePath.isEmpty) {
      throw Exception(
        'FlutterPaginationSession: book not found for bookId=$bookId',
      );
    }
    _sessionFilePath = book.filePath;
    _imageMaxWidthPx = (params.width - 2 * params.padding).round().clamp(
      1,
      4096,
    );
    epubBlockImageCache.clear();

    final frbIr = await reader_api.getChapterContentIr(
      bookId: bookId,
      chapterIndex: chapterIndex,
    );
    final ir = frbIr;

    return _installPages(
      ir: ir,
      chapterIndex: chapterIndex,
      params: params,
      maxChars: maxChars,
      filePath: book.filePath,
      onProgress: onProgress,
    );
  }

  Future<({int totalPages, bool isPartial})> _installPages({
    required ReaderChapterIr ir,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
    String? filePath,
    void Function(int totalPages, bool isPartial)? onProgress,
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
      baselineAlign: params.baselineAlign,
      textScaler: params.textScaler,
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
            ? (pages, blocks, spec, partial) {
                if (gen != _paginateGen) return;
                _applySnapshot(
                  chapterIndex: chapterIndex,
                  spec: spec,
                  ir: ir,
                  pages: pages,
                  blocks: blocks,
                  isPartial: partial,
                  filePath: filePath,
                );
                ensureWindow(0);
                _onCacheUpdated?.call();
                onProgress?.call(pages.length, partial);
              }
            : null,
      );
    } on PaginationCancelledException {
      Logging.info('[FlutterPagination] paginate cancelled gen=$gen');
      return (
        totalPages: pagePlans?.length ?? 0,
        isPartial: sessionIsPartial,
      );
    }

    if (gen != _paginateGen) {
      return (
        totalPages: pagePlans?.length ?? 0,
        isPartial: sessionIsPartial,
      );
    }

    _applySnapshot(
      chapterIndex: chapterIndex,
      spec: outcome.spec,
      ir: ir,
      pages: outcome.pages,
      blocks: outcome.blocks,
      isPartial: outcome.isPartial,
      filePath: filePath,
    );
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

  void _applySnapshot({
    required int chapterIndex,
    required LayoutSpec spec,
    required ReaderChapterIr ir,
    required List<PagePlan> pages,
    required List<BlockLayout> blocks,
    required bool isPartial,
    String? filePath,
  }) {
    final key = LayoutKey.fromSpec(spec);
    _layoutSnapshot = LayoutSnapshot(
      generation: _paginateGen,
      key: key,
      spec: spec,
      chapter: ir,
      pages: pages,
      blocks: blocks,
      isComplete: !isPartial,
    );
    _chapterIndex = chapterIndex;
    if (filePath != null) _sessionFilePath = filePath;
  }

  ({int totalPages, bool isPartial}) installFromReady(
    PaginationChapterReady ready,
  ) {
    Logging.info(
      '[FlutterPagination] installFromReady chapter=${ready.chapterIndex} '
      'pages=${ready.pages.length}',
    );
    _paginateGen++;
    _imageMaxWidthPx = ready.contentWidthDp.round().clamp(1, 4096);
    _applySnapshot(
      chapterIndex: ready.chapterIndex,
      spec: ready.spec,
      ir: ready.ir,
      pages: ready.pages,
      blocks: ready.blocks,
      isPartial: false,
      filePath: ready.filePath,
    );
    ensureWindow(0);
    _onCacheUpdated?.call();
    return (totalPages: ready.pages.length, isPartial: false);
  }
}

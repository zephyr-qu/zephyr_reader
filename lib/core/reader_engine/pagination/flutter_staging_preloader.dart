import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/core/reader_engine/layout/block_layout.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_key.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_spec.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/image_cache.dart';
import 'package:zephyr_reader/core/reader_engine/shared/next_chapter_staging.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/line_break_extractor.dart';
import 'package:zephyr_reader/core/reader_engine/shared/pagination_params.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/flutter_block_paginator.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/page_plan.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/pagination_staging_store.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/pagination_viewport_metrics.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/api/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/reader.dart' as reader_api;

/// 方案三 T2：用与当前章相同的 Flutter 装箱算法预取相邻章。
abstract final class FlutterStagingPreloader {
  static Future<NextChapterStaging?> preload({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    required bool forNext,
  }) async {
    final gen = PaginationStagingStore.generation;
    final sw = Stopwatch()..start();
    try {
      final book = await book_api.getBook(bookId: bookId);
      if (book == null || book.filePath.isEmpty) return null;

      final frbIr = await reader_api.getChapterContentIr(
        bookId: bookId,
        chapterIndex: chapterIndex,
      );
      final ir = frbIr;
      if (!PaginationStagingStore.isCurrent(gen)) return null;

      final contentWidth =
          (PaginationViewportMetrics.contentWidthDp ??
                  (params.width - 2 * params.padding))
              .clamp(1.0, 4096.0);
      final vPad = ReaderRenderConfig.pageContentVerticalPadding;
      final estimatedHeight = (params.height - 2 * vPad).clamp(1.0, 8192.0);
      final measured = PaginationViewportMetrics.contentHeightDp;
      final contentHeight = (measured ?? estimatedHeight).clamp(1.0, 8192.0);
      final imageMaxWidthPx = contentWidth.round().clamp(1, 4096);
      final config = lineBreakMeasureRenderConfig(
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

      late final List<PagePlan> pages;
      late final List<BlockLayout> blocks;
      late final LayoutSpec spec;
      try {
        final outcome = await FlutterBlockPaginator.paginateAsync(
          ir,
          config: config,
          contentWidthDp: contentWidth,
          contentHeightDp: contentHeight,
          isCancelled: () => !PaginationStagingStore.isCurrent(gen),
        );
        pages = outcome.pages;
        blocks = outcome.blocks;
        spec = outcome.spec;
      } on PaginationCancelledException {
        return null;
      }
      if (!PaginationStagingStore.isCurrent(gen) || pages.isEmpty) return null;

      // 预解码首/末附近页图片，promote 后翻页少骨架。
      final prefetchPages = forNext
          ? pages.take(3)
          : pages.reversed.take(3).toList().reversed;
      final prefetchFragments = <PageFragment>[];
      for (final p in prefetchPages) {
        prefetchFragments.addAll(p.fragments.where((f) => f.isImage));
      }
      if (prefetchFragments.isNotEmpty) {
        epubBlockImageCache.prefetchBlocks(
          filePath: book.filePath,
          fragments: prefetchFragments,
          maxWidthPx: imageMaxWidthPx,
        );
      }

      final ready = PaginationChapterReady(
        bookId: bookId,
        chapterIndex: chapterIndex,
        filePath: book.filePath,
        ir: ir,
        pages: pages,
        blocks: blocks,
        spec: spec,
        contentWidthDp: contentWidth,
        contentHeightDp: contentHeight,
        configHash: LayoutKey.fromSpec(spec).hash,
      );
      if (forNext) {
        PaginationStagingStore.next = ready;
      } else {
        PaginationStagingStore.prev = ready;
      }

      final anchorIndex = forNext ? 0 : pages.length - 1;
      final staging = _toNextChapterStaging(ready, anchorIndex);
      Logging.info(
        '[FlutterStaging] preload ${forNext ? "next" : "prev"} '
        'chapter=$chapterIndex pages=${pages.length} '
        'body=${contentWidth.toStringAsFixed(0)}x${contentHeight.toStringAsFixed(0)} '
        '${sw.elapsedMilliseconds}ms',
      );
      return staging;
    } catch (e) {
      Logging.debug('[FlutterStaging] preload failed: $e');
      return null;
    }
  }

  static NextChapterStaging _toNextChapterStaging(
    PaginationChapterReady ready,
    int anchorIndex,
  ) {
    final pages = ready.pages;
    final anchor = pages[anchorIndex.clamp(0, pages.length - 1)];
    final plain = ready.ir.plainText;
    final end = anchor.endUtf16.clamp(0, plain.length);
    final start = anchor.startUtf16.clamp(0, end);
    return NextChapterStaging(
      chapterIndex: ready.chapterIndex,
      configHash: ready.configHash,
      pagePlans: pages,
      firstPageContent: plain.substring(start, end),
      isPartial: false,
      bookId: ready.bookId,
      anchorPagePlan: anchor,
      spec: ready.spec,
    );
  }
}

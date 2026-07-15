import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/data/epub_block_image_cache.dart';
import 'package:zephyr_reader/features/reader/core/data/next_chapter_staging.dart';
import 'package:zephyr_reader/features/reader/data/line_break_extractor.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/flutter_block_paginator.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/packed_page.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/pagination_staging_store.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/pagination_viewport_metrics.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
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

      final ir = await reader_api.getChapterContentIr(
        bookId: bookId,
        chapterIndex: chapterIndex,
      );
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
        baselineAlign: true,
      );

      late final List<PackedPage> pages;
      try {
        final outcome = await FlutterBlockPaginator.paginateAsync(
          ir,
          config: config,
          contentWidthDp: contentWidth,
          contentHeightDp: contentHeight,
          isCancelled: () => !PaginationStagingStore.isCurrent(gen),
        );
        pages = outcome.pages;
      } on PaginationCancelledException {
        return null;
      }
      if (!PaginationStagingStore.isCurrent(gen) || pages.isEmpty) return null;

      // 预解码首/末附近页图片，promote 后翻页少骨架。
      final prefetchPages = forNext
          ? pages.take(3)
          : pages.reversed.take(3).toList().reversed;
      for (final p in prefetchPages) {
        epubBlockImageCache.prefetchBlocks(
          filePath: book.filePath,
          blocks: p.slices,
          maxWidthPx: imageMaxWidthPx,
        );
      }

      final ready = PaginationChapterReady(
        bookId: bookId,
        chapterIndex: chapterIndex,
        filePath: book.filePath,
        ir: ir,
        pages: pages,
        contentWidthDp: contentWidth,
        contentHeightDp: contentHeight,
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
    final end = anchor.endOffset.clamp(0, plain.length);
    final start = anchor.startOffset.clamp(0, end);
    return NextChapterStaging(
      chapterIndex: ready.chapterIndex,
      configHash: BigInt.zero,
      descriptors: pages,
      firstPageContent: plain.substring(start, end),
      isPartial: false,
      paginationMode: ChapterPaginationMode.contentBlocks,
      bookId: ready.bookId,
      anchorPageBlocks: anchor.slices,
    );
  }
}

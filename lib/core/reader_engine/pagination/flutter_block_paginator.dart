import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:zephyr_reader/core/reader_engine/layout/block_layout.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_spec.dart';
import 'package:zephyr_reader/core/reader_engine/layout/paragraph_layouter.dart';
import 'package:zephyr_reader/core/reader_engine/layout/span_factory.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/page_packer.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/page_plan.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/slice_rich_spans.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/ir_text_block_style.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';

/// 无 intrinsic 时图片高度 = 内容宽 × 此比（与 Rust `DEFAULT_IMAGE_HEIGHT_RATIO` 对齐）。
const kDefaultImageHeightRatio = 0.55;

/// 内联图上下 padding（与 [EpubBlockImage] `EdgeInsets.symmetric(vertical: 4)` 对齐）。
const kInlineImageVerticalPaddingDp = 8.0;

/// 单次 TextPainter 断行上限：大单块 TXT 必须切窗。
const kLineBreakChunkChars = 4000;

/// Phase 6: 真实 line height 已消除估算误差，余量设为 0。

@visibleForTesting
int utf16SafeChunkEnd(String text, int proposedEnd) {
  var end = proposedEnd.clamp(0, text.length);
  if (end > 0 && end < text.length) {
    final previous = text.codeUnitAt(end - 1);
    final current = text.codeUnitAt(end);
    final splitsSurrogatePair =
        previous >= 0xD800 &&
        previous <= 0xDBFF &&
        current >= 0xDC00 &&
        current <= 0xDFFF;
    if (splitsSurrogatePair) end--;
  }
  return end;
}

@visibleForTesting
int utf16SafeStopEnd(String text, int proposedEnd) {
  final end = proposedEnd.clamp(0, text.length);
  final safeBefore = utf16SafeChunkEnd(text, end);
  if (safeBefore == end) return end;
  return (end + 1).clamp(0, text.length);
}

@visibleForTesting
int textBlockChunkEnd(String text, int start) {
  final proposed = utf16SafeChunkEnd(text, start + kLineBreakChunkChars);
  if (proposed >= text.length) return text.length;

  final previousNewline = text.lastIndexOf('\n', proposed);
  if (previousNewline > start) return previousNewline + 1;

  // TextPainter 把每个输入末尾视作真实行尾；不能在段落中间硬切，
  // 否则下一 chunk 会凭空多出一行。没有前向换行时延长到下一个换行。
  final nextNewline = text.indexOf('\n', proposed);
  return nextNewline < 0 ? text.length : nextNewline + 1;
}

/// 装箱被 generation 取消。
final class PaginationCancelledException implements Exception {
  const PaginationCancelledException();

  @override
  String toString() => 'PaginationCancelledException';
}

/// [FlutterBlockPaginator.paginateAsync] 结果（Phase 6: 原生 PagePlan）。
class FlutterPaginateOutcome {
  const FlutterPaginateOutcome({
    required this.pages,
    required this.blocks,
    required this.spec,
    required this.isPartial,
  });

  final List<PagePlan> pages;
  final List<BlockLayout> blocks;
  final LayoutSpec spec;
  final bool isPartial;
}

/// 图片在正文宽下的显示高度（逻辑 dp）。
double imageDisplayHeightDp({
  required double contentWidthDp,
  int? intrinsicWidth,
  int? intrinsicHeight,
}) {
  final w = contentWidthDp.clamp(1.0, 4096.0);
  if (intrinsicWidth != null &&
      intrinsicHeight != null &&
      intrinsicWidth > 0 &&
      intrinsicHeight > 0) {
    final scale = (w / intrinsicWidth).clamp(0.0, 1.0);
    return intrinsicHeight * scale;
  }
  return w * kDefaultImageHeightRatio;
}

/// Flutter 侧页装箱（方案三）。
///
/// Phase 6: 使用 [ParagraphLayouter] + [PagePacker]，原生输出 [PagePlan]。
abstract final class FlutterBlockPaginator {
  /// 同步装箱（单测 / 小章）。
  static List<PagePlan> paginate(
    ReaderChapterIr ir, {
    required ReaderRenderConfig config,
    required double contentWidthDp,
    required double contentHeightDp,
    int? stopAfterPlainOffset,
  }) {
    final maxW = contentWidthDp.clamp(1.0, 4096.0);
    final maxH = contentHeightDp.clamp(1.0, 8192.0);
    if (ir.plainText.isEmpty && ir.blocks.isEmpty) {
      return const [
        PagePlan(
          pageIndex: 0,
          startUtf16: 0,
          endUtf16: 0,
          fragments: <PageFragment>[],
          isLastPage: true,
        ),
      ];
    }
    final blocks = _resolveBlocks(ir);
    final spec = _toLayoutSpec(config, maxW, maxH);
    final blockLayouts = _layoutBlocks(blocks, spec, maxW, config);
    return PagePacker.pack(
      blocks: blockLayouts,
      spec: spec,
      maxHeight: maxH,
      chapterPlainText: ir.plainText,
      irBlocks: blocks,
    );
  }

  /// 异步分块装箱；大块按 [kLineBreakChunkChars] 切窗并 yield。
  static Future<FlutterPaginateOutcome> paginateAsync(
    ReaderChapterIr ir, {
    required ReaderRenderConfig config,
    required double contentWidthDp,
    required double contentHeightDp,
    bool Function()? isCancelled,
    int yieldEveryChunks = 1,
    int? stopAfterPlainOffset,
    void Function(
      List<PagePlan> pagesSoFar,
      List<BlockLayout> blocksSoFar,
      LayoutSpec spec,
      bool isPartial,
    )?
    onProgress,
  }) async {
    void checkCancel() {
      if (isCancelled?.call() == true) {
        throw const PaginationCancelledException();
      }
    }

    checkCancel();
    final maxW = contentWidthDp.clamp(1.0, 4096.0);
    final maxH = contentHeightDp.clamp(1.0, 8192.0);
    final spec = _toLayoutSpec(config, maxW, maxH);

    if (ir.plainText.isEmpty && ir.blocks.isEmpty) {
      return FlutterPaginateOutcome(
        pages: const [
          PagePlan(
            pageIndex: 0,
            startUtf16: 0,
            endUtf16: 0,
            fragments: <PageFragment>[],
            isLastPage: true,
          ),
        ],
        blocks: const <BlockLayout>[],
        spec: spec,
        isPartial: false,
      );
    }

    final blocks = _resolveBlocks(ir);
    final packer = PagePacker(spec: spec, maxHeight: maxH);
    final blockLayouts = <BlockLayout>[];

    void report() {
      if (onProgress == null) return;
      // Non-destructive snapshot — does not mutate packer state.
      final pagesSnapshot = packer.snapshotPages(isPartial: true);
      onProgress(pagesSnapshot, List.unmodifiable(blockLayouts), spec, true);
    }

    var lastEmittedPageCount = 0;
    var isStopped = false;

    for (var i = 0; i < blocks.length && !isStopped; i++) {
      checkCancel();
      final block = blocks[i];

      if (block.kind == ReaderIrBlockKind.text) {
        final indentPx = IrReaderIrBlock.resolveFirstLineIndentPx(
          block.style,
          config,
        );
        final spanFactory = SpanFactory(spec);
        final layouter = ParagraphLayouter(spanFactory, spec);

        var chunkFrom = 0;
        var chunkOrdinal = 0;
        while (chunkFrom < block.text.length && !isStopped) {
          final chunkTo = textBlockChunkEnd(block.text, chunkFrom);
          final chunk = block.text.substring(chunkFrom, chunkTo);
          final chunkRuns = sliceRichSpans(
            block.runs,
            start: chunkFrom,
            len: chunk.length,
          );

          final layout = layouter.layoutTextBlock(
            blockIndex: i,
            text: chunk,
            spans: chunkRuns,
            style: block.style,
            maxWidth: maxW,
            firstLineIndentPx: chunkFrom == 0 ? indentPx : 0.0,
          );
          blockLayouts.add(layout);
          // Pass chunk-start offset so PagePacker computes correct chapter offsets
          final stopped = packer.appendTextBlock(
            block: layout,
            blockText: chunk,
            blockRuns: chunkRuns,
            blockPlainStart: block.plainStart + chunkFrom,
            blockStyle: block.style,
            startsBlock: chunkFrom == 0,
            endsBlock: chunkTo == block.text.length,
            stopAfterPlainOffset: stopAfterPlainOffset,
          );

          chunkFrom = chunkTo;
          chunkOrdinal++;

          if (stopped) {
            isStopped = true;
            break;
          }

          if (chunkFrom < block.text.length) {
            final em = packer.emittedPageCount;
            if (em - lastEmittedPageCount >= 2) {
              lastEmittedPageCount = em;
              report();
            }
            if (yieldEveryChunks > 0 && chunkOrdinal % yieldEveryChunks == 0) {
              await Future<void>.delayed(Duration.zero);
              checkCancel();
            }
          }
        }
      } else {
        final imgH = PagePacker.imageDisplayHeight(
          contentWidthDp: maxW,
          intrinsicWidth: block.imageIntrinsicWidth,
          intrinsicHeight: block.imageIntrinsicHeight,
        );
        final imageLayout = BlockLayout(
          blockIndex: i,
          startUtf16: block.plainStart,
          endUtf16: block.plainStart + block.plainLen,
          lines: const <LineLayout>[],
          isImage: true,
          assetId: block.imageAssetId ?? '',
          imageAlt: block.imageAlt,
          intrinsicWidth: block.imageIntrinsicWidth,
          intrinsicHeight: block.imageIntrinsicHeight,
        );
        blockLayouts.add(imageLayout);
        final stopped = packer.appendImageBlock(
          block: imageLayout,
          blockPlainStart: block.plainStart,
          displayHeight: imgH,
          assetId: block.imageAssetId ?? '',
          imageAlt: block.imageAlt,
          intrinsicWidth: block.imageIntrinsicWidth,
          intrinsicHeight: block.imageIntrinsicHeight,
          stopAfterPlainOffset: stopAfterPlainOffset,
        );

        if (stopped) {
          isStopped = true;
        }
      }
    }

    final pages = packer.finish(isPartial: isStopped);
    onProgress?.call(pages, List.unmodifiable(blockLayouts), spec, isStopped);
    return FlutterPaginateOutcome(
      pages: pages,
      blocks: List.unmodifiable(blockLayouts),
      spec: spec,
      isPartial: isStopped,
    );
  }

  static List<ReaderIrBlock> _resolveBlocks(ReaderChapterIr ir) {
    if (ir.blocks.isNotEmpty) return ir.blocks;
    return [
      ReaderIrBlock(
        kind: ReaderIrBlockKind.text,
        plainStart: 0,
        plainLen: ir.plainText.length,
        text: ir.plainText,
        runs: const [],
        style: const BlockStyle(isHeading: false, headingLevel: 0),
        imageAssetId: null,
        imageAlt: null,
        imageIntrinsicWidth: null,
        imageIntrinsicHeight: null,
      ),
    ];
  }

  static LayoutSpec _toLayoutSpec(
    ReaderRenderConfig config,
    double maxW,
    double maxH,
  ) {
    return LayoutSpec.fromRenderConfig(
      config,
      viewportWidth: maxW + 2 * config.pageMargin,
      viewportHeight: maxH + 2 * ReaderRenderConfig.pageContentVerticalPadding,
    );
  }

  /// Layout all blocks into BlockLayouts (for sync path).
  static List<BlockLayout> _layoutBlocks(
    List<ReaderIrBlock> blocks,
    LayoutSpec spec,
    double maxW,
    ReaderRenderConfig config,
  ) {
    final spanFactory = SpanFactory(spec);
    final layouter = ParagraphLayouter(spanFactory, spec);
    final out = <BlockLayout>[];

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.kind == ReaderIrBlockKind.text) {
        final indentPx = IrReaderIrBlock.resolveFirstLineIndentPx(
          block.style,
          config,
        );
        out.add(
          layouter.layoutTextBlock(
            blockIndex: i,
            text: block.text,
            spans: block.runs,
            style: block.style,
            maxWidth: maxW,
            firstLineIndentPx: indentPx,
            plainStart: block.plainStart,
          ),
        );
      } else {
        final imgH = PagePacker.imageDisplayHeight(
          contentWidthDp: maxW,
          intrinsicWidth: block.imageIntrinsicWidth,
          intrinsicHeight: block.imageIntrinsicHeight,
        );
        out.add(
          layouter.layoutImageBlock(
            blockIndex: i,
            startUtf16: block.plainStart,
            endUtf16: block.plainStart + block.plainLen,
            assetId: block.imageAssetId ?? '',
            imageAlt: block.imageAlt,
            intrinsicWidth: block.imageIntrinsicWidth,
            intrinsicHeight: block.imageIntrinsicHeight,
            imageDisplayWidth: maxW,
            imageDisplayHeight: imgH,
            isFullPage: imgH > (spec.contentHeight),
          ),
        );
      }
    }
    return out;
  }
}

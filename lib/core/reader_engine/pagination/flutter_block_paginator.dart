import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_spec.dart';
import 'package:zephyr_reader/core/reader_engine/layout/paragraph_layouter.dart';
import 'package:zephyr_reader/core/reader_engine/layout/span_factory.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/ir_text_block_style.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/slice_rich_spans.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/packed_page.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';
import 'package:zephyr_reader/src/rust/pipeline/types.dart' show BlockStyle;

/// 无 intrinsic 时图片高度 = 内容宽 × 此比（与 Rust `DEFAULT_IMAGE_HEIGHT_RATIO` 对齐）。
const kDefaultImageHeightRatio = 0.55;

/// 内联图上下 padding（与 [EpubBlockImage] `EdgeInsets.symmetric(vertical: 4)` 对齐）。
const kInlineImageVerticalPaddingDp = 8.0;

/// 单次 TextPainter 断行上限：大单块 TXT 必须切窗。
const kLineBreakChunkChars = 4000;

/// 页底保守余量：仅吸收残余子像素差异 + 图片 inline padding 舍入，非 heading 补偿。
/// heading 高度误差已由 _strutLineH 的 blockFontSize 修复消除。
const kPagePackBottomSlackDp = 8.0;

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

/// [FlutterBlockPaginator.paginateAsync] 结果。
class FlutterPaginateOutcome {
  const FlutterPaginateOutcome({required this.pages, required this.isPartial});

  final List<PackedPage> pages;
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
abstract final class FlutterBlockPaginator {
  /// 同步装箱（单测 / 小章）。
  static List<PackedPage> paginate(
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
        PackedPage(
          pageIndex: 0,
          startOffset: 0,
          endOffset: 0,
          slices: [],
          isLastPage: true,
        ),
      ];
    }

    final blocks = _resolveBlocks(ir);
    final packer = _PagePacker(
      maxHeight: maxH,
      config: config,
      stopAfterPlainOffset: stopAfterPlainOffset,
    );

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final stop = block.kind == ReaderIrBlockKind.text
          ? packer.packTextSync(blockIndex: i, block: block, maxWidth: maxW)
          : packer.packImage(blockIndex: i, block: block, maxWidth: maxW);
      if (stop) break;
      if (stopAfterPlainOffset != null &&
          packer.plainEnd >= stopAfterPlainOffset &&
          packer.hasEmittedPages &&
          i + 1 < blocks.length) {
        packer.stoppedEarly = true;
        break;
      }
    }
    return packer.finish(forcePartial: packer.stoppedEarly);
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
    void Function(List<PackedPage> pagesSoFar, bool isPartial)? onProgress,
  }) async {
    void checkCancel() {
      if (isCancelled?.call() == true) {
        throw const PaginationCancelledException();
      }
    }

    checkCancel();
    final maxW = contentWidthDp.clamp(1.0, 4096.0);
    final maxH = contentHeightDp.clamp(1.0, 8192.0);

    if (ir.plainText.isEmpty && ir.blocks.isEmpty) {
      return const FlutterPaginateOutcome(
        pages: [
          PackedPage(
            pageIndex: 0,
            startOffset: 0,
            endOffset: 0,
            slices: [],
            isLastPage: true,
          ),
        ],
        isPartial: false,
      );
    }

    final blocks = _resolveBlocks(ir);
    final packer = _PagePacker(
      maxHeight: maxH,
      config: config,
      stopAfterPlainOffset: stopAfterPlainOffset,
    );

    var lastReported = 0;
    void report() {
      if (onProgress == null) return;
      final n = packer.emittedPageCount;
      if (n - lastReported < 2) return;
      lastReported = n;
      onProgress(packer.snapshotPages(forcePartial: true), true);
    }

    var chunkOrdinal = 0;
    for (var i = 0; i < blocks.length; i++) {
      checkCancel();
      final block = blocks[i];
      final stop = block.kind == ReaderIrBlockKind.text
          ? await packer.packTextAsync(
              blockIndex: i,
              block: block,
              maxWidth: maxW,
              onChunkDone: () async {
                chunkOrdinal++;
                report();
                if (yieldEveryChunks > 0 &&
                    chunkOrdinal % yieldEveryChunks == 0) {
                  await Future<void>.delayed(Duration.zero);
                  checkCancel();
                }
              },
            )
          : packer.packImage(blockIndex: i, block: block, maxWidth: maxW);
      if (stop) break;

      if (stopAfterPlainOffset != null &&
          packer.plainEnd >= stopAfterPlainOffset &&
          packer.hasEmittedPages &&
          i + 1 < blocks.length) {
        packer.stoppedEarly = true;
        break;
      }
    }

    final pages = packer.finish(forcePartial: packer.stoppedEarly);
    onProgress?.call(pages, packer.stoppedEarly);
    return FlutterPaginateOutcome(pages: pages, isPartial: packer.stoppedEarly);
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
        style: const BlockStyle(
          isHeading: false,
          headingLevel: 0,
          textIndentEm: null,
          marginTopEm: null,
          marginBottomEm: null,
          textAlign: null,
          fontSize: null,
        ),
        imageAssetId: null,
        imageAlt: null,
        imageIntrinsicWidth: null,
        imageIntrinsicHeight: null,
      ),
    ];
  }
}

class _PagePacker {
  _PagePacker({
    required this.maxHeight,
    required this.config,
    this.stopAfterPlainOffset,
  }) : packBudget = (maxHeight - kPagePackBottomSlackDp).clamp(1.0, maxHeight),
       layoutSpec = LayoutSpec.fromRenderConfig(
         config,
         viewportWidth: 0, // unused; real width passed per-block as maxWidth
         viewportHeight: maxHeight + 2 * ReaderRenderConfig.pageContentVerticalPadding,
       );
  final double maxHeight;

  /// 实际可装高度（扣底边 slack）。
  final double packBudget;
  final ReaderRenderConfig config;
  final LayoutSpec layoutSpec;
  final int? stopAfterPlainOffset;

  final List<PackedPage> _pages = [];
  final List<PackedBlockSlice> _slices = [];
  int? _pageStart;
  int _pageEnd = 0;
  double _used = 0;
  bool _pageHasContent = false;

  /// 上一结束块是否允许补 paragraphSpacing（isBlockEnd 且无显式 bottom margin）。
  bool _prevBlockAllowsParagraphSpacing = false;
  bool stoppedEarly = false;

  /// 已越过 stopAfter，但仍先把当前页装满再停（避免半页留白）。
  bool _pastStop = false;

  int get plainEnd => _pageEnd;
  bool get hasEmittedPages => _pages.isNotEmpty || _pageHasContent;
  int get emittedPageCount => _pages.length + (_pageHasContent ? 1 : 0);

  bool _hitStop() {
    final stop = stopAfterPlainOffset;
    return stop != null && plainEnd >= stop && hasEmittedPages;
  }

  List<PackedPage> snapshotPages({required bool forcePartial}) {
    final out = <PackedPage>[
      for (final p in _pages)
        PackedPage(
          pageIndex: p.pageIndex,
          startOffset: p.startOffset,
          endOffset: p.endOffset,
          slices: p.slices,
          isLastPage: false,
        ),
    ];
    if (_pageHasContent || _slices.isNotEmpty) {
      out.add(
        PackedPage(
          pageIndex: out.length,
          startOffset: _pageStart ?? 0,
          endOffset: _pageEnd,
          slices: List.unmodifiable(List<PackedBlockSlice>.from(_slices)),
          isLastPage: !forcePartial,
        ),
      );
    }
    return List.unmodifiable(out);
  }

  bool packTextSync({
    required int blockIndex,
    required ReaderIrBlock block,
    required double maxWidth,
  }) {
    return _packText(
      blockIndex: blockIndex,
      block: block,
      maxWidth: maxWidth,
      onChunkDone: null,
    );
  }

  Future<bool> packTextAsync({
    required int blockIndex,
    required ReaderIrBlock block,
    required double maxWidth,
    required Future<void> Function() onChunkDone,
  }) {
    return _packTextAsync(
      blockIndex: blockIndex,
      block: block,
      maxWidth: maxWidth,
      onChunkDone: onChunkDone,
    );
  }

  /// 同步版：onChunkDone 忽略。
  bool _packText({
    required int blockIndex,
    required ReaderIrBlock block,
    required double maxWidth,
    required Future<void> Function()? onChunkDone,
  }) {
    assert(onChunkDone == null, 'use _packTextAsync for yields');
    return _packTextBody(
      blockIndex: blockIndex,
      block: block,
      maxWidth: maxWidth,
      afterChunk: null,
    );
  }

  Future<bool> _packTextAsync({
    required int blockIndex,
    required ReaderIrBlock block,
    required double maxWidth,
    required Future<void> Function() onChunkDone,
  }) async {
    // 用同步 body + 手动切窗循环，便于 await。
    final plainEnd = block.plainStart + block.plainLen;
    if (block.text.isEmpty) {
      _pageEnd = plainEnd;
      return false;
    }

    final ctx = _TextPackContext.create(
      packer: this,
      blockIndex: blockIndex,
      block: block,
      maxWidth: maxWidth,
    );

    var chunkFrom = 0;
    while (chunkFrom < block.text.length) {
      // 首屏：越过 stopAfter 后仍要装满当前页，再截断。
      if (stoppedEarly) break;

      final chunkTo = textBlockChunkEnd(block.text, chunkFrom);

      final stop = ctx.packChunk(chunkFrom, chunkTo);
      if (stop) {
        stoppedEarly = true;
        return true;
      }

      chunkFrom = chunkTo;
      if (chunkFrom < block.text.length) {
        await onChunkDone();
      }
    }

    ctx.flushSlice(isBlockEnd: true);
    _pageEnd = plainEnd;
    return false;
  }

  bool _packTextBody({
    required int blockIndex,
    required ReaderIrBlock block,
    required double maxWidth,
    required void Function()? afterChunk,
  }) {
    final plainEnd = block.plainStart + block.plainLen;
    if (block.text.isEmpty) {
      _pageEnd = plainEnd;
      return false;
    }

    final ctx = _TextPackContext.create(
      packer: this,
      blockIndex: blockIndex,
      block: block,
      maxWidth: maxWidth,
    );

    var chunkFrom = 0;
    while (chunkFrom < block.text.length) {
      if (stoppedEarly) break;

      final chunkTo = textBlockChunkEnd(block.text, chunkFrom);

      final stop = ctx.packChunk(chunkFrom, chunkTo);
      if (stop) {
        stoppedEarly = true;
        return true;
      }

      chunkFrom = chunkTo;
      afterChunk?.call();
    }

    ctx.flushSlice(isBlockEnd: true);
    _pageEnd = plainEnd;
    return false;
  }

  bool packImage({
    required int blockIndex,
    required ReaderIrBlock block,
    required double maxWidth,
  }) {
    final imgH = imageDisplayHeightDp(
      contentWidthDp: maxWidth,
      intrinsicWidth: block.imageIntrinsicWidth,
      intrinsicHeight: block.imageIntrinsicHeight,
    );
    // 内联路径渲染有 ±4dp padding；装箱必须计入，否则页底易溢出。
    final inlinePackedH = imgH + kInlineImageVerticalPaddingDp;
    final precedingSpacing = _prevBlockAllowsParagraphSpacing
        ? config.paragraphSpacing
        : 0.0;
    final inlinePackedHWithSpacing = precedingSpacing + inlinePackedH;
    final remaining = packBudget - _used;
    final start = block.plainStart;
    final end = start + block.plainLen;

    if (inlinePackedHWithSpacing <= remaining) {
      _pageStart ??= start;
      _pageEnd = end;
      _slices.add(
        PackedBlockSlice.image(
          blockIndex: blockIndex,
          assetId: block.imageAssetId ?? '',
          imageAlt: block.imageAlt,
          imageIntrinsicWidth: block.imageIntrinsicWidth,
          imageIntrinsicHeight: block.imageIntrinsicHeight,
          imageLayout: ReaderIrBlockLayout.inlineContain,
        ),
      );
      _used += inlinePackedHWithSpacing;
      _pageHasContent = true;
      _prevBlockAllowsParagraphSpacing = false;
      return false;
    }

    if (_pageHasContent) _flushPage();

    _pageStart = start;
    _pageEnd = end;
    _slices.add(
      PackedBlockSlice.image(
        blockIndex: blockIndex,
        assetId: block.imageAssetId ?? '',
        imageAlt: block.imageAlt,
        imageIntrinsicWidth: block.imageIntrinsicWidth,
        imageIntrinsicHeight: block.imageIntrinsicHeight,
        imageLayout: ReaderIrBlockLayout.fullPage,
      ),
    );
    _pageHasContent = true;
    _prevBlockAllowsParagraphSpacing = false;
    _flushPage();
    return false;
  }

  void _flushPage() {
    if (!_pageHasContent && _slices.isEmpty) return;
    _pages.add(
      PackedPage(
        pageIndex: _pages.length,
        startOffset: _pageStart ?? 0,
        endOffset: _pageEnd,
        slices: List.unmodifiable(_slices),
        isLastPage: false,
      ),
    );
    _slices.clear();
    _pageStart = null;
    _used = 0;
    _pageHasContent = false;
    _prevBlockAllowsParagraphSpacing = false;
  }

  List<PackedPage> finish({bool forcePartial = false}) {
    if (_pageHasContent || _slices.isNotEmpty || _pages.isEmpty) {
      _pages.add(
        PackedPage(
          pageIndex: _pages.length,
          startOffset: _pageStart ?? 0,
          endOffset: _pageEnd,
          slices: List.unmodifiable(_slices),
          isLastPage: !forcePartial,
        ),
      );
    } else {
      final last = _pages.removeLast();
      _pages.add(
        PackedPage(
          pageIndex: last.pageIndex,
          startOffset: last.startOffset,
          endOffset: last.endOffset,
          slices: last.slices,
          isLastPage: !forcePartial,
        ),
      );
    }
    return List.unmodifiable(_pages);
  }
}

/// 单个 ReaderIrBlock 的断行+装箱状态机。
///
/// Phase 2：使用 [ParagraphLayouter] 消费真实 line height，替代 _sliceHeightForLines 估算。
class _TextPackContext {
  _TextPackContext({
    required this.packer,
    required this.blockIndex,
    required this.block,
    required this.irStyle,
    required this.layouter,
    required double maxWidth,
  })  : indentPx = IrReaderIrBlock.resolveFirstLineIndentPx(irStyle, packer.config),
       blockPadding = IrReaderIrBlock.resolveBlockPadding(irStyle, packer.config),
       layoutMaxWidth = (maxWidth - IrReaderIrBlock.resolveBlockPadding(irStyle, packer.config).horizontal).clamp(1.0, maxWidth);

  factory _TextPackContext.create({
    required _PagePacker packer,
    required int blockIndex,
    required ReaderIrBlock block,
    required double maxWidth,
  }) {
    final irStyle = block.style;
    final spec = packer.layoutSpec;
    final spanFactory = SpanFactory(spec);
    final layouter = ParagraphLayouter(spanFactory, spec);
    return _TextPackContext(
      packer: packer,
      blockIndex: blockIndex,
      block: block,
      irStyle: irStyle,
      layouter: layouter,
      maxWidth: maxWidth,
    );
  }

  final _PagePacker packer;
  final int blockIndex;
  final ReaderIrBlock block;
  final double indentPx;
  final EdgeInsets blockPadding;
  final double layoutMaxWidth;
  final BlockStyle irStyle;
  final ParagraphLayouter layouter;

  var localStart = 0;
  var isBlockStart = true;
  final lineBuf = StringBuffer();
  var sliceLocalStart = 0;
  var sliceIsBlockStart = true;


  double _blockOverhead() {
    var oh = blockPadding.vertical;
    if (packer._prevBlockAllowsParagraphSpacing &&
        packer.config.paragraphSpacing > 0) {
      oh += packer.config.paragraphSpacing;
    }
    return oh;
  }

  void flushSlice({required bool isBlockEnd}) {
    if (lineBuf.isEmpty) return;
    final text = lineBuf.toString();
    final absStart = block.plainStart + sliceLocalStart;
    final absEnd = absStart + text.length;
    packer._pageStart ??= absStart;
    packer._pageEnd = absEnd;
    packer._slices.add(
      PackedBlockSlice.text(
        blockIndex: blockIndex,
        text: text,
        isBlockStart: sliceIsBlockStart,
        isBlockEnd: isBlockEnd,
        style: irStyle,
        spans: sliceRichSpans(
          block.runs,
          start: sliceLocalStart,
          len: text.length,
        ),
      ),
    );
    packer._pageHasContent = true;
    packer._prevBlockAllowsParagraphSpacing =
        isBlockEnd && irStyle.marginBottomEm == null;
    lineBuf.clear();
  }

  /// 处理 [chunkFrom, chunkTo) 子串。返回是否应停止后续块。
  ///
  /// Phase 2: 使用 [ParagraphLayouter] 获取真实 line height。
  bool packChunk(int chunkFrom, int chunkTo) {
    final chunk = block.text.substring(chunkFrom, chunkTo);
    final chunkRuns = sliceRichSpans(
      block.runs,
      start: chunkFrom,
      len: chunk.length,
    );
    final layout = layouter.layoutTextBlock(
      blockIndex: blockIndex,
      text: chunk,
      spans: chunkRuns,
      style: irStyle,
      maxWidth: layoutMaxWidth,
      firstLineIndentPx: isBlockStart ? indentPx : 0.0,
    );
    if (layout.lines.isEmpty) return false;

    for (final line in layout.lines) {
      final localEnd = chunkFrom + line.endUtf16;
      if (localEnd <= localStart) continue;
      final lineText = block.text.substring(localStart, localEnd);
      final lineH = line.height;

      if (lineBuf.isEmpty) {
        var need = lineH + (isBlockStart ? _blockOverhead() : 0.0);
        // 仅在本页已有内容时才因装不下而翻页；允许贴满 maxHeight。
        if (packer._pageHasContent && packer._used + need > packer.packBudget) {
          flushSlice(isBlockEnd: false);
          packer._flushPage();
          if (packer._pastStop) {
            packer.stoppedEarly = true;
            return true;
          }
          // 上一块留在前页，页首不应继续携带它产生的 paragraphSpacing。
          need = lineH + (isBlockStart ? _blockOverhead() : 0.0);
        }
        sliceLocalStart = localStart;
        sliceIsBlockStart = isBlockStart;
        packer._used += need;
        lineBuf.write(lineText);
      } else {
        if (packer._used + lineH > packer.packBudget) {
          flushSlice(isBlockEnd: false);
          packer._flushPage();
          if (packer._pastStop) {
            packer.stoppedEarly = true;
            return true;
          }
          final need = lineH + (isBlockStart ? _blockOverhead() : 0.0);
          sliceLocalStart = localStart;
          sliceIsBlockStart = isBlockStart;
          packer._used += need;
          lineBuf.write(lineText);
        } else {
          packer._used += lineH;
          lineBuf.write(lineText);
        }
      }

      packer._pageHasContent = true;
      localStart = localEnd;
      isBlockStart = false;
      packer._pageEnd = block.plainStart + localEnd;

      if (packer._hitStop()) {
        packer._pastStop = true;
      }
    }
    return false;
  }
}

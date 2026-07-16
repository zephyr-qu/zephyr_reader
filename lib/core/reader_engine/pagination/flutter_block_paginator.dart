import 'package:flutter/painting.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/line_break_extractor.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/ir_text_block_style.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/slice_rich_spans.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/packed_page.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';

/// 无 intrinsic 时图片高度 = 内容宽 × 此比（与 Rust `DEFAULT_IMAGE_HEIGHT_RATIO` 对齐）。
const kDefaultImageHeightRatio = 0.55;

/// 内联图上下 padding（与 [EpubBlockImage] `EdgeInsets.symmetric(vertical: 4)` 对齐）。
const kInlineImageVerticalPaddingDp = 8.0;

/// 单次 TextPainter 断行上限：大单块 TXT 必须切窗。
const kLineBreakChunkChars = 4000;

/// 页底安全余量：Strut 累加与 SelectableText 实测常有 1–2dp 差，避免 RenderFlex overflow。
const kPagePackBottomSlackDp = 2.0;

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
        isHeading: false,
        headingLevel: 0,
        textIndentEm: null,
        marginTopEm: null,
        marginBottomEm: null,
        textAlign: null,
        fontSize: null,
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
  }) : packBudget = (maxHeight - kPagePackBottomSlackDp).clamp(1.0, maxHeight);

  final double maxHeight;

  /// 实际可装高度（扣底边 slack）。
  final double packBudget;
  final ReaderRenderConfig config;
  final int? stopAfterPlainOffset;

  final List<PackedPage> _pages = [];
  final List<PackedBlockSlice> _slices = [];
  int? _pageStart;
  int _pageEnd = 0;
  double _used = 0;
  bool _pageHasContent = false;
  bool _prevEndedBlockOnPage = false;
  bool stoppedEarly = false;
  double _sliceHeight = 0;

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

      var chunkTo = (chunkFrom + kLineBreakChunkChars).clamp(
        0,
        block.text.length,
      );
      if (chunkTo < block.text.length) {
        final nl = block.text.lastIndexOf('\n', chunkTo);
        if (nl > chunkFrom + kLineBreakChunkChars ~/ 2) {
          chunkTo = nl + 1;
        }
      }

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

      var chunkTo = (chunkFrom + kLineBreakChunkChars).clamp(
        0,
        block.text.length,
      );
      if (chunkTo < block.text.length) {
        final nl = block.text.lastIndexOf('\n', chunkTo);
        if (nl > chunkFrom + kLineBreakChunkChars ~/ 2) {
          chunkTo = nl + 1;
        }
      }

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
    final remaining = packBudget - _used;
    final start = block.plainStart;
    final end = start + block.plainLen;

    if (inlinePackedH <= remaining) {
      _pageStart ??= start;
      _pageEnd = end;
      _slices.add(
        PackedBlockSlice.image(
          blockIndex: blockIndex,
          assetId: block.imageAssetId ?? '',
          imageAlt: block.imageAlt,
          imageLayout: ReaderIrBlockLayout.inlineContain,
        ),
      );
      _used += inlinePackedH;
      _pageHasContent = true;
      _prevEndedBlockOnPage = true;
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
        imageLayout: ReaderIrBlockLayout.fullPage,
      ),
    );
    _pageHasContent = true;
    _prevEndedBlockOnPage = true;
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
    _prevEndedBlockOnPage = false;
    _sliceHeight = 0;
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
class _TextPackContext {
  _TextPackContext({
    required this.packer,
    required this.blockIndex,
    required this.block,
    required this.textStyle,
    required this.strutStyle,
    required this.indentPx,
    required this.blockPadding,
    required this.layoutMaxWidth,
    required this.blockLineHeight,
    required this.irStyle,
  });

  factory _TextPackContext.create({
    required _PagePacker packer,
    required int blockIndex,
    required ReaderIrBlock block,
    required double maxWidth,
  }) {
    final irStyle = block;
    final config = packer.config;
    final blockFontSize = IrReaderIrBlock.effectiveFontSize(irStyle, config);
    final blockLineHeight = IrReaderIrBlock.effectiveLineHeight(
      irStyle,
      config,
    );
    final textStyle = config
        .buildTextStyle(fontSizeMultiplier: blockFontSize / config.fontSize)
        .copyWith(height: blockLineHeight);
    final strutStyle = config.buildStrutStyle(
      fontSizeMultiplier: blockFontSize / config.fontSize,
      lineHeight: blockLineHeight,
    );
    final indentPx = IrReaderIrBlock.resolveFirstLineIndentPx(irStyle, config);
    final blockPadding = IrReaderIrBlock.resolveBlockPadding(irStyle, config);
    final layoutMaxWidth = (maxWidth - blockPadding.horizontal).clamp(
      1.0,
      maxWidth,
    );
    return _TextPackContext(
      packer: packer,
      blockIndex: blockIndex,
      block: block,
      textStyle: textStyle,
      strutStyle: strutStyle,
      indentPx: indentPx,
      blockPadding: blockPadding,
      layoutMaxWidth: layoutMaxWidth,
      blockLineHeight: blockLineHeight,
      irStyle: irStyle,
    );
  }

  final _PagePacker packer;
  final int blockIndex;
  final ReaderIrBlock block;
  final TextStyle textStyle;
  final StrutStyle strutStyle;
  final double indentPx;
  final EdgeInsets blockPadding;
  final double layoutMaxWidth;
  final double blockLineHeight;
  final ReaderIrBlock irStyle;

  var localStart = 0;
  var isBlockStart = true;
  final lineBuf = StringBuffer();
  var sliceLocalStart = 0;
  var sliceIsBlockStart = true;

  double get _strutLineH => packer.config.fontSize * blockLineHeight;

  double _blockOverhead() {
    var oh = blockPadding.vertical;
    if (packer._prevEndedBlockOnPage &&
        irStyle.marginBottomEm == null &&
        packer.config.paragraphSpacing > 0) {
      oh += packer.config.paragraphSpacing;
    }
    return oh;
  }

  /// forceStrutHeight 下每行高度即 fontSize×lineHeight；不用 TextPainter 估高（会偏高→底空）。
  double _sliceHeightForLines(int lineCount, {required bool withBlockStart}) {
    if (lineCount <= 0) return 0;
    final oh = withBlockStart ? _blockOverhead() : 0.0;
    return oh + lineCount * _strutLineH;
  }

  var _sliceLineCount = 0;

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
    packer._prevEndedBlockOnPage = isBlockEnd;
    lineBuf.clear();
    packer._sliceHeight = 0;
    _sliceLineCount = 0;
  }

  /// 处理 [chunkFrom, chunkTo) 子串。返回是否应停止后续块。
  bool packChunk(int chunkFrom, int chunkTo) {
    final chunk = block.text.substring(chunkFrom, chunkTo);
    final breaks = computeLineBreakIndices(
      text: chunk,
      style: textStyle,
      maxWidth: layoutMaxWidth,
      strutStyle: strutStyle,
      firstLineIndentPx: isBlockStart ? indentPx : 0.0,
    );
    if (breaks.isEmpty) return false;

    for (final relEnd in breaks) {
      final localEnd = chunkFrom + relEnd;
      if (localEnd <= localStart) continue;
      final lineText = block.text.substring(localStart, localEnd);

      if (lineBuf.isEmpty) {
        final need = _sliceHeightForLines(1, withBlockStart: isBlockStart);
        // 仅在本页已有内容时才因装不下而翻页；允许贴满 maxHeight。
        if (packer._pageHasContent && packer._used + need > packer.packBudget) {
          flushSlice(isBlockEnd: false);
          packer._flushPage();
          if (packer._pastStop) {
            packer.stoppedEarly = true;
            return true;
          }
        }
        sliceLocalStart = localStart;
        sliceIsBlockStart = isBlockStart;
        _sliceLineCount = 1;
        packer._sliceHeight = need;
        packer._used += need;
        lineBuf.write(lineText);
      } else {
        final newLines = _sliceLineCount + 1;
        final newSliceH = _sliceHeightForLines(
          newLines,
          withBlockStart: sliceIsBlockStart,
        );
        final delta = newSliceH - packer._sliceHeight;
        if (packer._used + delta > packer.packBudget) {
          flushSlice(isBlockEnd: false);
          packer._flushPage();
          if (packer._pastStop) {
            packer.stoppedEarly = true;
            return true;
          }
          final need = _sliceHeightForLines(1, withBlockStart: isBlockStart);
          sliceLocalStart = localStart;
          sliceIsBlockStart = isBlockStart;
          _sliceLineCount = 1;
          packer._sliceHeight = need;
          packer._used += need;
          lineBuf.write(lineText);
        } else {
          packer._used += delta;
          packer._sliceHeight = newSliceH;
          _sliceLineCount = newLines;
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

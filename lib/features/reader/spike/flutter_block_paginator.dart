import 'package:zephyr_reader/features/reader/data/line_break_extractor.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/features/reader/rendering/ir_text_block_style.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/features/reader/spike/spike_page.dart';
import 'package:zephyr_reader/src/rust/domain/types/block_pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

/// 无 intrinsic 时图片高度 = 内容宽 × 此比（与 Rust `DEFAULT_IMAGE_HEIGHT_RATIO` 对齐）。
const kDefaultImageHeightRatio = 0.55;

/// 装箱被 generation 取消。
final class PaginationCancelledException implements Exception {
  const PaginationCancelledException();

  @override
  String toString() => 'PaginationCancelledException';
}

/// [FlutterBlockPaginator.paginateAsync] 结果。
class FlutterPaginateOutcome {
  const FlutterPaginateOutcome({
    required this.pages,
    required this.isPartial,
  });

  final List<SpikePage> pages;
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

/// Flutter 侧页装箱（方案三）：TextPainter 断行 + 按页高装箱。
///
/// **T3**：`paginateAsync` 在主 isolate 分块 `await` 让出事件循环——TextPainter
/// 依赖字体子系统，不能搬进普通 `compute` isolate。
abstract final class FlutterBlockPaginator {
  /// 同步装箱（单测 / 小章）。
  static List<SpikePage> paginate(
    ChapterContentIr ir, {
    required ReaderRenderConfig config,
    required double contentWidthDp,
    required double contentHeightDp,
    int? stopAfterPlainOffset,
  }) {
    final outcome = _paginateSync(
      ir,
      config: config,
      contentWidthDp: contentWidthDp,
      contentHeightDp: contentHeightDp,
      stopAfterPlainOffset: stopAfterPlainOffset,
    );
    return outcome.pages;
  }

  /// 异步分块装箱；[yieldEveryBlocks]>0 时每隔 N 块让出一帧事件循环。
  ///
  /// [isCancelled] 返回 true 时抛出 [PaginationCancelledException]。
  /// [stopAfterPlainOffset]：plain 进度达到后提前结束（首屏优先，[isPartial]=true）。
  static Future<FlutterPaginateOutcome> paginateAsync(
    ChapterContentIr ir, {
    required ReaderRenderConfig config,
    required double contentWidthDp,
    required double contentHeightDp,
    bool Function()? isCancelled,
    int yieldEveryBlocks = 6,
    int? stopAfterPlainOffset,
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
          SpikePage(
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

    for (var i = 0; i < blocks.length; i++) {
      checkCancel();
      final stop = blocks[i].when(
        text: (t) =>
            packer.addTextBlock(blockIndex: i, block: t, maxWidth: maxW),
        image: (img) =>
            packer.addImageBlock(blockIndex: i, block: img, maxWidth: maxW),
      );
      if (stop) break;

      // 块间停点：已覆盖 stopAfter 且还有后续块 → 首屏截断。
      if (stopAfterPlainOffset != null &&
          packer.plainEnd >= stopAfterPlainOffset &&
          packer.hasEmittedPages &&
          i + 1 < blocks.length) {
        packer.stoppedEarly = true;
        break;
      }

      if (yieldEveryBlocks > 0 &&
          i > 0 &&
          i % yieldEveryBlocks == 0 &&
          i + 1 < blocks.length) {
        await Future<void>.delayed(Duration.zero);
        checkCancel();
      }
    }

    return FlutterPaginateOutcome(
      pages: packer.finish(forcePartial: packer.stoppedEarly),
      isPartial: packer.stoppedEarly,
    );
  }

  static FlutterPaginateOutcome _paginateSync(
    ChapterContentIr ir, {
    required ReaderRenderConfig config,
    required double contentWidthDp,
    required double contentHeightDp,
    int? stopAfterPlainOffset,
  }) {
    final maxW = contentWidthDp.clamp(1.0, 4096.0);
    final maxH = contentHeightDp.clamp(1.0, 8192.0);

    if (ir.plainText.isEmpty && ir.blocks.isEmpty) {
      return const FlutterPaginateOutcome(
        pages: [
          SpikePage(
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

    for (var i = 0; i < blocks.length; i++) {
      final stop = blocks[i].when(
        text: (t) =>
            packer.addTextBlock(blockIndex: i, block: t, maxWidth: maxW),
        image: (img) =>
            packer.addImageBlock(blockIndex: i, block: img, maxWidth: maxW),
      );
      if (stop) break;

      if (stopAfterPlainOffset != null &&
          packer.plainEnd >= stopAfterPlainOffset &&
          packer.hasEmittedPages &&
          i + 1 < blocks.length) {
        packer.stoppedEarly = true;
        break;
      }
    }

    return FlutterPaginateOutcome(
      pages: packer.finish(forcePartial: packer.stoppedEarly),
      isPartial: packer.stoppedEarly,
    );
  }

  static List<ContentBlock> _resolveBlocks(ChapterContentIr ir) {
    if (ir.blocks.isNotEmpty) return ir.blocks;
    return [
      ContentBlock.text(
        TextBlock(
          plain: BlockPlainRange(plainStart: 0, plainLen: ir.plainText.length),
          text: ir.plainText,
          style: const TextBlockStyle(isHeading: false, headingLevel: 0),
          spans: const [],
        ),
      ),
    ];
  }
}

class _PagePacker {
  _PagePacker({
    required this.maxHeight,
    required this.config,
    this.stopAfterPlainOffset,
  });

  final double maxHeight;
  final ReaderRenderConfig config;
  final int? stopAfterPlainOffset;

  final List<SpikePage> _pages = [];
  final List<SpikeBlockSlice> _slices = [];
  int? _pageStart;
  int _pageEnd = 0;
  double _used = 0;
  bool _pageHasContent = false;
  bool _prevEndedBlockOnPage = false;
  bool stoppedEarly = false;

  int get plainEnd => _pageEnd;

  bool get hasEmittedPages => _pages.isNotEmpty || _pageHasContent;

  bool _hitStop() {
    final stop = stopAfterPlainOffset;
    return stop != null && plainEnd >= stop && hasEmittedPages;
  }

  /// 返回 true 表示已达 [stopAfterPlainOffset]，调用方应停止后续块。
  bool addTextBlock({
    required int blockIndex,
    required TextBlock block,
    required double maxWidth,
  }) {
    final plainEnd = block.plain.plainStart + block.plain.plainLen;
    if (block.text.isEmpty) {
      _pageEnd = plainEnd;
      return false;
    }

    final irStyle = block.style;
    final blockFontSize = IrTextBlockStyle.effectiveFontSize(irStyle, config);
    final blockLineHeight = IrTextBlockStyle.effectiveLineHeight(
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
    final indentPx = IrTextBlockStyle.resolveFirstLineIndentPx(irStyle, config);
    final blockPadding = IrTextBlockStyle.resolveBlockPadding(irStyle, config);
    final layoutMaxWidth = (maxWidth - blockPadding.horizontal).clamp(
      1.0,
      maxWidth,
    );

    final breaks = computeLineBreakIndices(
      text: block.text,
      style: textStyle,
      maxWidth: layoutMaxWidth,
      strutStyle: strutStyle,
      firstLineIndentPx: indentPx,
    );
    if (breaks.isEmpty) {
      _pageEnd = plainEnd;
      return false;
    }

    var localStart = 0;
    var isBlockStart = true;
    final lineBuf = StringBuffer();
    var sliceLocalStart = 0;
    var sliceIsBlockStart = true;

    void flushSlice({required bool isBlockEnd}) {
      if (lineBuf.isEmpty) return;
      final text = lineBuf.toString();
      final absStart = block.plain.plainStart + sliceLocalStart;
      final absEnd = absStart + text.length;
      _pageStart ??= absStart;
      _pageEnd = absEnd;
      _slices.add(
        SpikeBlockSlice.text(
          blockIndex: blockIndex,
          text: text,
          isBlockStart: sliceIsBlockStart,
          isBlockEnd: isBlockEnd,
          style: irStyle,
          spans: _clipSpans(block.spans, sliceLocalStart, text.length),
        ),
      );
      _pageHasContent = true;
      _prevEndedBlockOnPage = isBlockEnd;
      lineBuf.clear();
    }

    for (var li = 0; li < breaks.length; li++) {
      final localEnd = breaks[li];
      final lineText = block.text.substring(localStart, localEnd);

      final measured = measureSliceLayout(
        text: lineText,
        style: textStyle,
        maxWidth: layoutMaxWidth,
        strutStyle: strutStyle,
        firstLineIndentPx: isBlockStart ? indentPx : 0.0,
      );
      var lineH = measured.height;
      if (lineH <= 0) {
        lineH = config.fontSize * blockLineHeight;
      }

      var overhead = 0.0;
      if (isBlockStart) {
        overhead += blockPadding.vertical;
        if (_prevEndedBlockOnPage &&
            irStyle.marginBottomEm == null &&
            config.paragraphSpacing > 0) {
          overhead += config.paragraphSpacing;
        }
      }

      final need = overhead + lineH;
      if (_pageHasContent && _used + need > maxHeight + 0.5) {
        flushSlice(isBlockEnd: false);
        _flushPage();
        overhead = isBlockStart ? blockPadding.vertical : 0.0;
      }

      if (lineBuf.isEmpty) {
        sliceLocalStart = localStart;
        sliceIsBlockStart = isBlockStart;
        _used += overhead + lineH;
      } else {
        _used += lineH;
      }

      lineBuf.write(lineText);
      _pageHasContent = true;
      localStart = localEnd;
      isBlockStart = false;

      // 行级停点：大单块 TXT 也能首屏截断，不必等整块结束。
      _pageEnd = block.plain.plainStart + localEnd;
      if (_hitStop()) {
        flushSlice(isBlockEnd: false);
        stoppedEarly = true;
        return true;
      }
    }

    flushSlice(isBlockEnd: true);
    _pageEnd = plainEnd;
    // 块边界停点由外层根据「是否还有后续块」判定，避免全章装完仍标 partial。
    return false;
  }

  /// 返回 true 表示已达停点。
  bool addImageBlock({
    required int blockIndex,
    required ImageBlock block,
    required double maxWidth,
  }) {
    final imgH = imageDisplayHeightDp(
      contentWidthDp: maxWidth,
      intrinsicWidth: block.intrinsicWidth,
      intrinsicHeight: block.intrinsicHeight,
    );
    final remaining = maxHeight - _used;
    final start = block.plain.plainStart;
    final end = start + block.plain.plainLen;

    if (imgH <= remaining + 0.5) {
      _pageStart ??= start;
      _pageEnd = end;
      _slices.add(
        SpikeBlockSlice.image(
          blockIndex: blockIndex,
          assetId: block.assetId,
          alt: block.alt,
          imageLayout: ImageBlockLayout.inlineContain,
        ),
      );
      _used += imgH;
      _pageHasContent = true;
      _prevEndedBlockOnPage = true;
      return false;
    }

    if (_pageHasContent) {
      _flushPage();
    }

    _pageStart = start;
    _pageEnd = end;
    _slices.add(
      SpikeBlockSlice.image(
        blockIndex: blockIndex,
        assetId: block.assetId,
        alt: block.alt,
        imageLayout: ImageBlockLayout.fullPage,
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
      SpikePage(
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
  }

  List<SpikePage> finish({bool forcePartial = false}) {
    if (_pageHasContent || _slices.isNotEmpty || _pages.isEmpty) {
      _pages.add(
        SpikePage(
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
        SpikePage(
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

List<RichTextSpan> _clipSpans(
  List<RichTextSpan> spans,
  int localStart,
  int length,
) {
  if (spans.isEmpty || length <= 0) return const [];
  return const [];
}

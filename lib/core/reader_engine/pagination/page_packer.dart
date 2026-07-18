import 'package:zephyr_reader/core/reader_engine/layout/block_layout.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_spec.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/page_plan.dart'
    show PageFragment, PagePlan, ReaderIrBlockLayout;
import 'package:zephyr_reader/core/reader_engine/pagination/slice_rich_spans.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';


/// TextPainter vs SelectableText.rich 布局偏差预留。
/// 实测 RenderFlex overflow 在 7.7px 以内。
const kPagePackBottomSlackDp = 8.0;

/// 内联图上下 padding（与 [EpubBlockImage] `EdgeInsets.symmetric(vertical: 4)` 对齐）。
const kInlineImageVerticalPaddingDp = 8.0;

/// 图片高度 fallback 比率。
const kDefaultImageHeightRatio = 0.55;

/// 纯几何页面装箱器 — 消费 [BlockLayout] 产生 [PagePlan]。
///
/// ADR-018：PagePacker 不直接理解字体、TextStyle、TextPainter。
class PagePacker {
  PagePacker({required this.spec, required this.maxHeight})
    : packBudget = (maxHeight - kPagePackBottomSlackDp).clamp(1.0, maxHeight);

  final LayoutSpec spec;
  final double maxHeight;
  final double packBudget;

  // ── 页状态 ──
  final List<PagePlan> _pages = [];
  final List<PageFragment> _fragments = [];
  int? _pageStart;
  int _pageEnd = 0;
  double _used = 0;
  bool _pageHasContent = false;
  bool _prevBlockAllowsParagraphSpacing = false;

  // ── 当前 Fragment 累积 ──
  final StringBuffer _fragBuf = StringBuffer();
  int _fragBlockIndex = 0;
  int _fragLocalStart = 0;
  bool _fragIsBlockStart = true;
  bool _fragEndsBlock = false;
  int?
  _fragBlockPlainStart; // block's chapter-level plainStart for correct absolute offset
  BlockStyle? _fragBlockStyle;
  List<ReaderInlineRun> _fragBlockRuns = const [];

  int get plainEnd => _pageEnd;
  bool get hasEmittedPages => _pages.isNotEmpty || _pageHasContent;
  int get emittedPageCount => _pages.length + (_pageHasContent ? 1 : 0);

  /// 非破坏性快照：返回已发布的页面（不含当前正在组装的页）。
  /// 用于 progress 回调。不会修改 packer 状态。
  List<PagePlan> snapshotPages({bool isPartial = false}) {
    // Rebuild from _pages (immutable copies) + current fragment if any.
    final out = <PagePlan>[
      for (final p in _pages)
        PagePlan(
          pageIndex: p.pageIndex,
          startUtf16: p.startUtf16,
          endUtf16: p.endUtf16,
          fragments: p.fragments,
          usedHeight: p.usedHeight,
          isLastPage: false,
        ),
    ];
    if (_pageHasContent || _fragments.isNotEmpty) {
      out.add(
        PagePlan(
          pageIndex: out.length,
          startUtf16: _pageStart ?? 0,
          endUtf16: _pageEnd,
          fragments: List.unmodifiable([
            ..._fragments,
            if (_fragBuf.isNotEmpty)
              _pendingFragment(isBlockEnd: _fragEndsBlock),
          ]),
          usedHeight: _used,
          isLastPage: !isPartial,
        ),
      );
    }
    return out;
  }

  /// 添加文本块的布局结果。
  bool appendTextBlock({
    required BlockLayout block,
    required String blockText,
    required List<ReaderInlineRun> blockRuns,
    required int blockPlainStart,
    required BlockStyle blockStyle,
    bool startsBlock = true,
    bool endsBlock = true,
    int? stopAfterPlainOffset,
  }) {
    // Flush previous block's fragment if any.
    if (_fragBuf.isNotEmpty) {
      _flushFragment(isBlockEnd: _fragEndsBlock);
    }

    var isBlockStart = startsBlock;

    for (var lineIndex = 0; lineIndex < block.lines.length; lineIndex++) {
      final line = block.lines[lineIndex];
      final isLastLine = lineIndex == block.lines.length - 1;
      final lineH = line.height;
      final lineStart = blockPlainStart + line.startUtf16;
      final lineEnd = blockPlainStart + line.endUtf16;
      final lineText = blockText.substring(line.startUtf16, line.endUtf16);

      if (_fragBuf.isEmpty) {
        // ── 新 Fragment ──
        final topOverhead = isBlockStart
            ? block.margins.top +
                  (_prevBlockAllowsParagraphSpacing
                      ? spec.paragraphSpacing
                      : 0.0)
            : 0.0;
        final bottomOverhead = isLastLine && endsBlock
            ? block.margins.bottom
            : 0.0;
        var need = lineH + topOverhead + bottomOverhead;

        if (_pageHasContent && _used + need > packBudget) {
          if (stopAfterPlainOffset != null &&
              _pageEnd >= stopAfterPlainOffset) {
            _flushPage();
            return true;
          }
          _flushFragment(isBlockEnd: false);
          _flushPage();
          // Page continuation does not create a new semantic block boundary.
          need =
              lineH + (isBlockStart ? block.margins.top : 0.0) + bottomOverhead;
        }

        _fragBlockIndex = block.blockIndex;
        _fragLocalStart = line.startUtf16;
        _fragIsBlockStart = isBlockStart;
        _fragBlockPlainStart = blockPlainStart;
        _fragBlockStyle = blockStyle;
        _fragBlockRuns = blockRuns;
        _pageStart ??= lineStart;
        _used += need;
      } else {
        // ── 续行 ──
        final continuationNeed =
            lineH + (isLastLine && endsBlock ? block.margins.bottom : 0.0);
        if (_used + continuationNeed > packBudget) {
          if (stopAfterPlainOffset != null &&
              _pageEnd >= stopAfterPlainOffset) {
            _flushFragment(isBlockEnd: false);
            _flushPage();
            return true;
          }
          _flushFragment(isBlockEnd: false);
          _flushPage();
          _fragBlockIndex = block.blockIndex;
          _fragLocalStart = line.startUtf16;
          _fragIsBlockStart = false;
          _fragBlockPlainStart = blockPlainStart;
          _fragBlockStyle = blockStyle;
          _fragBlockRuns = blockRuns;
          _pageStart ??= lineStart;
          _used += continuationNeed;
          _fragBuf.write(lineText);
          _pageEnd = lineEnd;
          _pageHasContent = true;
          continue;
        } else {
          _used += continuationNeed;
        }
      }

      _fragBuf.write(lineText);
      _pageEnd = lineEnd;
      _pageHasContent = true;
      isBlockStart = false;
    }

    _prevBlockAllowsParagraphSpacing =
        endsBlock && blockStyle.marginBottomEm == null;
    _fragEndsBlock = endsBlock;
    return false;
  }

  /// 添加图片块的布局结果。
  bool appendImageBlock({
    required BlockLayout block,
    required int blockPlainStart,
    required double displayHeight,
    required String assetId,
    String? imageAlt,
    int? intrinsicWidth,
    int? intrinsicHeight,
    int? stopAfterPlainOffset,
  }) {
    if (_fragBuf.isNotEmpty) {
      _flushFragment(isBlockEnd: _fragEndsBlock);
    }
    final inlinePackedH = displayHeight + kInlineImageVerticalPaddingDp;
    final precedingSpacing = _prevBlockAllowsParagraphSpacing
        ? spec.paragraphSpacing
        : 0.0;
    final totalH = precedingSpacing + inlinePackedH;
    final remaining = packBudget - _used;
    final start = blockPlainStart;
    final end = start + (block.endUtf16 - block.startUtf16);

    if (totalH <= remaining) {
      // Fits inline on current page.
      _pageStart ??= start;
      _pageEnd = end;
      _fragments.add(
        PageFragment.image(
          blockIndex: block.blockIndex,
          startUtf16: start,
          endUtf16: end,
          assetId: assetId,
          imageAlt: imageAlt,
          intrinsicWidth: intrinsicWidth,
          intrinsicHeight: intrinsicHeight,
          imageDisplayWidth: imageDisplayWidth(
            contentWidthDp: spec.contentWidth,
            intrinsicWidth: intrinsicWidth,
          ),
          imageDisplayHeight: displayHeight,
          imageLayout: ReaderIrBlockLayout.inlineContain,
        ),
      );
      _used += totalH;
      _pageHasContent = true;
      _prevBlockAllowsParagraphSpacing = false;
      return false;
    }

    // Doesn't fit → full page.
    if (_pageHasContent) {
      if (stopAfterPlainOffset != null && _pageEnd >= stopAfterPlainOffset) {
        _flushPage();
        return true;
      }
      _flushPage();
    }
    _pageStart = start;
    _pageEnd = end;
    _fragments.add(
      PageFragment.image(
        blockIndex: block.blockIndex,
        startUtf16: start,
        endUtf16: end,
        assetId: assetId,
        imageAlt: imageAlt,
        intrinsicWidth: intrinsicWidth,
        intrinsicHeight: intrinsicHeight,
        imageLayout: ReaderIrBlockLayout.fullPage,
      ),
    );
    _pageHasContent = true;
    _prevBlockAllowsParagraphSpacing = false;
    _used = packBudget;
    _flushPage();
    return false;
  }

  /// Flush current fragment accumulator into a PageFragment.
  void _flushFragment({required bool isBlockEnd}) {
    if (_fragBuf.isEmpty) return;
    _fragments.add(_pendingFragment(isBlockEnd: isBlockEnd));
    _fragBuf.clear();
  }

  PageFragment _pendingFragment({required bool isBlockEnd}) {
    final text = _fragBuf.toString();
    final localStart = _fragLocalStart;
    // Absolute offset = blockPlainStart + fragment's local start within block.
    final absStart = (_fragBlockPlainStart ?? 0) + localStart;
    final absEnd = absStart + text.length;
    // Slice runs to match this fragment's range.
    final slicedRuns = _fragBlockRuns.isEmpty
        ? const <ReaderInlineRun>[]
        : sliceRichSpans(_fragBlockRuns, start: localStart, len: text.length);

    return PageFragment.text(
      blockIndex: _fragBlockIndex,
      startUtf16: absStart,
      endUtf16: absEnd,
      text: text,
      spans: slicedRuns,
      isBlockStart: _fragIsBlockStart,
      isBlockEnd: isBlockEnd,
      style: _fragBlockStyle,
    );
  }

  void _flushPage() {
    // Flush pending fragment before creating page.
    if (_fragBuf.isNotEmpty) {
      _flushFragment(isBlockEnd: false);
    }
    if (!_pageHasContent && _fragments.isEmpty) return;
    _pages.add(
      PagePlan(
        pageIndex: _pages.length,
        startUtf16: _pageStart ?? 0,
        endUtf16: _pageEnd,
        fragments: List.unmodifiable(_fragments),
        usedHeight: _used,
      ),
    );
    _fragments.clear();
    _pageStart = null;
    _used = 0;
    _pageHasContent = false;
    _prevBlockAllowsParagraphSpacing = false;
  }

  /// 完成装箱。返回所有页（最后一页标记 isLastPage）。
  List<PagePlan> finish({bool isPartial = false}) {
    _flushFragment(isBlockEnd: _fragEndsBlock);
    if (_pageHasContent || _fragments.isNotEmpty || _pages.isEmpty) {
      _pages.add(
        PagePlan(
          pageIndex: _pages.length,
          startUtf16: _pageStart ?? 0,
          endUtf16: _pageEnd,
          fragments: List.unmodifiable(_fragments),
          usedHeight: _used,
          isLastPage: !isPartial,
        ),
      );
      _fragments.clear();
    } else {
      final last = _pages.removeLast();
      _pages.add(
        PagePlan(
          pageIndex: last.pageIndex,
          startUtf16: last.startUtf16,
          endUtf16: last.endUtf16,
          fragments: last.fragments,
          usedHeight: last.usedHeight,
          isLastPage: !isPartial,
        ),
      );
    }
    return List.unmodifiable(_pages);
  }

  /// 装箱时停止于指定 offset 后（首屏截断）。
  bool hitPlainEnd(int stopAfterPlainOffset) =>
      stopAfterPlainOffset > 0 &&
      plainEnd >= stopAfterPlainOffset &&
      hasEmittedPages;

  /// 图片在内容宽下的显示高度。
  static double imageDisplayHeight({
    required double contentWidthDp,
    int? intrinsicWidth,
    int? intrinsicHeight,
  }) {
    final w = contentWidthDp.clamp(1.0, 4096.0);
    if (intrinsicWidth != null &&
        intrinsicHeight != null &&
        intrinsicWidth > 0 &&
        intrinsicHeight > 0) {
      return intrinsicHeight * (w / intrinsicWidth).clamp(0.0, 1.0);
    }
    return w * kDefaultImageHeightRatio;
  }

  static double imageDisplayWidth({
    required double contentWidthDp,
    int? intrinsicWidth,
  }) {
    final w = contentWidthDp.clamp(1.0, 4096.0);
    if (intrinsicWidth != null && intrinsicWidth > 0) {
      return intrinsicWidth.toDouble().clamp(1.0, w);
    }
    return w;
  }

  /// 便捷方法：一次装箱整个 BlockLayout 列表。
  static List<PagePlan> pack({
    required List<BlockLayout> blocks,
    required LayoutSpec spec,
    required double maxHeight,
    required String chapterPlainText,
    required List<ReaderIrBlock> irBlocks,
  }) {
    final packer = PagePacker(spec: spec, maxHeight: maxHeight);
    for (final block in blocks) {
      if (block.isImage) {
        final displayH = imageDisplayHeight(
          contentWidthDp: spec.contentWidth,
          intrinsicWidth: block.intrinsicWidth,
          intrinsicHeight: block.intrinsicHeight,
        );
        packer.appendImageBlock(
          block: block,
          blockPlainStart: block.startUtf16,
          displayHeight: displayH,
          assetId: block.assetId ?? '',
          imageAlt: block.imageAlt,
          intrinsicWidth: block.intrinsicWidth,
          intrinsicHeight: block.intrinsicHeight,
        );
      } else {
        final ir = irBlocks.firstWhere(
          (b) =>
              b.plainStart <= block.startUtf16 &&
              b.plainStart + b.plainLen > block.startUtf16,
          orElse: () => irBlocks.first,
        );
        packer.appendTextBlock(
          block: block,
          blockText: chapterPlainText.substring(
            block.startUtf16,
            block.endUtf16,
          ),
          blockRuns: ir.runs,
          blockPlainStart: block.startUtf16,
          blockStyle: ir.style,
        );
      }
    }
    return packer.finish();
  }
}

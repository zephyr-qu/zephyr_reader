import 'package:zephyr_reader/core/reader_engine/layout/block_layout.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_spec.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/packed_page.dart'
    show ReaderIrBlockLayout;
import 'package:zephyr_reader/core/reader_engine/pagination/page_plan.dart';
import 'package:zephyr_reader/src/rust/pipeline/types.dart';

/// 页底保守余量（Phase 3 暂保留；Phase 6 根据实际误差统计决定最终值）。
const kPagePackBottomSlackDp = 8.0;

/// 内联图上下 padding（与 [EpubBlockImage] `EdgeInsets.symmetric(vertical: 4)` 对齐）。
const kInlineImageVerticalPaddingDp = 8.0;

/// 图片高度 fallback 比率。
const kDefaultImageHeightRatio = 0.55;

/// 纯几何页面装箱器 — 消费 [BlockLayout] 产生 [PagePlan]。
///
/// ADR-018：PagePacker 不直接理解字体、TextStyle、TextPainter。
/// 页面高度全部来自 [BlockLayout] 的真实 line height。
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

  int get plainEnd => _pageEnd;
  bool get hasEmittedPages => _pages.isNotEmpty || _pageHasContent;

  /// 添加文本块的布局结果。
  ///
  /// 每调用一次代表一个块的片段终止——自动 flush 上一个块的未完成 Fragment。
  void appendTextBlock({
    required BlockLayout block,
    required String blockText,
    required List<ReaderInlineRun> blockRuns,
    required int blockPlainStart,
    required BlockStyle blockStyle,
  }) {
    // Flush previous block's fragment if any
    if (_fragBuf.isNotEmpty) {
      _flushFragment(isBlockEnd: true);
    }
    // ponytail: paragraphsSpacing between blocks, not within
    final spacing = _prevBlockAllowsParagraphSpacing
        ? spec.paragraphSpacing
        : 0.0;
    final overhead = block.margins.vertical + spacing;

    for (final line in block.lines) {
      final lineH = line.height;
      final lineStart = blockPlainStart + line.startUtf16;
      final lineEnd = blockPlainStart + line.endUtf16;
      final lineText = blockText.substring(line.startUtf16, line.endUtf16);

      if (_fragBuf.isEmpty) {
        // Starting a new fragment
        var need = lineH + (_fragBuf.isEmpty ? overhead : 0.0);
        if (_pageHasContent && _used + need > packBudget) {
          _flushFragment(isBlockEnd: false);
          _flushPage();
          need = lineH + overhead;
        }
        _fragBlockIndex = block.blockIndex;
        _fragLocalStart = line.startUtf16;
        _fragIsBlockStart = _fragBuf.isEmpty;
        _pageStart ??= lineStart;
        _used += need;
      } else {
        if (_used + lineH > packBudget) {
          _flushFragment(isBlockEnd: false);
          _flushPage();
          _fragBlockIndex = block.blockIndex;
          _fragLocalStart = line.startUtf16;
          _fragIsBlockStart = false;
          _pageStart ??= lineStart;
          _used += lineH + overhead;
        } else {
          _used += lineH;
        }
      }
      _fragBuf.write(lineText);
      _pageEnd = lineEnd;
      _pageHasContent = true;
    }
    // ponytail: mark if next block should add paragraph spacing
    _prevBlockAllowsParagraphSpacing = blockStyle.marginBottomEm == null;
  }

  /// 添加图片块的布局结果。
  void appendImageBlock({
    required BlockLayout block,
    required int blockPlainStart,
    required double displayHeight,
    required String assetId,
    String? imageAlt,
    int? intrinsicWidth,
    int? intrinsicHeight,
  }) {
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
          imageLayout: ReaderIrBlockLayout.inlineContain,
        ),
      );
      _used += totalH;
      _pageHasContent = true;
      _prevBlockAllowsParagraphSpacing = false;
      return;
    }

    // Doesn't fit → full page.
    if (_pageHasContent) _flushPage();
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
    _flushPage();
  }

  /// Flush current fragment accumulator into a PageFragment.
  void _flushFragment({
    required bool isBlockEnd,
    BlockStyle? blockStyle,
  }) {
    if (_fragBuf.isEmpty) return;
    final text = _fragBuf.toString();
    final absStart = (_pageStart ?? 0) + _fragLocalStart;
    final absEnd = absStart + text.length;
    _fragments.add(
      PageFragment.text(
        blockIndex: _fragBlockIndex,
        startUtf16: absStart,
        endUtf16: absEnd,
        text: text,
        isBlockStart: _fragIsBlockStart,
        isBlockEnd: isBlockEnd,
        style: blockStyle,
      ),
    );
    _fragBuf.clear();
  }

  void _flushPage() {
    if (!_pageHasContent && _fragments.isEmpty) return;
    _pages.add(
      PagePlan(
        pageIndex: _pages.length,
        startUtf16: _pageStart ?? 0,
        endUtf16: _pageEnd,
        fragments: List.unmodifiable(_fragments),
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
    _flushFragment(isBlockEnd: true);
    if (_pageHasContent || _fragments.isNotEmpty || _pages.isEmpty) {
      _pages.add(
        PagePlan(
          pageIndex: _pages.length,
          startUtf16: _pageStart ?? 0,
          endUtf16: _pageEnd,
          fragments: List.unmodifiable(_fragments),
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
          (b) => b.plainStart <= block.startUtf16 &&
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

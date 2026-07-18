import 'package:flutter/foundation.dart';

import 'package:zephyr_reader/core/reader_engine/pagination/packed_page.dart'
    show PackedBlockSlice, PackedPage, ReaderIrBlockLayout;
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart'
    show BlockStyle, ReaderInlineRun;

/// 一页的完整描述。
///
/// ADR-018：分页器产生不可变 PagePlan，渲染器只消费计划，不重新解释页边界。
@immutable
class PagePlan {
  final int pageIndex;
  final int startUtf16;
  final int endUtf16;
  final List<PageFragment> fragments;
  final double usedHeight;
  final bool isLastPage;

  const PagePlan({
    required this.pageIndex,
    required this.startUtf16,
    required this.endUtf16,
    required this.fragments,
    this.usedHeight = 0,
    this.isLastPage = false,
  });

  // Phase 6 compat: maps to fragments for legacy consumers.
  List<PackedBlockSlice> get slices =>
      fragments.map((f) => f.toPackedSlice()).toList();

  /// Adapter: PagePlan → PackedPage（过渡期）。
  PackedPage toPackedPage() => PackedPage(
    pageIndex: pageIndex,
    startOffset: startUtf16,
    endOffset: endUtf16,
    slices: slices,
    isLastPage: isLastPage,
  );
}

/// 页内一块连续渲染片段。
@immutable
class PageFragment {
  final int blockIndex;
  final int startUtf16;
  final int endUtf16;
  final bool isBlockStart;
  final bool isBlockEnd;

  // 文本片段
  final String? text;
  final List<ReaderInlineRun> spans;
  final BlockStyle? style;

  // 图片片段
  final bool isImage;
  final String? assetId;
  final String? imageAlt;
  final int? intrinsicWidth;
  final int? intrinsicHeight;
  final double? imageDisplayWidth;
  final double? imageDisplayHeight;
  final ReaderIrBlockLayout? imageLayout;

  const PageFragment.text({
    required this.blockIndex,
    required this.startUtf16,
    required this.endUtf16,
    required this.text,
    this.spans = const [],
    this.style,
    this.isBlockStart = true,
    this.isBlockEnd = true,
  }) : isImage = false,
       assetId = null,
       imageAlt = null,
       intrinsicWidth = null,
       intrinsicHeight = null,
       imageDisplayWidth = null,
       imageDisplayHeight = null,
       imageLayout = null;

  const PageFragment.image({
    required this.blockIndex,
    required this.startUtf16,
    required this.endUtf16,
    required this.assetId,
    required this.imageLayout,
    this.imageAlt,
    this.intrinsicWidth,
    this.intrinsicHeight,
    this.imageDisplayWidth,
    this.imageDisplayHeight,
  }) : isImage = true,
       text = null,
       spans = const [],
       style = null,
       isBlockStart = true,
       isBlockEnd = true;

  /// Adapter: PageFragment → PackedBlockSlice（过渡期）。
  PackedBlockSlice toPackedSlice() {
    if (isImage) {
      return PackedBlockSlice.image(
        blockIndex: blockIndex,
        assetId: assetId ?? '',
        imageAlt: imageAlt,
        imageIntrinsicWidth: intrinsicWidth,
        imageIntrinsicHeight: intrinsicHeight,
        imageLayout: imageLayout ?? ReaderIrBlockLayout.inlineContain,
      );
    }
    return PackedBlockSlice.text(
      blockIndex: blockIndex,
      text: text ?? '',
      spans: spans,
      isBlockStart: isBlockStart,
      isBlockEnd: isBlockEnd,
      style: style,
    );
  }
}

/// PagePlan 集合的不变量验证。
final class PagePlanValidator {
  const PagePlanValidator._();

  /// 验证页面范围连续性：[i].endUtf16 == [i+1].startUtf16。
  static String? validateContinuity(List<PagePlan> pages) {
    for (var i = 0; i < pages.length - 1; i++) {
      if (pages[i].endUtf16 != pages[i + 1].startUtf16) {
        return 'Page $i end=${pages[i].endUtf16} != Page ${i + 1} start=${pages[i + 1].startUtf16}';
      }
    }
    return null;
  }

  /// 验证范围合法性：startUtf16 <= endUtf16。
  static String? validateRanges(List<PagePlan> pages) {
    for (final p in pages) {
      if (p.startUtf16 > p.endUtf16) {
        return 'Page ${p.pageIndex}: start=${p.startUtf16} > end=${p.endUtf16}';
      }
    }
    return null;
  }
}

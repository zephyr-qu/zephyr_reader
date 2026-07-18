import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';

/// Flutter 装箱页内块切片。
class PackedBlockSlice {
  const PackedBlockSlice.text({
    required this.blockIndex,
    required this.text,
    required this.isBlockStart,
    required this.isBlockEnd,
    required this.style,
    this.spans = const [],
  }) : isImage = false,
       assetId = null,
       imageAlt = null,
       imageIntrinsicWidth = null,
       imageIntrinsicHeight = null,
       imageLayout = null;

  const PackedBlockSlice.image({
    required this.blockIndex,
    required this.assetId,
    required this.imageLayout,
    this.imageAlt,
    this.imageIntrinsicWidth,
    this.imageIntrinsicHeight,
  }) : isImage = true,
       text = '',
       isBlockStart = true,
       isBlockEnd = true,
       style = null,
       spans = const [];

  final int blockIndex;
  final bool isImage;
  final String text;
  final String? assetId;
  final String? imageAlt;
  final int? imageIntrinsicWidth;
  final int? imageIntrinsicHeight;
  final bool isBlockStart;
  final bool isBlockEnd;
  final BlockStyle? style;
  final List<ReaderInlineRun> spans;

  /// 仅 Image 切片有效。
  final ReaderIrBlockLayout? imageLayout;
}

/// Flutter 装箱产出的一页。
class PackedPage {
  const PackedPage({
    required this.pageIndex,
    required this.startOffset,
    required this.endOffset,
    required this.slices,
    required this.isLastPage,
  });

  final int pageIndex;

  /// 章级 plain Unicode 半开区间 [startOffset, endOffset)。
  final int startOffset;
  final int endOffset;
  final List<PackedBlockSlice> slices;
  final bool isLastPage;
}

/// 页内 Image 块的排版方式（从 FRB block_pagination.dart 迁移到纯 Dart）。
enum ReaderIrBlockLayout {
  /// 剩余页高足够：缩放 contain，与文本同页。
  inlineContain,

  /// 放不下：独占一页（全屏 contain）。
  fullPage,
}

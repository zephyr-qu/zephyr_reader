import 'package:zephyr_reader/src/rust/domain/types/block_pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

/// Spike 页内块切片。
class SpikeBlockSlice {
  const SpikeBlockSlice.text({
    required this.blockIndex,
    required this.text,
    required this.isBlockStart,
    required this.isBlockEnd,
    required this.style,
    this.spans = const [],
  }) : isImage = false,
       assetId = null,
       alt = null,
       imageLayout = null;

  const SpikeBlockSlice.image({
    required this.blockIndex,
    required this.assetId,
    required this.imageLayout,
    this.alt,
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
  final String? alt;
  final bool isBlockStart;
  final bool isBlockEnd;
  final TextBlockStyle? style;
  final List<RichTextSpan> spans;

  /// 仅 Image 切片有效。
  final ImageBlockLayout? imageLayout;
}

/// Flutter 装箱产出的一页。
class SpikePage {
  const SpikePage({
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
  final List<SpikeBlockSlice> slices;
  final bool isLastPage;
}

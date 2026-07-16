import 'package:zephyr_reader/features/reader/core/data/scroll_layout_params.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_list_metrics.dart';
import 'package:zephyr_reader/features/reader/data/ir_types.dart';

/// 滚动模式下单章分段数据。
///
/// 每个 [ScrollChapterSegment] 对应一个章节的段落序列，
/// 供 [ScrollDocumentComposer] 拼接多章时使用。
/// 可选 [irBlocks] + [chapterFilePath] 与 pagination 同源 IR。
class ScrollChapterSegment {
  final int chapterIndex;
  final List<String> paragraphs;
  final List<int> paragraphCharOffsets;
  final List<ReaderIrBlock>? irBlocks;
  final String? chapterFilePath;
  final ScrollListMetrics listMetrics;

  ScrollChapterSegment({
    required this.chapterIndex,
    required this.paragraphs,
    required this.paragraphCharOffsets,
    this.irBlocks,
    this.chapterFilePath,
    ScrollListMetrics? listMetrics,
  }) : listMetrics =
           listMetrics ??
           (irBlocks != null && irBlocks.isNotEmpty
               ? computeScrollIrListMetrics(blocks: irBlocks)
               : computeScrollListMetrics(
                   paragraphs: paragraphs,
                   paragraphCharOffsets: paragraphCharOffsets,
                 ));

  bool get isIr => irBlocks != null && irBlocks!.isNotEmpty;

  /// 检查 IR 块列表中是否包含图片块。
  bool get hasImages =>
      irBlocks?.any((b) => b.kind == ReaderIrBlockKind.image) ?? false;

  /// ListView 项数（与渲染扁平化一致；含图片时可能 > [paragraphs].length）。
  int get paragraphCount => listMetrics.itemCount;

  int get totalCharLength {
    if (isIr) {
      var end = 0;
      for (final block in irBlocks!) {
        final range = block.plainStart + block.plainLen;
        if (range > end) end = range;
      }
      return end;
    }
    return paragraphCharOffsets.isNotEmpty
        ? paragraphCharOffsets.last +
              paragraphs.last.length +
              2 /* trailing newline pair */
        : 0;
  }

  /// 带排版参数的 ListView 度量（含图片项高度估算）。
  ScrollListMetrics metricsFor(ScrollLayoutParams layout) {
    if (isIr) {
      return computeScrollIrListMetrics(blocks: irBlocks!, layout: layout);
    }
    return computeScrollListMetrics(
      paragraphs: paragraphs,
      paragraphCharOffsets: paragraphCharOffsets,
      layout: layout,
    );
  }

  /// 根据章节内 charOffset 查找段落索引（含值，即段落起点）。
  /// 返回 -1 当 offset 超出范围。
  int paragraphIndexForCharOffset(int charOffset) {
    var lo = 0;
    var hi = paragraphCharOffsets.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (paragraphCharOffsets[mid] <= charOffset) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo - 1;
  }
}

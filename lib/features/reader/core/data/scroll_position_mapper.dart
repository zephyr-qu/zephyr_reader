import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_layout_params.dart';

/// 多段滚动列表：章内 charOffset ↔ scrollOffset 映射。
class ScrollPositionMapper {
  const ScrollPositionMapper._();

  /// 将 [chapterIndex] 章内 [charOffset] 映射为 ListView scrollOffset。
  ///
  /// 含图段使用 [ScrollListMetrics.itemExtents]；纯文段 fallback 到均匀段高。
  static double scrollOffsetForChar(
    List<ScrollChapterSegment> segments,
    int chapterIndex,
    int charOffset,
    ScrollLayoutParams layout,
  ) {
    if (segments.isEmpty) return 0;

    var globalOffset = 0.0;
    for (final seg in segments) {
      if (seg.chapterIndex != chapterIndex) {
        globalOffset += _segmentScrollExtent(seg, layout);
        continue;
      }

      final metrics = seg.metricsFor(layout);
      final localItem = metrics.itemIndexForCharOffset(charOffset);
      final itemStart = metrics.charOffsetAt(localItem);
      final charLen = metrics.charLengthAt(localItem);
      var inItemRatio = 0.0;
      if (charLen > 0 && charOffset > itemStart) {
        inItemRatio = ((charOffset - itemStart) / charLen).clamp(0.0, 1.0);
      }
      return globalOffset +
          metrics.scrollOffsetForLocalItem(
            localItem,
            inItemRatio: inItemRatio,
            uniformFallback: layout.uniformTextExtent,
          );
    }

    return 0;
  }

  static double _segmentScrollExtent(
    ScrollChapterSegment seg,
    ScrollLayoutParams layout,
  ) => seg
      .metricsFor(layout)
      .totalScrollExtent(uniformFallback: layout.uniformTextExtent);
}

import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';

/// 多段滚动列表：章内 charOffset ↔ scrollOffset 近似映射。
class ScrollPositionMapper {
  const ScrollPositionMapper._();

  /// 将 [chapterIndex] 章内 [charOffset] 映射为 ListView scrollOffset（均匀段高模型）。
  static double scrollOffsetForChar(
    List<ScrollChapterSegment> segments,
    int chapterIndex,
    int charOffset,
    double paragraphExtent,
  ) {
    if (segments.isEmpty || paragraphExtent <= 0) return 0;

    var globalParagraph = 0;
    for (final seg in segments) {
      if (seg.chapterIndex != chapterIndex) {
        globalParagraph += seg.paragraphCount;
        continue;
      }

      final localPara = seg.paragraphIndexForCharOffset(charOffset);
      if (localPara < 0) {
        return globalParagraph * paragraphExtent;
      }

      var offset = globalParagraph * paragraphExtent;
      offset += localPara * paragraphExtent;

      if (localPara < seg.paragraphs.length) {
        final paraStart = seg.paragraphCharOffsets[localPara];
        final paraText = seg.paragraphs[localPara];
        if (paraText.isNotEmpty && charOffset > paraStart) {
          final ratio =
              ((charOffset - paraStart) / paraText.length).clamp(0.0, 1.0);
          offset += ratio * paragraphExtent;
        }
      }
      return offset;
    }

    return 0;
  }
}

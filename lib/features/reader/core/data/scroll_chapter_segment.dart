/// 滚动模式下单章分段数据。
///
/// 每个 [ScrollChapterSegment] 对应一个章节的文本段落序列，
/// 供 [ScrollDocumentComposer] 拼接多章时使用。
class ScrollChapterSegment {
  final int chapterIndex;
  final List<String> paragraphs;
  final List<int> paragraphCharOffsets;

  const ScrollChapterSegment({
    required this.chapterIndex,
    required this.paragraphs,
    required this.paragraphCharOffsets,
  });

  int get paragraphCount => paragraphs.length;

  int get totalCharLength =>
      paragraphCharOffsets.isNotEmpty
          ? paragraphCharOffsets.last +
              paragraphs.last.length +
              2 /* trailing newline pair */
          : 0;

  /// 根据章节内 charOffset 查找段落索引（含值，即段落起点）。
  /// 返回 -1 当 offset 超出范围。
  int paragraphIndexForCharOffset(int charOffset) {
    // paragraphCharOffsets 是升序的
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

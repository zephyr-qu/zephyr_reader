import 'package:flutter/material.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

/// 滚动模式下单章分段数据。
///
/// 每个 [ScrollChapterSegment] 对应一个章节的段落序列，
/// 供 [ScrollDocumentComposer] 拼接多章时使用。
/// Phase 2：可选 [richParagraphs] / [richRootSpan] 支持 EPUB/MD 富文本与图片。
class ScrollChapterSegment {
  final int chapterIndex;
  final List<String> paragraphs;
  final List<int> paragraphCharOffsets;
  final List<RichParagraph>? richParagraphs;
  final TextSpan? richRootSpan;

  const ScrollChapterSegment({
    required this.chapterIndex,
    required this.paragraphs,
    required this.paragraphCharOffsets,
    this.richParagraphs,
    this.richRootSpan,
  });

  bool get isRich => richParagraphs != null && richParagraphs!.isNotEmpty;

  bool get hasImages => richParagraphs?.any((p) => p.isImage) ?? false;

  /// ListView item 数：富文本按 RichParagraph（含图片），纯文本按段落。
  int get paragraphCount =>
      isRich ? richParagraphs!.length : paragraphs.length;

  int get totalCharLength =>
      paragraphCharOffsets.isNotEmpty
          ? paragraphCharOffsets.last +
              paragraphs.last.length +
              2 /* trailing newline pair */
          : 0;

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

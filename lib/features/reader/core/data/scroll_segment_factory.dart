import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_payload.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_list_metrics.dart';

/// 将章节加载结果转为 [ScrollChapterSegment]。
class ScrollSegmentFactory {
  const ScrollSegmentFactory._();

  static ScrollChapterSegment fromPayload(
    int chapterIndex,
    ScrollChapterPayload payload,
  ) {
    final ir = payload.chapterIr;
    if (ir != null && ir.blocks.isNotEmpty) {
      return ScrollChapterSegment(
        chapterIndex: chapterIndex,
        paragraphs: const [],
        paragraphCharOffsets: const [],
        irBlocks: ir.blocks,
        chapterFilePath: payload.chapterFilePath,
        listMetrics: computeScrollIrListMetrics(blocks: ir.blocks),
      );
    }

    final paragraphs = payload.content
        .split('\n\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    var acc = 0;
    final offsets = paragraphs.map((p) {
      final o = acc;
      acc += p.length + 2;
      return o;
    }).toList();
    return ScrollChapterSegment(
      chapterIndex: chapterIndex,
      paragraphs: paragraphs,
      paragraphCharOffsets: offsets,
      richParagraphs: payload.richParagraphs,
      richRootSpan: payload.richRootSpan,
      chapterFilePath: payload.chapterFilePath,
    );
  }
}

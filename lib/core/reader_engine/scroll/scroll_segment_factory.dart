import 'package:zephyr_reader/core/reader_engine/scroll/scroll_chapter_segment.dart';
import 'package:zephyr_reader/core/reader_engine/scroll/scroll_list_metrics.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';


/// 滚动拼接用单章加载结果（不依赖仓库 current* 单例）。
typedef ScrollChapterPayload = ({
  String content,
  ReaderChapterIr? chapterIr,
  String? chapterFilePath,
});

/// 纯文本章节 payload。
ScrollChapterPayload scrollPlainPayload(
  String content, {
  ReaderChapterIr? chapterIr,
  String? chapterFilePath,
}) => (
  content: content,
  chapterIr: chapterIr,
  chapterFilePath: chapterFilePath,
);

/// IR 章节 payload（scroll 主路径，ADR-009）。
ScrollChapterPayload scrollIrPayload({
  required ReaderChapterIr chapterIr,
  required String chapterFilePath,
}) => (
  content: chapterIr.plainText,
  chapterIr: chapterIr,
  chapterFilePath: chapterFilePath,
);

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
      chapterFilePath: payload.chapterFilePath,
    );
  }
}

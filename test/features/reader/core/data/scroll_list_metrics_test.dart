import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_list_metrics.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

void main() {
  group('computeScrollListMetrics', () {
    test('plain 段与 paragraphs 对齐', () {
      final metrics = computeScrollListMetrics(
        paragraphs: const ['a', 'b'],
        paragraphCharOffsets: const [0, 3],
      );
      expect(metrics.itemCount, 2);
      expect(metrics.charOffsets, [0, 3]);
      expect(metrics.charLengths, [1, 1]);
    });

    test('含图片 rich 段 itemCount 大于 plain paragraphs', () {
      final paragraphs = List.generate(10, (i) => 'p$i');
      final offsets = List.generate(10, (i) => i * 5);
      final rich = <RichParagraph>[
        for (var i = 0; i < 10; i++)
          RichParagraph(
            spans: const [],
            indent: 0,
            isHeading: false,
            headingLevel: 0,
            isImage: false,
            imageData: Uint8List(0),
          ),
        RichParagraph(
          spans: const [],
          indent: 0,
          isHeading: false,
          headingLevel: 0,
          isImage: true,
          imageData: Uint8List(0),
        ),
      ];
      final seg = ScrollChapterSegment(
        chapterIndex: 0,
        paragraphs: paragraphs,
        paragraphCharOffsets: offsets,
        richParagraphs: rich,
      );
      expect(seg.paragraphCount, 11);
      expect(seg.listMetrics.charLengths.last, 1);
    });
  });
}

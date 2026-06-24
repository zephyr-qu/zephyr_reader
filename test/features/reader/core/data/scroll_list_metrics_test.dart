import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_layout_params.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_list_metrics.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

Uint8List _fakePngDimensions(int width, int height) {
  final bytes = Uint8List(24);
  bytes[0] = 0x89;
  bytes[1] = 0x50;
  bytes[2] = 0x4E;
  bytes[3] = 0x47;
  bytes[16] = (width >> 24) & 0xFF;
  bytes[17] = (width >> 16) & 0xFF;
  bytes[18] = (width >> 8) & 0xFF;
  bytes[19] = width & 0xFF;
  bytes[20] = (height >> 24) & 0xFF;
  bytes[21] = (height >> 16) & 0xFF;
  bytes[22] = (height >> 8) & 0xFF;
  bytes[23] = height & 0xFF;
  return bytes;
}

void main() {
  const layout = ScrollLayoutParams(
    textRowHeight: 24,
    paragraphSpacing: 16,
    contentWidth: 400,
    fontSize: 16,
  );

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

    test('含图片时 itemExtents 高于纯文本 uniform 高度', () {
      final paragraphs = const ['before', 'after'];
      final offsets = const [0, 10];
      final rich = <RichParagraph>[
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
          imageData: _fakePngDimensions(800, 600),
        ),
        RichParagraph(
          spans: const [],
          indent: 0,
          isHeading: false,
          headingLevel: 0,
          isImage: false,
          imageData: Uint8List(0),
        ),
      ];
      final metrics = computeScrollListMetrics(
        paragraphs: paragraphs,
        paragraphCharOffsets: offsets,
        richParagraphs: rich,
        layout: layout,
      );
      expect(metrics.hasItemExtents, isTrue);
      expect(metrics.itemExtents[1], greaterThan(layout.uniformTextExtent));
    });

    test('readImageDimensions 解析 PNG 头部', () {
      final dims = readImageDimensions(_fakePngDimensions(320, 240));
      expect(dims?.$1, 320);
      expect(dims?.$2, 240);
    });
  });
}

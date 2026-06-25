import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_payload.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_segment_factory.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

void main() {
  group('ScrollSegmentFactory', () {
    test('plain payload produces non-rich segment', () {
      final payload = scrollPlainPayload('Para one.\n\nPara two.');
      final seg = ScrollSegmentFactory.fromPayload(0, payload);
      expect(seg.isRich, isFalse);
      expect(seg.isIr, isFalse);
      expect(seg.paragraphCount, 2);
      expect(seg.paragraphs.first, 'Para one.');
    });

    test('IR payload produces isIr segment with image block', () {
      const style = TextBlockStyle(
        isHeading: false,
        headingLevel: 0,
        textIndentEm: null,
        marginTopEm: null,
        marginBottomEm: null,
        fontFamily: null,
        lineHeight: null,
        textAlign: null,
      );
      final ir = ChapterContentIr(
        plainText: 'Text\uFFFC',
        blocks: [
          ContentBlock.text(
            TextBlock(
              plain: BlockPlainRange(plainStart: 0, plainLen: 4),
              text: 'Text',
              style: style,
              spans: const [],
            ),
          ),
          ContentBlock.image(
            ImageBlock(
              plain: BlockPlainRange(plainStart: 4, plainLen: 1),
              assetId: 'cover',
            ),
          ),
        ],
      );
      final seg = ScrollSegmentFactory.fromPayload(
        2,
        scrollIrPayload(chapterIr: ir, chapterFilePath: '/x.epub'),
      );
      expect(seg.isIr, isTrue);
      expect(seg.isRich, isFalse);
      expect(seg.irBlocks, hasLength(2));
      expect(seg.chapterFilePath, '/x.epub');
      expect(seg.paragraphCount, 2);
    });

    test('rich payload sets isRich and paragraphCount from richParagraphs', () {
      final richParagraphs = [
        RichParagraph(
          spans: [
            RichTextSpan.styled(
              SpanStyle.plain,
              const RichTextSpanData(text: 'Title'),
            ),
          ],
          indent: 0,
          isHeading: true,
          headingLevel: 1,
          isImage: false,
          imageData: Uint8List(0),
        ),
        RichParagraph(
          spans: [
            RichTextSpan.styled(
              SpanStyle.plain,
              const RichTextSpanData(text: 'Body'),
            ),
          ],
          indent: 0,
          isHeading: false,
          headingLevel: 0,
          isImage: false,
          imageData: Uint8List(0),
        ),
      ];
      final payload = (
        content: 'Title\n\nBody',
        richParagraphs: richParagraphs,
        richRootSpan: const TextSpan(
          children: [
            TextSpan(text: 'Title'),
            TextSpan(text: '\n\n'),
            TextSpan(text: 'Body'),
          ],
        ),
        epubRichSkipped: false,
        chapterIr: null as ChapterContentIr?,
        chapterFilePath: null as String?,
      );
      final seg = ScrollSegmentFactory.fromPayload(1, payload);
      expect(seg.isRich, isTrue);
      expect(seg.paragraphCount, 2);
      expect(seg.richRootSpan, isNotNull);
    });

    test('hasImages when any rich paragraph is image', () {
      final payload = (
        content: 'text',
        richParagraphs: [
          RichParagraph(
            spans: const [],
            indent: 0,
            isHeading: false,
            headingLevel: 0,
            isImage: true,
            imageData: Uint8List.fromList([1, 2, 3]),
          ),
        ],
        richRootSpan: null as TextSpan?,
        epubRichSkipped: false,
        chapterIr: null as ChapterContentIr?,
        chapterFilePath: null as String?,
      );
      final seg = ScrollSegmentFactory.fromPayload(0, payload);
      expect(seg.hasImages, isTrue);
    });
  });
}

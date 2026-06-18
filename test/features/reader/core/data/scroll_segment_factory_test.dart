import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_segment_factory.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

void main() {
  group('ScrollSegmentFactory', () {
    test('plain payload produces non-rich segment', () {
      final payload = (
        content: 'Para one.\n\nPara two.',
        richParagraphs: null as List<RichParagraph>?,
        richRootSpan: null as TextSpan?,
        epubRichSkipped: false,
      );
      final seg = ScrollSegmentFactory.fromPayload(0, payload);
      expect(seg.isRich, isFalse);
      expect(seg.paragraphCount, 2);
      expect(seg.paragraphs.first, 'Para one.');
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
        richRootSpan: const TextSpan(text: 'Title\n\nBody'),
        epubRichSkipped: false,
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
      );
      final seg = ScrollSegmentFactory.fromPayload(0, payload);
      expect(seg.hasImages, isTrue);
    });
  });
}

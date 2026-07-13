import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_payload.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_segment_factory.dart';

void main() {
  group('ScrollSegmentFactory', () {
    test('plain payload produces non-IR segment', () {
      final payload = scrollPlainPayload('Para one.\n\nPara two.');
      final seg = ScrollSegmentFactory.fromPayload(0, payload);
      expect(seg.isIr, isFalse);
      expect(seg.paragraphCount, 2);
      expect(seg.paragraphs.first, 'Para one.');
    });

    test('plain payload with content split produces correct paragraphs', () {
      final payload = scrollPlainPayload('Line A.\n\nLine B.\n\nLine C.');
      final seg = ScrollSegmentFactory.fromPayload(0, payload);
      expect(seg.paragraphCount, 3);
      expect(seg.paragraphs[0], 'Line A.');
      expect(seg.paragraphs[1], 'Line B.');
      expect(seg.paragraphs[2], 'Line C.');
      expect(seg.chapterFilePath, isNull);
    });
  });
}

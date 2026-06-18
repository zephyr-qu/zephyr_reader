import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_position_mapper.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_segment_factory.dart';

void main() {
  group('ScrollPositionMapper', () {
    test('scrollOffsetForChar 映射到正确段落区间', () {
      final seg = ScrollSegmentFactory.fromPayload(
        1,
        (content: 'AAAA\n\nBBBB\n\nCCCC', richParagraphs: null, richRootSpan: null, epubRichSkipped: false),
      );
      const extent = 100.0;

      expect(
        ScrollPositionMapper.scrollOffsetForChar([seg], 1, 0, extent),
        0,
      );
      expect(
        ScrollPositionMapper.scrollOffsetForChar([seg], 1, 6, extent),
        extent,
      );
      expect(
        ScrollPositionMapper.scrollOffsetForChar([seg], 1, 10, extent),
        greaterThan(extent),
      );
    });

    test('多段时累加前序段落高度', () {
      final seg0 = ScrollSegmentFactory.fromPayload(
        0,
        (content: 'Ch0\n\nP2', richParagraphs: null, richRootSpan: null, epubRichSkipped: false),
      );
      final seg1 = ScrollSegmentFactory.fromPayload(
        1,
        (content: 'Ch1\n\nP2', richParagraphs: null, richRootSpan: null, epubRichSkipped: false),
      );
      const extent = 50.0;

      final offset = ScrollPositionMapper.scrollOffsetForChar(
        [seg0, seg1],
        1,
        0,
        extent,
      );
      expect(offset, seg0.paragraphCount * extent);
    });
  });
}

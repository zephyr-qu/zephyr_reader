import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_layout_params.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_position_mapper.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_segment_factory.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_payload.dart';

void main() {
  const layout = ScrollLayoutParams(
    textRowHeight: 88,
    paragraphSpacing: 12,
    contentWidth: 360,
    fontSize: 16,
  );

  group('ScrollPositionMapper', () {
    test('scrollOffsetForChar 映射到正确段落区间', () {
      final seg = ScrollSegmentFactory.fromPayload(
        1,
        scrollPlainPayload('AAAA\n\nBBBB\n\nCCCC'),
      );

      expect(
        ScrollPositionMapper.scrollOffsetForChar([seg], 1, 0, layout),
        0,
      );
      expect(
        ScrollPositionMapper.scrollOffsetForChar([seg], 1, 6, layout),
        layout.uniformTextExtent,
      );
      expect(
        ScrollPositionMapper.scrollOffsetForChar([seg], 1, 10, layout),
        greaterThan(layout.uniformTextExtent),
      );
    });

    test('多段时累加前序段落高度', () {
      final seg0 = ScrollSegmentFactory.fromPayload(
        0,
        scrollPlainPayload('Ch0\n\nP2'),
      );
      final seg1 = ScrollSegmentFactory.fromPayload(
        1,
        scrollPlainPayload('Ch1\n\nP2'),
      );

      final offset = ScrollPositionMapper.scrollOffsetForChar(
        [seg0, seg1],
        1,
        0,
        layout,
      );
      expect(
        offset,
        seg0.metricsFor(layout).totalScrollExtent(
              uniformFallback: layout.uniformTextExtent,
            ),
      );
    });
  });
}

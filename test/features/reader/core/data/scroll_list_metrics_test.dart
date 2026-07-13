import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_list_metrics.dart';

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

    test('空 paragraphs 返回空的 metrics', () {
      final metrics = computeScrollListMetrics(
        paragraphs: const [],
        paragraphCharOffsets: const [],
      );
      expect(metrics.itemCount, 0);
      expect(metrics.charOffsets, isEmpty);
      expect(metrics.charLengths, isEmpty);
    });
  });
}

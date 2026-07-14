import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';

void main() {
  group('paginatedTypesetLayoutInsets', () {
    test('用实测行高留半行 buffer', () {
      final insets = paginatedTypesetLayoutInsets(
        fontSize: 18,
        lineHeight: 1.5, // 27dp 名义行高
        measuredLineHeightDp: 32, // 正文平均行高
      );
      expect(insets.contentVerticalPadding, 20);
      expect(insets.pageHeightLineBuffer, closeTo(16.0, 0.01));
    });

    test('无实测时用 fontSize×lineHeight 的一半', () {
      final insets = paginatedTypesetLayoutInsets(
        fontSize: 16,
        lineHeight: 1.5, // 24dp
      );
      expect(insets.pageHeightLineBuffer, closeTo(12.0, 0.01));
    });
  });
}

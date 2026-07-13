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

  group('estimateRustLinesForText', () {
    test('首行缩进增加行数', () {
      const text = '这是一段用于测试断行估算的中文文本内容';
      final linesNoIndent = estimateRustLinesForText(
        text: text,
        applyFirstLineIndent: false,
        cjkWidthPx: 48,
        pageWidthPx: 960,
        fontSizePx: 48,
      );
      final linesWithIndent = estimateRustLinesForText(
        text: text,
        applyFirstLineIndent: true,
        cjkWidthPx: 48,
        pageWidthPx: 960,
        fontSizePx: 48,
      );
      expect(linesWithIndent, greaterThanOrEqualTo(linesNoIndent));
    });
  });

  group('estimateRustMaxLineWidthPx', () {
    test('uses ratio', () {
      final width1 = estimateRustMaxLineWidthPx(
        pageWidthPx: 1000,
        fontSizePx: 48,
        effectiveLineWidthRatio: 0.98,
      );
      final width2 = estimateRustMaxLineWidthPx(
        pageWidthPx: 1000,
        fontSizePx: 48,
        effectiveLineWidthRatio: 0.97,
      );
      expect(width1, closeTo(980.0, 0.01)); // 1000 * 0.98
      expect(width2, closeTo(970.0, 0.01)); // 1000 * 0.97
      expect(width1, greaterThan(width2));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';

void main() {
  group('buildTypesetConfig', () {
    test('基本参数转换', () {
      final config = buildTypesetConfig(
        width: 360,
        height: 640,
        fontSize: 16,
        lineHeight: 1.5,
        paragraphSpacing: 32, // 32/16 = 2.0
      );

      expect(config.pageWidth, equals(328)); // (360-32)*1.0
      expect(config.pageHeight, equals(640)); // 640 * 1.0 ≈ 640
      expect(config.fontSize, equals(16));
      expect(config.lineSpacing, equals(1.5));
      expect(config.paragraphSpacing, equals(2.0));
      expect(config.letterSpacing, equals(0));
      expect(config.firstLineIndent, equals(2));
      expect(config.language, equals(LanguageType.auto));
      expect(config.punctuationSqueeze, isTrue);
      expect(config.fontFamily, equals('Noto Sans SC'));
      expect(config.calibration, isNotNull);
    });

    test('像素值四舍五入', () {
      final config = buildTypesetConfig(
        width: 360.7,
        height: 640.4,
        fontSize: 16.3,
        lineHeight: 1.5,
        devicePixelRatio: 2.0,
      );

      // (360.7-32)*2 = 657.4 → round → 657
      expect(config.pageWidth, equals(657)); // (360.7-32)*2.0
      // 640.4 * 2 = 1280.8 → round → 1281
      expect(config.pageHeight, equals(1281));
      // 16.3 * 2 = 32.6 → round → 33
      expect(config.fontSize, equals(33));
    });

    test('自定义 padding 被正确转换（pageWidth/Height 减去 padding*2）', () {
      // buildTypesetConfig 不直接处理 padding 减法的逻辑
      // padding 参数由调用方在传入前处理，此处验证 padding 本身不影响 width/height
      final config = buildTypesetConfig(
        width: 400,
        height: 700,
        fontSize: 14,
        lineHeight: 1.6,
        padding: 24,
      );

      // padding 参数不影响计算结果
      expect(config.pageWidth, equals(352)); // (400-48)*1.0
      expect(config.pageHeight, equals(700));
    });

    test('自定义 devicePixelRatio', () {
      final config = buildTypesetConfig(
        width: 360,
        height: 640,
        fontSize: 16,
        lineHeight: 1.5,
        devicePixelRatio: 3.0,
      );

      expect(config.pageWidth, equals(984)); // (360-32)*3
      expect(config.pageHeight, equals(1920)); // 640 * 3
      expect(config.fontSize, equals(48)); // 16 * 3
    });

    test('自定义 firstLineIndent', () {
      final config = buildTypesetConfig(
        width: 360,
        height: 640,
        fontSize: 16,
        lineHeight: 1.5,
        firstLineIndent: 4,
      );

      expect(config.firstLineIndent, equals(4));
    });

    test('自定义 fontFamily', () {
      final config = buildTypesetConfig(
        width: 360,
        height: 640,
        fontSize: 16,
        lineHeight: 1.5,
        fontFamily: 'LXGW WenKai',
      );

      expect(config.fontFamily, equals('LXGW WenKai'));
    });

    test('contentVerticalPadding 扣减 pageHeight（line buffer 默认 0）', () {
      final config = buildTypesetConfig(
        width: 360,
        height: 800,
        fontSize: 16,
        lineHeight: 1.5,
        contentVerticalPadding: 20,
        devicePixelRatio: 2.0,
      );

      // contentHeight = 800 - 40 = 760 → 1520 px
      expect(config.pageHeight, equals(1520));
    });

    test('paginatedTypesetLayoutInsets 用实测行高留半行 buffer', () {
      final insets = paginatedTypesetLayoutInsets(
        fontSize: 18,
        lineHeight: 1.5, // 27dp 名义行高
        measuredLineHeightDp: 32, // 正文平均行高
      );
      expect(insets.contentVerticalPadding, 20);
      expect(insets.pageHeightLineBuffer, closeTo(16.0, 0.01));
    });

    test('paginatedTypesetLayoutInsets 无实测时用 fontSize×lineHeight 的一半', () {
      final insets = paginatedTypesetLayoutInsets(
        fontSize: 16,
        lineHeight: 1.5, // 24dp
      );
      expect(insets.pageHeightLineBuffer, closeTo(12.0, 0.01));
    });

    test('显式 pageHeightLineBuffer 仍可额外扣减', () {
      final config = buildTypesetConfig(
        width: 360,
        height: 800,
        fontSize: 16,
        lineHeight: 1.5,
        contentVerticalPadding: 20,
        pageHeightLineBuffer: 52,
        devicePixelRatio: 2.0,
      );

      // contentHeight = 800 - 40 - 52 = 708 → 1416 px
      expect(config.pageHeight, equals(1416));
    });

    test('estimateRustLinesForText 首行缩进增加行数', () {
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

    test('calibration 默认使用标准字宽', () {
      final config = buildTypesetConfig(
        width: 360,
        height: 640,
        fontSize: 16,
        lineHeight: 1.5,
        devicePixelRatio: 2.0,
      );

      expect(config.calibration, isNotNull);
      expect(config.calibration!.cjkWidth, closeTo(32.0, 0.01)); // 16*2
      expect(config.calibration!.effectiveLineWidthRatio, closeTo(1.0, 0.001));
    });

    test('A8 estimateRustMaxLineWidth uses ratio', () {
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

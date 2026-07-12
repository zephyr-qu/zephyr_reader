import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/features/reader/data/layout_calibration_store.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';

class _MockPrefs extends Mock implements PreferencesService {}

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

    test('paginatedTypesetLayoutInsets 用实测行高留满一行 buffer', () {
      final insets = paginatedTypesetLayoutInsets(
        fontSize: 18,
        lineHeight: 1.5, // 27dp 名义行高
        measuredLineHeightDp: 32, // strut 实测
      );
      expect(insets.contentVerticalPadding, 20);
      expect(insets.pageHeightLineBuffer, closeTo(32.0, 0.01));
    });

    test('paginatedTypesetLayoutInsets 无实测时用 fontSize×lineHeight', () {
      final insets = paginatedTypesetLayoutInsets(
        fontSize: 16,
        lineHeight: 1.5, // 24dp
      );
      expect(insets.pageHeightLineBuffer, closeTo(24.0, 0.01));
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

    group('calibration 参数', () {
      test('null calibration 使用 default 字宽并仍传给 Rust', () {
        final config = buildTypesetConfig(
          width: 360,
          height: 640,
          fontSize: 16,
          lineHeight: 1.5,
          devicePixelRatio: 2.0,
          calibration: null,
        );

        expect(config.calibration, isNotNull);
        expect(config.calibration!.cjkWidth, closeTo(32.0, 0.01)); // 16*2
      });

      test('有 calibration 时正确转换', () {
        final cal = const CalibrationData(
          dpr: 2.0,
          cjkWidth: 18.0,
          asciiWidth: 9.5,
          digitWidth: 9.0,
          punctWidth: 17.5,
          latinExtWidth: 13.0,
          otherWidth: 14.0,
          effectiveLineWidthRatio: 0.97,
          lineHeightDp: 24.0,
        );
        final config = buildTypesetConfig(
          width: 360,
          height: 640,
          fontSize: 16,
          lineHeight: 1.5,
          calibration: cal,
        );

        final rust = calibrationToRust(cal);
        expect(config.calibration, equals(rust));
        expect(config.calibration!.dpr, equals(2.0));
      });

      test('calibration dpr 与 devicePixelRatio 独立', () {
        final cal = const CalibrationData(
          dpr: 2.0,
          cjkWidth: 18.0,
          asciiWidth: 9.5,
          digitWidth: 9.0,
          punctWidth: 17.5,
          latinExtWidth: 13.0,
          otherWidth: 14.0,
          effectiveLineWidthRatio: 0.97,
          lineHeightDp: 24.0,
        );
        final config = buildTypesetConfig(
          width: 360,
          height: 640,
          fontSize: 16,
          lineHeight: 1.5,
          devicePixelRatio: 1.5,
          calibration: cal,
        );

        // pageWidth 使用 devicePixelRatio(1.5)，不是 calibration.dpr(2.0)
        expect(config.pageWidth, equals(492)); // (360-32)*1.5
        expect(config.calibration!.dpr, equals(2.0));
      });
    });

    group('calibrateFromPageText', () {
      test('空文本返回 null', () {
        expect(
          calibrateFromPageText(
            pageText: '',
            fontSize: 16,
            devicePixelRatio: 1.0,
            fontFamily: 'Roboto',
          ),
          isNull,
        );
      });

      test('calibrationDriftExceeds 检测相对漂移', () {
        const baseline = CalibrationData(
          dpr: 1.0,
          cjkWidth: 16.0,
          asciiWidth: 9.6,
          digitWidth: 9.6,
          punctWidth: 16.0,
          latinExtWidth: 10.0,
          otherWidth: 12.0,
          effectiveLineWidthRatio: 0.97,
          lineHeightDp: 24.0,
        );
        const smallDrift = CalibrationData(
          dpr: 1.0,
          cjkWidth: 16.4,
          asciiWidth: 9.6,
          digitWidth: 9.6,
          punctWidth: 16.0,
          latinExtWidth: 10.0,
          otherWidth: 12.0,
          effectiveLineWidthRatio: 0.97,
          lineHeightDp: 24.0,
        );
        const largeDrift = CalibrationData(
          dpr: 1.0,
          cjkWidth: 18.0,
          asciiWidth: 9.6,
          digitWidth: 9.6,
          punctWidth: 16.0,
          latinExtWidth: 10.0,
          otherWidth: 12.0,
          effectiveLineWidthRatio: 0.97,
          lineHeightDp: 24.0,
        );

        expect(calibrationDriftExceeds(baseline, smallDrift), isFalse);
        expect(calibrationDriftExceeds(baseline, largeDrift), isTrue);
      });

      test('isCalibrationPlausible 拒绝异常 CJK 比例', () {
        const plausible = CalibrationData(
          dpr: 1.0,
          cjkWidth: 16.0,
          asciiWidth: 9.6,
          digitWidth: 9.6,
          punctWidth: 16.0,
          latinExtWidth: 10.0,
          otherWidth: 12.0,
          effectiveLineWidthRatio: 0.97,
          lineHeightDp: 24.0,
        );
        const tooWide = CalibrationData(
          dpr: 1.0,
          cjkWidth: 30.0,
          asciiWidth: 9.6,
          digitWidth: 9.6,
          punctWidth: 16.0,
          latinExtWidth: 10.0,
          otherWidth: 12.0,
          effectiveLineWidthRatio: 0.97,
          lineHeightDp: 24.0,
        );

        expect(isCalibrationPlausible(plausible, 16.0), isTrue);
        expect(isCalibrationPlausible(tooWide, 16.0), isFalse);
      });

      test('calibrationToRust 映射 latinExtWidth', () {
        const cal = CalibrationData(
          dpr: 2.0,
          cjkWidth: 18.0,
          asciiWidth: 9.5,
          digitWidth: 9.0,
          punctWidth: 17.5,
          latinExtWidth: 13.0,
          otherWidth: 14.0,
          effectiveLineWidthRatio: 0.985,
          lineHeightDp: 24.0,
        );
        final rust = calibrationToRust(cal);
        expect(rust.latinExtWidth, closeTo(26.0, 0.01)); // 13*2
        expect(rust.effectiveLineWidthRatio, closeTo(0.985, 0.001));
        expect(rust.measuredLineHeightPx, closeTo(48.0, 0.01)); // 24*2
      });

      test('measureLayoutFingerprint 产出合理 ratio 与行高', () {
        final params = const TypesetMeasureParams(
          width: 360,
          height: 640,
          pagePadding: 16,
          fontSize: 16,
          lineHeight: 1.5,
          letterSpacing: 0,
          fontFamily: 'Roboto',
          devicePixelRatio: 1.0,
        );
        final data = measureLayoutFingerprint(params);
        expect(data.effectiveLineWidthRatio, inInclusiveRange(0.85, 1.0));
        expect(data.lineHeightDp, greaterThan(16));
        expect(data.cjkWidth, greaterThan(0));
      });

      test('CalibrationData JSON 往返', () {
        const original = CalibrationData(
          dpr: 2.0,
          cjkWidth: 18.0,
          asciiWidth: 9.5,
          digitWidth: 9.0,
          punctWidth: 17.5,
          latinExtWidth: 13.0,
          otherWidth: 14.0,
          effectiveLineWidthRatio: 0.98,
          lineHeightDp: 24.0,
        );
        final restored = CalibrationData.fromJson(original.toJson());
        expect(
          restored.effectiveLineWidthRatio,
          original.effectiveLineWidthRatio,
        );
        expect(restored.lineHeightDp, original.lineHeightDp);
        expect(restored.cjkWidth, original.cjkWidth);
      });
      test('A6 resolveLayoutCalibration cache hit', () async {
        final prefs = _MockPrefs();
        final params = const TypesetMeasureParams(
          width: 360,
          height: 640,
          pagePadding: 16,
          fontSize: 16,
          lineHeight: 1.5,
          letterSpacing: 0,
          fontFamily: 'Roboto',
          devicePixelRatio: 1.0,
        );
        // Pre-seed cache with a valid calibration
        final key = LayoutCalibrationStore.cacheKey(params);
        const cached = CalibrationData(
          dpr: 1.0,
          cjkWidth: 16.0,
          asciiWidth: 9.6,
          digitWidth: 9.6,
          punctWidth: 16.0,
          latinExtWidth: 11.2,
          otherWidth: 12.8,
          effectiveLineWidthRatio: 0.98,
          lineHeightDp: 24.0,
        );
        when(
          () => prefs.getString(key),
        ).thenReturn(jsonEncode(cached.toJson()));

        final result = await resolveLayoutCalibration(
          params: params,
          prefs: prefs,
        );
        expect(result, isNotNull);
        expect(result!.effectiveLineWidthRatio, 0.98);
        // Should NOT call measure — cache hit returns immediately
        verifyNever(() => prefs.setString(any(), any()));
      });

      test('A7 defaultCalibrationData line height', () {
        final cal = defaultCalibrationData(
          fontSize: 16,
          devicePixelRatio: 2.0,
          lineHeight: 1.5,
        );
        expect(cal.lineHeightDp, closeTo(24.0, 0.01)); // 16 * 1.5
        expect(cal.effectiveLineWidthRatio, 1.0);
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
        // 0.98 > 0.97, so 0.98 produces wider line
        expect(width1, greaterThan(width2));
      });

      test('A9 calibrationDrift ratio detection', () {
        const baseline = CalibrationData(
          dpr: 1.0,
          cjkWidth: 16.0,
          asciiWidth: 9.6,
          digitWidth: 9.6,
          punctWidth: 16.0,
          latinExtWidth: 10.0,
          otherWidth: 12.0,
          effectiveLineWidthRatio: 0.976,
          lineHeightDp: 24.0,
        );
        const smallDrift = CalibrationData(
          dpr: 1.0,
          cjkWidth: 16.0,
          asciiWidth: 9.6,
          digitWidth: 9.6,
          punctWidth: 16.0,
          latinExtWidth: 10.0,
          otherWidth: 12.0,
          effectiveLineWidthRatio: 0.99, // 1.4% drift
          lineHeightDp: 24.0,
        );
        const largeDrift = CalibrationData(
          dpr: 1.0,
          cjkWidth: 16.0,
          asciiWidth: 9.6,
          digitWidth: 9.6,
          punctWidth: 16.0,
          latinExtWidth: 10.0,
          otherWidth: 12.0,
          effectiveLineWidthRatio: 0.90, // 7.8% drift
          lineHeightDp: 24.0,
        );

        expect(calibrationDriftExceeds(baseline, smallDrift), isFalse);
        expect(calibrationDriftExceeds(baseline, largeDrift), isTrue);
      });
    });
  });
}

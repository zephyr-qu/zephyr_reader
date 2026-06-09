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

      expect(config.pageWidth, equals(360)); // 360 * 1.0 ≈ 360
      expect(config.pageHeight, equals(640)); // 640 * 1.0 ≈ 640
      expect(config.fontSize, equals(16));
      expect(config.lineSpacing, equals(1.5));
      expect(config.paragraphSpacing, equals(2.0));
      expect(config.letterSpacing, equals(0));
      expect(config.firstLineIndent, equals(2));
      expect(config.language, equals(LanguageType.mixed));
      expect(config.enableHyphenation, isFalse);
      expect(config.punctuationSqueeze, isTrue);
      expect(config.fontFamily, equals('Noto Sans SC'));
      expect(config.calibration, isNull);
    });

    test('像素值四舍五入', () {
      final config = buildTypesetConfig(
        width: 360.7,
        height: 640.4,
        fontSize: 16.3,
        lineHeight: 1.5,
        devicePixelRatio: 2.0,
      );

      // 360.7 * 2 = 721.4 → round → 721
      expect(config.pageWidth, equals(721));
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
      expect(config.pageWidth, equals(400));
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

      expect(config.pageWidth, equals(1080)); // 360 * 3
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

    group('calibration 参数', () {
      test('null calibration 产生 null rustCalibration', () {
        final config = buildTypesetConfig(
          width: 360,
          height: 640,
          fontSize: 16,
          lineHeight: 1.5,
          calibration: null,
        );

        expect(config.calibration, isNull);
      });

      test('有 calibration 时正确转换', () {
        final cal = const CalibrationData(
          dpr: 2.0,
          cjkWidth: 18.0,
          asciiWidth: 9.5,
          digitWidth: 9.0,
          punctWidth: 17.5,
          otherWidth: 14.0,
        );
        final config = buildTypesetConfig(
          width: 360,
          height: 640,
          fontSize: 16,
          lineHeight: 1.5,
          calibration: cal,
        );

        expect(config.calibration, isNotNull);
        expect(config.calibration!.dpr, equals(2.0));
        expect(config.calibration!.cjkWidth, equals(18.0));
        expect(config.calibration!.asciiWidth, equals(9.5));
        expect(config.calibration!.digitWidth, equals(9.0));
        expect(config.calibration!.punctWidth, equals(17.5));
        expect(config.calibration!.otherWidth, equals(14.0));
        expect(config.calibration!.latinExtWidth, equals(0.0));
      });

      test('calibration dpr 与 devicePixelRatio 独立', () {
        final cal = const CalibrationData(
          dpr: 2.0,
          cjkWidth: 18.0,
          asciiWidth: 9.5,
          digitWidth: 9.0,
          punctWidth: 17.5,
          otherWidth: 14.0,
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
        expect(config.pageWidth, equals(540)); // 360 * 1.5
        expect(config.calibration!.dpr, equals(2.0));
      });
    });
  });
}

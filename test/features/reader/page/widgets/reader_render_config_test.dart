import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/page/widgets/reader_render_config.dart';

ReaderRenderConfig _config({
  double fontSize = 16,
  double lineHeight = 1.5,
  Color textColor = Colors.black,
  String fontFamily = '',
  double letterSpacing = 0,
}) {
  return ReaderRenderConfig(
    textColor: textColor,
    backgroundColor: Colors.white,
    fontSize: fontSize,
    lineHeight: lineHeight,
    fontFamily: fontFamily,
    letterSpacing: letterSpacing,
    paragraphSpacing: 12,
    pageMargin: 16,
    searchQuery: '',
    searchMatchHighlight: false,
    showVocabularyMark: false,
    vocabularyWords: const {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderRenderConfig.buildTextStyle', () {
    test('应返回正确的字体大小和行高', () {
      final style = _config(
        fontSize: 18,
        lineHeight: 1.8,
      ).buildTextStyle();

      expect(style.fontSize, equals(18));
      expect(style.height, equals(1.8));
      expect(style.color, equals(Colors.black));
    });

    test('默认应使用中文首选字体', () {
      final style = _config().buildTextStyle();

      expect(style.fontFamily, equals(ReaderRenderConfig.chineseFont));
    });

    test('useLatin 应切换为英文字体', () {
      final style = _config().buildTextStyle(useLatin: true);

      expect(style.fontFamily, equals(ReaderRenderConfig.latinFont));
    });

    test('fontFamily 应覆盖默认字体', () {
      final style = _config(fontFamily: 'CustomFont').buildTextStyle();

      expect(style.fontFamily, equals('CustomFont'));
    });

    test('应有回退字体栈', () {
      final style = _config().buildTextStyle();

      expect(style.fontFamilyFallback, isNotNull);
      expect(style.fontFamilyFallback!.length, greaterThan(0));
      expect(style.fontFamilyFallback, contains('PingFang SC'));
      expect(style.fontFamilyFallback, contains('sans-serif'));
    });

    test('letterSpacing 应从 config 透传', () {
      final style = _config(letterSpacing: 2).buildTextStyle();

      expect(style.letterSpacing, equals(2));
    });

    test('letterSpacing 默认应为 0', () {
      final style = _config().buildTextStyle();

      expect(style.letterSpacing, equals(0));
    });

    test('useLatin true 且 fontFamily 自定义时应使用自定义', () {
      final style = _config(fontFamily: 'MyFont').buildTextStyle(
        useLatin: true,
      );

      expect(style.fontFamily, equals('MyFont'));
    });

    test('fontSizeMultiplier 应缩放字号', () {
      final style = _config(fontSize: 20).buildTextStyle(
        fontSizeMultiplier: 0.9,
      );

      expect(style.fontSize, closeTo(18, 0.01));
    });

    test('color 参数应覆盖 config.textColor', () {
      final style = _config(textColor: Colors.black).buildTextStyle(
        color: Colors.red,
      );

      expect(style.color, equals(Colors.red));
    });
  });

  group('ReaderRenderConfig.buildStrutStyle', () {
    test('应返回正确的 StrutStyle', () {
      final strut = _config().buildStrutStyle();

      expect(strut.fontSize, closeTo(15.2, 0.01));
      expect(strut.height, equals(1.5));
      expect(strut.forceStrutHeight, isTrue);
    });

    test('默认应使用中文首选字体', () {
      final strut = _config().buildStrutStyle();

      expect(strut.fontFamily, equals(ReaderRenderConfig.chineseFont));
    });

    test('useLatin 应切换为英文字体', () {
      final strut = _config().buildStrutStyle(useLatin: true);

      expect(strut.fontFamily, equals(ReaderRenderConfig.latinFont));
    });

    test('fontFamily 应覆盖默认字体', () {
      final strut = _config(fontFamily: 'CustomFont').buildStrutStyle();

      expect(strut.fontFamily, equals('CustomFont'));
    });

    test('应有回退字体栈', () {
      final strut = _config().buildStrutStyle();

      expect(strut.fontFamilyFallback, isNotNull);
      expect(strut.fontFamilyFallback!.length, greaterThan(0));
      expect(strut.fontFamilyFallback, contains('PingFang SC'));
    });

    test('fontSizeMultiplier 应缩放字号', () {
      final strut = _config(fontSize: 20).buildStrutStyle(
        fontSizeMultiplier: 0.9,
      );

      expect(strut.fontSize, closeTo(20 * 0.9 * 0.95, 0.01));
    });
  });

  group('常量', () {
    test('chineseFont 应为 Noto Sans SC', () {
      expect(ReaderRenderConfig.chineseFont, equals('Noto Sans SC'));
    });

    test('latinFont 应为 Roboto', () {
      expect(ReaderRenderConfig.latinFont, equals('Roboto'));
    });

    test('fallbackStack 应包含所有回退字体', () {
      expect(ReaderRenderConfig.fallbackStack.length, equals(7));
      expect(ReaderRenderConfig.fallbackStack[0], equals('PingFang SC'));
      expect(ReaderRenderConfig.fallbackStack.last, equals('sans-serif'));
    });
  });
}

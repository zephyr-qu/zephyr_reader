import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/reader/font_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FontConfig', () {
    group('readerStyle', () {
      test('应返回正确的字体大小和行高', () {
        final style = FontConfig.readerStyle(
          fontSize: 18,
          lineHeight: 1.8,
          color: Colors.black,
        );

        expect(style.fontSize, equals(18));
        expect(style.height, equals(1.8));
        expect(style.color, equals(Colors.black));
      });

      test('默认应使用中文首选字体', () {
        final style = FontConfig.readerStyle(
          fontSize: 16,
          lineHeight: 1.5,
          color: Colors.black,
        );

        expect(style.fontFamily, equals(FontConfig.chineseFont));
      });

      test('useLatin 应切换为英文字体', () {
        final style = FontConfig.readerStyle(
          fontSize: 16,
          lineHeight: 1.5,
          color: Colors.black,
          useLatin: true,
        );

        expect(style.fontFamily, equals(FontConfig.latinFont));
      });

      test('fontFamily 应覆盖默认字体', () {
        final style = FontConfig.readerStyle(
          fontSize: 16,
          lineHeight: 1.5,
          color: Colors.black,
          fontFamily: 'CustomFont',
        );

        expect(style.fontFamily, equals('CustomFont'));
      });

      test('应有回退字体栈', () {
        final style = FontConfig.readerStyle(
          fontSize: 16,
          lineHeight: 1.5,
          color: Colors.black,
        );

        expect(style.fontFamilyFallback, isNotNull);
        expect(style.fontFamilyFallback!.length, greaterThan(0));
        expect(style.fontFamilyFallback, contains('PingFang SC'));
        expect(style.fontFamilyFallback, contains('sans-serif'));
      });

      test('letterSpacing 应正确设置', () {
        final style = FontConfig.readerStyle(
          fontSize: 16,
          lineHeight: 1.5,
          color: Colors.black,
          letterSpacing: 2,
        );

        expect(style.letterSpacing, equals(2));
      });

      test('letterSpacing 默认应为 0', () {
        final style = FontConfig.readerStyle(
          fontSize: 16,
          lineHeight: 1.5,
          color: Colors.black,
        );

        expect(style.letterSpacing, equals(0));
      });

      test('useLatin true 且 fontFamily 自定义时应使用自定义', () {
        final style = FontConfig.readerStyle(
          fontSize: 16,
          lineHeight: 1.5,
          color: Colors.black,
          useLatin: true,
          fontFamily: 'MyFont',
        );

        expect(style.fontFamily, equals('MyFont'));
      });
    });

    group('readerStrut', () {
      test('应返回正确的 StrutStyle', () {
        final strut = FontConfig.readerStrut(fontSize: 16, lineHeight: 1.5);

        expect(strut.fontSize, closeTo(15.2, 0.01));
        expect(strut.height, equals(1.5));
        expect(strut.forceStrutHeight, isTrue);
      });

      test('默认应使用中文首选字体', () {
        final strut = FontConfig.readerStrut(fontSize: 16, lineHeight: 1.5);

        expect(strut.fontFamily, equals(FontConfig.chineseFont));
      });

      test('useLatin 应切换为英文字体', () {
        final strut = FontConfig.readerStrut(
          fontSize: 16,
          lineHeight: 1.5,
          useLatin: true,
        );

        expect(strut.fontFamily, equals(FontConfig.latinFont));
      });

      test('fontFamily 应覆盖默认字体', () {
        final strut = FontConfig.readerStrut(
          fontSize: 16,
          lineHeight: 1.5,
          fontFamily: 'CustomFont',
        );

        expect(strut.fontFamily, equals('CustomFont'));
      });

      test('应有回退字体栈', () {
        final strut = FontConfig.readerStrut(fontSize: 16, lineHeight: 1.5);

        expect(strut.fontFamilyFallback, isNotNull);
        expect(strut.fontFamilyFallback!.length, greaterThan(0));
        expect(strut.fontFamilyFallback, contains('PingFang SC'));
      });
    });

    group('常量', () {
      test('chineseFont 应为 Noto Sans SC', () {
        expect(FontConfig.chineseFont, equals('Noto Sans SC'));
      });

      test('latinFont 应为 Roboto', () {
        expect(FontConfig.latinFont, equals('Roboto'));
      });

      test('fallbackStack 应包含所有回退字体', () {
        expect(FontConfig.fallbackStack.length, equals(7));
        expect(FontConfig.fallbackStack[0], equals('PingFang SC'));
        expect(FontConfig.fallbackStack.last, equals('sans-serif'));
      });
    });
  });
}

// test/widget/rich_text_converter_test.dart
//
// RichTextConverter 纯函数单元测试。
// 纯 Dart 测试，零 FRB/FFI 依赖。
import 'package:flutter/material.dart';

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/rich_text_converter.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

void main() {
  final converter = const RichTextConverter();

  group('toTextSpan', () {
    test('empty paragraph list returns empty TextSpan', () {
      final (span, text) = converter.toTextSpan([]);
      expect(span.children, isEmpty);
      expect(text, isEmpty);
    });

    test('single plain text paragraph', () {
      final (span, text) = converter.toTextSpan([
        RichParagraph(
          spans: [RichTextSpan.plain(text: 'Hello world')],
          indent: 0,
          isHeading: false,
          headingLevel: 0,
          isImage: false,
          imageData: Uint8List(0),
        ),
      ]);
      expect(text, 'Hello world');
      expect(span.children, hasLength(1));
      final firstChild = span.children!.first as TextSpan;
      expect(firstChild.children, hasLength(1));
      expect((firstChild.children!.first as TextSpan).text, 'Hello world');
    });

    test('image paragraph is skipped', () {
      final (span, text) = converter.toTextSpan([
        RichParagraph(
          spans: [],
          indent: 0,
          isHeading: false,
          headingLevel: 0,
          isImage: true,
          imageData: Uint8List(0),
        ),
        RichParagraph(
          spans: [RichTextSpan.plain(text: 'After image')],
          indent: 0,
          isHeading: false,
          headingLevel: 0,
          isImage: false,
          imageData: Uint8List(0),
        ),
      ]);
      expect(text, 'After image');
      expect(span.children, hasLength(1));
    });

    test('paragraphs separated by double newline', () {
      final (span, text) = converter.toTextSpan([
        RichParagraph(
          spans: [RichTextSpan.plain(text: 'First')],
          indent: 0,
          isHeading: false,
          headingLevel: 0,
          isImage: false,
          imageData: Uint8List(0),
        ),
        RichParagraph(
          spans: [RichTextSpan.plain(text: 'Second')],
          indent: 0,
          isHeading: false,
          headingLevel: 0,
          isImage: false,
          imageData: Uint8List(0),
        ),
      ]);
      expect(text, 'First\n\nSecond');
      expect(span.children, hasLength(3));
    });

    test('empty text paragraph is skipped', () {
      final (span, text) = converter.toTextSpan([
        RichParagraph(
          spans: [RichTextSpan.plain(text: '')],
          indent: 0,
          isHeading: false,
          headingLevel: 0,
          isImage: false,
          imageData: Uint8List(0),
        ),
      ]);
      expect(text, isEmpty);
      expect(span.children, isEmpty);
    });
  });

  group('spanToStyle', () {
    test('plain text has default style', () {
      final style = converter.spanToStyle(RichTextSpan.plain(text: 'a'));
      expect(style.fontWeight, isNull);
      expect(style.fontStyle, isNull);
      expect(style.decoration, isNull);
    });

    test('bold text has bold weight', () {
      final style = converter.spanToStyle(RichTextSpan.bold(text: 'b'));
      expect(style.fontWeight, FontWeight.bold);
    });

    test('italic text has italic style', () {
      final style = converter.spanToStyle(RichTextSpan.italic(text: 'i'));
      expect(style.fontStyle, FontStyle.italic);
    });

    test('underline text has underline decoration', () {
      final style = converter.spanToStyle(RichTextSpan.underline(text: 'u'));
      expect(style.decoration, TextDecoration.underline);
    });

    test('strikethrough text has lineThrough decoration', () {
      final style = converter.spanToStyle(
        RichTextSpan.strikethrough(text: 's'),
      );
      expect(style.decoration, TextDecoration.lineThrough);
    });

    test('code text has monospace font', () {
      final style = converter.spanToStyle(RichTextSpan.code(text: 'c'));
      expect(style.fontFamily, 'monospace');
    });

    test('link text has underline decoration', () {
      final style = converter.spanToStyle(
        RichTextSpan.link(text: 'link', url: 'https://example.com'),
      );
      expect(style.decoration, TextDecoration.underline);
    });

    test('span with fontSize overrides base style', () {
      final style = converter.spanToStyle(
        RichTextSpan.bold(text: 'b', fontSize: 20),
      );
      expect(style.fontWeight, FontWeight.bold);
      expect(style.fontSize, 20);
    });

    test('span with color parses hex', () {
      final style = converter.spanToStyle(
        RichTextSpan.plain(text: 'a', color: '#FF0000'),
      );
      expect(style.color, const Color(0xFFFF0000));
    });
  });

  group('paragraphBlockStyle', () {
    RichParagraph makePara({
      bool isHeading = false,
      int headingLevel = 0,
      double? lineHeight,
    }) {
      return RichParagraph(
        spans: [RichTextSpan.plain(text: 'p')],
        indent: 0,
        isHeading: isHeading,
        headingLevel: headingLevel,
        lineHeight: lineHeight,
        isImage: false,
        imageData: Uint8List(0),
      );
    }

    test('non-heading returns base style', () {
      final style = converter.paragraphBlockStyle(
        makePara(),
        baseFontSize: 16,
        baseLineHeight: 1.6,
      );
      expect(style.fontSize, 16);
      expect(style.height, 1.6);
    });

    test('heading level 1 uses 24px bold', () {
      final style = converter.paragraphBlockStyle(
        makePara(isHeading: true, headingLevel: 1),
        baseFontSize: 16,
        baseLineHeight: 1.6,
      );
      expect(style.fontSize, 24);
      expect(style.fontWeight, FontWeight.bold);
    });

    test('heading level 2 uses 20px bold', () {
      final style = converter.paragraphBlockStyle(
        makePara(isHeading: true, headingLevel: 2),
        baseFontSize: 16,
        baseLineHeight: 1.6,
      );
      expect(style.fontSize, 20);
      expect(style.fontWeight, FontWeight.bold);
    });

    test('heading level 3 uses 18px bold', () {
      final style = converter.paragraphBlockStyle(
        makePara(isHeading: true, headingLevel: 3),
        baseFontSize: 16,
        baseLineHeight: 1.6,
      );
      expect(style.fontSize, 18);
    });

    test('heading level 5 uses 14px bold fallback', () {
      final style = converter.paragraphBlockStyle(
        makePara(isHeading: true, headingLevel: 5),
        baseFontSize: 16,
        baseLineHeight: 1.6,
      );
      expect(style.fontSize, 14);
    });

    test('custom lineHeight overrides base', () {
      final style = converter.paragraphBlockStyle(
        makePara(lineHeight: 2.0),
        baseFontSize: 16,
        baseLineHeight: 1.6,
      );
      expect(style.height, 2.0);
    });
  });

  group('parseCssColor', () {
    test('#RRGGBB format', () {
      expect(converter.parseCssColor('#FF0000'), const Color(0xFFFF0000));
      expect(converter.parseCssColor('#00FF00'), const Color(0xFF00FF00));
      expect(converter.parseCssColor('#0000FF'), const Color(0xFF0000FF));
    });

    test('#RGB format', () {
      expect(converter.parseCssColor('#F00'), const Color(0xFFFF0000));
      expect(converter.parseCssColor('#0F0'), const Color(0xFF00FF00));
      expect(converter.parseCssColor('#00F'), const Color(0xFF0000FF));
    });

    test('invalid hex returns null', () {
      expect(converter.parseCssColor('not-a-color'), isNull);
    });

    test('empty string returns null', () {
      expect(converter.parseCssColor(''), isNull);
    });

    test('partial hex returns null', () {
      expect(converter.parseCssColor('#FFF'), isNot(isNull));
      expect(converter.parseCssColor('#FF'), isNull);
    });
  });
}

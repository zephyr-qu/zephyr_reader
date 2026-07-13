import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/rich_text_converter.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

const _cjFullwidth = '\u3000';

/// Reusable helper to build a simple RichParagraph.
RichParagraph _p({
  String text = '',
  double? textIndentEm,
  SpanStyle style = SpanStyle.plain,
  List<RichTextSpan>? spans,
}) {
  return RichParagraph(
    spans: spans ?? [RichTextSpan.styled(style, RichTextSpanData(text: text))],
    indent: 0,
    isHeading: false,
    headingLevel: 0,
    className: null,
    textAlign: null,
    marginTopEm: null,
    marginBottomEm: null,
    textIndentEm: textIndentEm,
    fontSize: null,
    isImage: false,
    imageSrc: null,
    imageData: Uint8List(0),
    imageAlt: null,
  );
}

void main() {
  group('_resolveIndentPrefix (via toTextSpan plain output)', () {
    test('textIndentEm null → no indent', () {
      final p = _p(text: 'Hello');
      final converter = const RichTextConverter();
      final (_, plain) = converter.toTextSpan([p]);
      expect(plain, 'Hello');
    });

    test('textIndentEm 2.0 → 2 CJK fullwidth spaces', () {
      final p = _p(text: '世界', textIndentEm: 2.0);
      final converter = const RichTextConverter();
      final (_, plain) = converter.toTextSpan([p]);
      expect(plain, '$_cjFullwidth$_cjFullwidth世界');
    });

    test('textIndentEm 1.5 → 2 spaces (ceil)', () {
      final p = _p(text: '测试', textIndentEm: 1.5);
      final converter = const RichTextConverter();
      final (_, plain) = converter.toTextSpan([p]);
      expect(plain, '$_cjFullwidth$_cjFullwidth测试');
    });

    test('textIndentEm 0.5 → 1 space (clamp min 1)', () {
      final p = _p(text: '文本', textIndentEm: 0.5);
      final converter = const RichTextConverter();
      final (_, plain) = converter.toTextSpan([p]);
      expect(plain, '$_cjFullwidth文本');
    });

    test('textIndentEm 0 → no indent', () {
      final p = _p(text: 'Zero indent', textIndentEm: 0.0);
      final converter = const RichTextConverter();
      final (_, plain) = converter.toTextSpan([p]);
      expect(plain, 'Zero indent');
    });

    test('multiple paragraphs: only indented gets prefix', () {
      final p1 = _p(text: 'First', textIndentEm: 2.0);
      final p2 = _p(text: 'Second');
      final converter = const RichTextConverter();
      final (_, plain) = converter.toTextSpan([p1, p2]);
      expect(plain, '$_cjFullwidth${_cjFullwidth}First\n\nSecond');
    });
  });

  group('Indent preserves first span style', () {
    test('bold first span keeps bold after indent injection', () {
      final p = _p(
        spans: [
          const RichTextSpan.styled(
            SpanStyle.bold,
            RichTextSpanData(text: 'Bold start'),
          ),
          const RichTextSpan.styled(
            SpanStyle.plain,
            RichTextSpanData(text: ' normal rest'),
          ),
        ],
        textIndentEm: 2.0,
      );
      final converter = const RichTextConverter();
      final (span, plain) = converter.toTextSpan([p]);
      // Plain text should have indent
      expect(plain, '$_cjFullwidth${_cjFullwidth}Bold start normal rest');
      // The first span child should still have bold style
      final children = span.children;
      expect(children, isNotNull);
      // Find the paragraph-level TextSpan
      final blockSpan =
          children!.firstWhere((s) => s is TextSpan && s.children != null)
              as TextSpan;
      final firstParaChild = blockSpan.children!.first as TextSpan;
      expect(firstParaChild.style?.fontWeight, FontWeight.bold);
    });
  });

  group('Image paragraphs', () {
    test('image paragraph is skipped', () {
      final p = RichParagraph(
        spans: [],
        indent: 0,
        isHeading: false,
        headingLevel: 0,
        className: null,
        textAlign: null,
        marginTopEm: null,
        marginBottomEm: null,
        textIndentEm: null,
        fontSize: null,
        isImage: true,
        imageSrc: null,
        imageData: Uint8List(0),
        imageAlt: null,
      );
      final converter = const RichTextConverter();
      final (_, plain) = converter.toTextSpan([p]);
      expect(plain, '');
    });
  });
}

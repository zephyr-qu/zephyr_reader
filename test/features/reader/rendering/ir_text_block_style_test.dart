import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/rich_text_converter.dart';
import 'package:zephyr_reader/features/reader/rendering/ir_text_block_style.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

ReaderRenderConfig _config({bool firstLineIndent = true}) {
  return ReaderRenderConfig(
    textColor: Colors.black,
    backgroundColor: Colors.white,
    fontSize: 16,
    lineHeight: 1.5,
    fontFamily: '',
    letterSpacing: 0,
    paragraphSpacing: 12,
    pageMargin: 16,
    showVocabularyMark: false,
    vocabularyWords: const {},
    firstLineIndent: firstLineIndent,
  );
}

void main() {
  test('user firstLineIndent off suppresses default indent', () {
    const style = TextBlockStyle(
      isHeading: false,
      headingLevel: 0,
      textIndentEm: null,
      marginTopEm: null,
      marginBottomEm: null,
      fontFamily: null,
      lineHeight: null,
      textAlign: null,
    );
    expect(
      IrTextBlockStyle.resolveFirstLineIndentPx(
        style,
        _config(firstLineIndent: false),
      ),
      0,
    );
    expect(
      IrTextBlockStyle.resolveFirstLineIndentPx(
        style,
        _config(firstLineIndent: true),
      ),
      32,
    );
  });

  test('explicit CSS textIndentEm overrides user firstLineIndent off', () {
    const style = TextBlockStyle(
      isHeading: false,
      headingLevel: 0,
      textIndentEm: 3,
      marginTopEm: null,
      marginBottomEm: null,
      fontFamily: null,
      lineHeight: null,
      textAlign: null,
    );
    expect(
      IrTextBlockStyle.resolveFirstLineIndentPx(
        style,
        _config(firstLineIndent: false),
      ),
      48,
    );
  });

  test('resolveFirstLineIndentPx uses IR em over default', () {
    const style = TextBlockStyle(
      isHeading: false,
      headingLevel: 0,
      textIndentEm: 3,
      marginTopEm: null,
      marginBottomEm: null,
      fontFamily: null,
      lineHeight: null,
      textAlign: null,
    );
    expect(
      IrTextBlockStyle.resolveFirstLineIndentPx(style, _config()),
      48,
    );
  });

  test('headings never indent', () {
    const style = TextBlockStyle(
      isHeading: true,
      headingLevel: 2,
      textIndentEm: 2,
      marginTopEm: null,
      marginBottomEm: null,
      fontFamily: null,
      lineHeight: null,
      textAlign: null,
    );
    expect(
      IrTextBlockStyle.resolveFirstLineIndentPx(style, _config()),
      0,
    );
  });

  test('marginBottomEm overrides paragraphSpacing', () {
    const style = TextBlockStyle(
      isHeading: false,
      headingLevel: 0,
      textIndentEm: null,
      marginTopEm: null,
      marginBottomEm: 1.5,
      fontFamily: null,
      lineHeight: null,
      textAlign: null,
    );
    expect(
      IrTextBlockStyle.resolveBottomSpacing(style, _config()),
      24,
    );
  });

  test('irSpansToTextSpan applies bold style', () {
    const converter = RichTextConverter();
    const spans = [
      RichTextSpan.styled(
        SpanStyle.plain,
        RichTextSpanData(text: 'Hello '),
      ),
      RichTextSpan.styled(
        SpanStyle.bold,
        RichTextSpanData(text: 'bold'),
      ),
    ];
    final result = converter.irSpansToTextSpan(
      spans,
      blockStyle: const TextStyle(fontSize: 16),
    );
    expect(result.children, isNotNull);
    expect(result.children!.length, 2);
    final boldChild = result.children![1] as TextSpan;
    expect(boldChild.style?.fontWeight, FontWeight.bold);
  });

  test('buildHighlightedSpan adds WidgetSpan indent when block starts', () {
    const style = TextBlockStyle(
      isHeading: false,
      headingLevel: 0,
      textIndentEm: 2,
      marginTopEm: null,
      marginBottomEm: null,
      fontFamily: null,
      lineHeight: null,
      textAlign: null,
    );
    final span = IrTextBlockStyle.buildHighlightedSpan(
      text: 'Hello',
      spans: const [],
      irStyle: style,
      config: _config(),
      highlights: const [],
      contentStart: 0,
      applyFirstLineIndent: true,
    );
    expect(span, isA<TextSpan>());
    final children = (span as TextSpan).children;
    expect(children, isNotNull);
    expect(children!.first, isA<WidgetSpan>());
  });
}

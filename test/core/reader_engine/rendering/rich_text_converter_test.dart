import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/rich_text_converter.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';

void main() {
  test('link preserves combined bold and italic style', () {
    const converter = RichTextConverter();
    final style = converter.spanToStyle(
      const ReaderInlineRun(
        text: 'both',
        style: ReaderInlineStyle(bold: true, italic: true),
        url: 'chapter.xhtml',
      ),
    );

    expect(style.fontWeight, FontWeight.bold);
    expect(style.fontStyle, FontStyle.italic);
    expect(style.decoration, TextDecoration.underline);
    expect(style.color, Colors.blue);
  });
}

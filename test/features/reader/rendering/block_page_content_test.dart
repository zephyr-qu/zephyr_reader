import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/rendering/block_page_content.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/domain/types/block_pagination.dart';

ReaderRenderConfig _config({double paragraphSpacing = 12}) {
  return ReaderRenderConfig(
    textColor: Colors.black,
    backgroundColor: Colors.white,
    fontSize: 16,
    lineHeight: 1.5,
    fontFamily: '',
    letterSpacing: 0,
    paragraphSpacing: paragraphSpacing,
    pageMargin: 16,
    showVocabularyMark: false,
    vocabularyWords: const {},
  );
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 400,
      height: 600,
      child: child,
    ),
  ),
);

void main() {
  testWidgets('isBlockEnd 为 true 时在 Text 块后插入 paragraphSpacing', (tester) async {
    const spacing = 12.0;
    await tester.pumpWidget(
      _wrap(
        LayoutBuilder(
          builder: (context, constraints) => buildBlockPageContent(
            context: context,
            blocks: const [
              PageBlockSlice.text(
                PageTextBlockSlice(
                  blockIndex: 0,
                  text: 'First paragraph.',
                  isBlockEnd: true,
                ),
              ),
              PageBlockSlice.text(
                PageTextBlockSlice(
                  blockIndex: 1,
                  text: 'Second paragraph.',
                  isBlockEnd: true,
                ),
              ),
            ],
            startOffset: 0,
            epubFilePath: '/books/test.epub',
            config: _config(paragraphSpacing: spacing),
            highlights: const [],
            onHighlightTap: null,
            onSelectionChanged: null,
            onSelectionGlobalPosition: null,
            maxContentWidth: 400,
          ),
        ),
      ),
    );

    final spacingBoxes = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((box) => box.height == spacing);
    expect(spacingBoxes.length, 2);
  });

  testWidgets('跨页续排切片 isBlockEnd=false 时不插入段间距', (tester) async {
    await tester.pumpWidget(
      _wrap(
        LayoutBuilder(
          builder: (context, constraints) => buildBlockPageContent(
            context: context,
            blocks: const [
              PageBlockSlice.text(
                PageTextBlockSlice(
                  blockIndex: 0,
                  text: 'Continuation slice.',
                  isBlockEnd: false,
                ),
              ),
            ],
            startOffset: 0,
            epubFilePath: '/books/test.epub',
            config: _config(),
            highlights: const [],
            onHighlightTap: null,
            onSelectionChanged: null,
            onSelectionGlobalPosition: null,
            maxContentWidth: 400,
          ),
        ),
      ),
    );

    final spacingBoxes = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((box) => box.height == 12);
    expect(spacingBoxes, isEmpty);
  });
}

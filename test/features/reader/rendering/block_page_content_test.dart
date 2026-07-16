import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/packed_page.dart';
import 'package:zephyr_reader/features/reader/rendering/block_page_content.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/pipeline/types.dart';

const _defaultStyle = ReaderIrBlock(
  kind: ReaderIrBlockKind.text,
  plainStart: 0,
  plainLen: 0,
  text: '',
  runs: [],
  isHeading: false,
  headingLevel: 0,
  textIndentEm: null,
  marginTopEm: null,
  marginBottomEm: null,
  textAlign: null,
  fontSize: null,
  imageAssetId: null,
  imageAlt: null,
  imageIntrinsicWidth: null,
  imageIntrinsicHeight: null,
);

const _emptySpans = <ReaderInlineRun>[];

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
  home: Scaffold(body: SizedBox(width: 400, height: 600, child: child)),
);

void main() {
  testWidgets('段距只加在块之间，页末最后一块不加', (tester) async {
    const spacing = 12.0;
    await tester.pumpWidget(
      _wrap(
        LayoutBuilder(
          builder: (context, constraints) => buildBlockPageContent(
            context: context,
            blocks: const [
              PackedBlockSlice.text(
                blockIndex: 0,
                text: 'First paragraph.',
                isBlockStart: true,
                isBlockEnd: true,
                style: _defaultStyle,
                spans: _emptySpans,
              ),
              PackedBlockSlice.text(
                blockIndex: 1,
                text: 'Second paragraph.',
                isBlockStart: true,
                isBlockEnd: true,
                style: _defaultStyle,
                spans: _emptySpans,
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
    expect(spacingBoxes.length, 1);
  });

  testWidgets('跨页续排切片 isBlockEnd=false 时不插入段间距', (tester) async {
    await tester.pumpWidget(
      _wrap(
        LayoutBuilder(
          builder: (context, constraints) => buildBlockPageContent(
            context: context,
            blocks: const [
              PackedBlockSlice.text(
                blockIndex: 0,
                text: 'Continuation slice.',
                isBlockStart: false,
                isBlockEnd: false,
                style: _defaultStyle,
                spans: _emptySpans,
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

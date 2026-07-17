import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/flutter_block_paginator.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/line_break_extractor.dart';
import 'package:zephyr_reader/core/reader_engine/shared/pagination_params.dart';
import 'package:zephyr_reader/src/rust/pipeline/types.dart';

void main() {
  const config = ReaderRenderConfig(
    textColor: Colors.black,
    backgroundColor: Colors.white,
    fontSize: 16,
    lineHeight: 1.5,
    fontFamily: 'sans-serif',
    letterSpacing: 0,
    paragraphSpacing: 0,
    pageMargin: 0,
    showVocabularyMark: false,
    vocabularyWords: {},
  );

  testWidgets('page descriptors use Dart UTF-16 offsets', (tester) async {
    const text = 'A😀B';
    const ir = ReaderChapterIr(
      plainText: text,
      blocks: [
        ReaderIrBlock(
          kind: ReaderIrBlockKind.text,
          plainStart: 0,
          plainLen: 4,
          text: text,
          runs: [],
          style: BlockStyle(isHeading: false, headingLevel: 0),
        ),
      ],
    );

    final pages = FlutterBlockPaginator.paginate(
      ir,
      config: config,
      contentWidthDp: 400,
      contentHeightDp: 600,
    );

    expect(text.length, 4);
    expect(pages, hasLength(1));
    expect(pages.single.startOffset, 0);
    expect(pages.single.endOffset, 4);
    expect(
      text.substring(pages.single.startOffset, pages.single.endOffset),
      text,
    );
  });

  test('chunking never splits a UTF-16 surrogate pair', () {
    final text = '${List.filled(3999, 'A').join()}😀B';
    final safeEnd = utf16SafeChunkEnd(text, 4000);

    expect(safeEnd, 3999);
    expect(() => text.substring(0, safeEnd), returnsNormally);
    expect(text.substring(safeEnd), '😀B');
  });

  test('chunking never creates a synthetic line break inside a paragraph', () {
    final unbroken = List.filled(kLineBreakChunkChars + 1, 'A').join();
    expect(textBlockChunkEnd(unbroken, 0), unbroken.length);

    final withNewline =
        '${List.filled(3000, 'A').join()}\n${List.filled(2000, 'B').join()}';
    expect(textBlockChunkEnd(withNewline, 0), 3001);
  });

  test('layout hash includes baseline alignment and text scaling', () {
    const base = PaginationParams(
      fontSize: 16,
      lineHeight: 1.5,
      width: 400,
      height: 600,
      padding: 20,
    );
    const noBaseline = PaginationParams(
      fontSize: 16,
      lineHeight: 1.5,
      width: 400,
      height: 600,
      padding: 20,
      baselineAlign: false,
    );
    const scaled = PaginationParams(
      fontSize: 16,
      lineHeight: 1.5,
      width: 400,
      height: 600,
      padding: 20,
      textScaler: TextScaler.linear(1.2),
    );

    expect(base.layoutHash, isNot(noBaseline.layoutHash));
    expect(base.layoutHash, isNot(scaled.layoutHash));
  });

  testWidgets('rich text with indent preserves UTF-16 line boundaries', (
    tester,
  ) async {
    const text = 'A😀BCDEFG';
    final breaks = computeLineBreakIndices(
      text: text,
      style: const TextStyle(fontSize: 16),
      textSpan: const TextSpan(
        children: [
          TextSpan(text: 'A'),
          TextSpan(
            text: '😀BC',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: 'DEFG'),
        ],
      ),
      maxWidth: 50,
      firstLineIndentPx: 12,
    );

    expect(breaks, isNotEmpty);
    expect(breaks.last, text.length);
    for (final end in breaks) {
      expect(() => text.substring(0, end), returnsNormally);
    }
  });

  testWidgets('paragraph spacing before an image participates in packing', (
    tester,
  ) async {
    const spacedConfig = ReaderRenderConfig(
      textColor: Colors.black,
      backgroundColor: Colors.white,
      fontSize: 16,
      lineHeight: 1.5,
      fontFamily: 'sans-serif',
      letterSpacing: 0,
      paragraphSpacing: 10,
      pageMargin: 0,
      showVocabularyMark: false,
      vocabularyWords: {},
    );
    const bodyStyle = BlockStyle(isHeading: false, headingLevel: 0);
    const ir = ReaderChapterIr(
      plainText: 'A\uFFFC',
      blocks: [
        ReaderIrBlock(
          kind: ReaderIrBlockKind.text,
          plainStart: 0,
          plainLen: 1,
          text: 'A',
          runs: [],
          style: bodyStyle,
        ),
        ReaderIrBlock(
          kind: ReaderIrBlockKind.image,
          plainStart: 1,
          plainLen: 1,
          text: '',
          runs: [],
          style: bodyStyle,
          imageAssetId: 'image',
        ),
      ],
    );

    final pages = FlutterBlockPaginator.paginate(
      ir,
      config: spacedConfig,
      contentWidthDp: 100,
      contentHeightDp: 96,
    );

    expect(pages, hasLength(2));
    expect(pages.first.slices.single.isImage, isFalse);
    expect(pages.last.slices.single.isImage, isTrue);
  });

  testWidgets('paragraph spacing is not carried across a page break', (
    tester,
  ) async {
    const spacedConfig = ReaderRenderConfig(
      textColor: Colors.black,
      backgroundColor: Colors.white,
      fontSize: 16,
      lineHeight: 1.5,
      fontFamily: 'sans-serif',
      letterSpacing: 0,
      paragraphSpacing: 10,
      pageMargin: 0,
      showVocabularyMark: false,
      vocabularyWords: {},
    );
    const bodyStyle = BlockStyle(isHeading: false, headingLevel: 0);
    const ir = ReaderChapterIr(
      plainText: 'A\nBCD',
      blocks: [
        ReaderIrBlock(
          kind: ReaderIrBlockKind.text,
          plainStart: 0,
          plainLen: 3,
          text: 'A\nB',
          runs: [],
          style: bodyStyle,
        ),
        ReaderIrBlock(
          kind: ReaderIrBlockKind.text,
          plainStart: 3,
          plainLen: 1,
          text: 'C',
          runs: [],
          style: bodyStyle,
        ),
        ReaderIrBlock(
          kind: ReaderIrBlockKind.text,
          plainStart: 4,
          plainLen: 1,
          text: 'D',
          runs: [],
          style: bodyStyle,
        ),
      ],
    );

    final pages = FlutterBlockPaginator.paginate(
      ir,
      config: spacedConfig,
      contentWidthDp: 200,
      contentHeightDp: 68,
    );

    expect(pages, hasLength(2));
    expect(pages.first.slices, hasLength(1));
    expect(pages.last.slices, hasLength(2));
  });
}

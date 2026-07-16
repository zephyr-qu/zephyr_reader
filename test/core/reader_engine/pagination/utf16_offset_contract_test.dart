import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/flutter_block_paginator.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';
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
}

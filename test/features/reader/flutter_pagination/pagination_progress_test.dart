import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/line_break_extractor.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/flutter_block_paginator.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/packed_page.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/pagination_progress.dart';
import 'package:zephyr_reader/src/rust/pipeline/types.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ReaderRenderConfig cfg({double fontSize = 16}) =>
      lineBreakMeasureRenderConfig(
        fontSize: fontSize,
        lineHeight: 1.5,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        paragraphSpacing: 8,
        pageMargin: 16,
        firstLineIndent: false,
        baselineAlign: true,
      );

  ChapterContentIr longIr() {
    final plain = List.filled(60, '书签恢复与改字号重装箱测试段落。').join();
    return ChapterContentIr(
      blocks: [
        ContentBlock.text(
          TextBlock(
            plain: BlockPlainRange(plainStart: 0, plainLen: plain.length),
            text: plain,
            style: const TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: const [],
          ),
        ),
      ],
      plainText: plain,
    );
  }

  test('pageIndexAtCharOffset covers every char in some page', () {
    final ir = longIr();
    final pages = FlutterBlockPaginator.paginate(
      ir,
      config: cfg(),
      contentWidthDp: 200,
      contentHeightDp: 100,
    );
    expect(pages.length, greaterThan(1));

    for (var off = 0; off < ir.plainText.length; off++) {
      final idx = PaginationProgress.pageIndexAtCharOffset(pages, off);
      expect(idx, inInclusiveRange(0, pages.length - 1));
      final p = pages[idx];
      if (off == ir.plainText.length) {
        expect(idx, pages.length - 1);
      } else {
        expect(off, greaterThanOrEqualTo(p.startOffset));
        expect(off, lessThan(p.endOffset));
      }
    }

    // 章末夹紧
    final endIdx = PaginationProgress.pageIndexAtCharOffset(
      pages,
      ir.plainText.length,
    );
    expect(endIdx, pages.length - 1);
  });

  test('charOffsetForPage matches navigator inside-offset rule', () {
    const pages = [
      PackedPage(
        pageIndex: 0,
        startOffset: 0,
        endOffset: 10,
        slices: [],
        isLastPage: false,
      ),
      PackedPage(
        pageIndex: 1,
        startOffset: 10,
        endOffset: 11,
        slices: [],
        isLastPage: true,
      ),
    ];
    expect(PaginationProgress.charOffsetForPage(pages, 0), 1);
    expect(PaginationProgress.charOffsetForPage(pages, 1), 10);
  });

  test('font size change rebox keeps bookmark offset on a valid page', () {
    final ir = longIr();
    final bookmark = ir.plainText.length ~/ 3;

    final small = FlutterBlockPaginator.paginate(
      ir,
      config: cfg(fontSize: 14),
      contentWidthDp: 220,
      contentHeightDp: 120,
    );
    final large = FlutterBlockPaginator.paginate(
      ir,
      config: cfg(fontSize: 22),
      contentWidthDp: 220,
      contentHeightDp: 120,
    );

    expect(small.length, greaterThan(1));
    expect(large.length, greaterThan(1));
    // 字号变大通常页数增多（或至少不丢字符）
    expect(large.last.endOffset, ir.plainText.length);
    expect(small.last.endOffset, ir.plainText.length);

    expect(
      PaginationProgress.offsetStillOnResolvedPage(
        pages: large,
        charOffset: bookmark,
      ),
      isTrue,
    );
    expect(
      PaginationProgress.offsetStillOnResolvedPage(
        pages: small,
        charOffset: bookmark,
      ),
      isTrue,
    );

    final pageAfter = PaginationProgress.pageIndexAtCharOffset(large, bookmark);
    final anchor = PaginationProgress.charOffsetForPage(large, pageAfter);
    expect(
      PaginationProgress.offsetStillOnResolvedPage(
        pages: large,
        charOffset: anchor,
      ),
      isTrue,
    );
  });
}

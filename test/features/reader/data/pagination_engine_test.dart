import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/packed_page.dart';

void main() {
  group('PaginationEngine.chapterCharOffsetMax', () {
    const descriptors = [
      PackedPage(
        pageIndex: 0,
        startOffset: 0,
        endOffset: 100,
        slices: [],
        isLastPage: false,
      ),
      PackedPage(
        pageIndex: 1,
        startOffset: 100,
        endOffset: 105,
        slices: [],
        isLastPage: true,
      ),
    ];

    test('contentBlocks uses last descriptor endOffset', () {
      final phase1Plain = 'x' * 100;
      final max = PaginationEngine.chapterCharOffsetMax(
        sessionMode: ChapterPaginationMode.contentBlocks,
        descriptors: descriptors,
        phase1PlainContent: phase1Plain,
      );
      expect(max, 105);
    });

    test('plainText uses phase1 content length', () {
      const phase1Plain = 'hello';
      final max = PaginationEngine.chapterCharOffsetMax(
        sessionMode: ChapterPaginationMode.plainText,
        descriptors: descriptors,
        phase1PlainContent: phase1Plain,
      );
      expect(max, 5);
    });
  });
}

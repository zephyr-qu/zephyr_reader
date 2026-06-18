import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/pagination_viewport_index.dart';

void main() {
  group('pagination_viewport_index', () {
    test('virtual prev offset', () {
      expect(paginationVirtualPrevOffset(false), 0);
      expect(paginationVirtualPrevOffset(true), 1);
    });

    test('logical to physical page index', () {
      expect(
        paginationPhysicalPageIndex(
          logicalPageIndex: 3,
          hasPreviousChapter: true,
        ),
        4,
      );
      expect(
        paginationPhysicalPageIndex(
          logicalPageIndex: 3,
          hasPreviousChapter: false,
        ),
        3,
      );
    });

    test('max physical page with virtual prev and next staging', () {
      expect(
        paginationMaxPhysicalPageIndex(
          logicalPageCount: 10,
          hasPreviousChapter: true,
          hasNextStagingPage: true,
        ),
        11,
      );
      expect(
        paginationMaxPhysicalPageIndex(
          logicalPageCount: 10,
          hasPreviousChapter: false,
          hasNextStagingPage: false,
        ),
        9,
      );
    });
  });
}

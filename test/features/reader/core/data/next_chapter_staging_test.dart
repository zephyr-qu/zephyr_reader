// test/features/reader/core/data/next_chapter_staging_test.dart
//
// NextChapterStaging 单元测试 — 验证 M2 改 book_id 参数后
// staging 预取/提升链路：matches 比较、字段默认值、bookId 可空行为。

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/core/data/next_chapter_staging.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

final _descriptor = const PageDescriptor(
  pageIndex: 0,
  startOffset: 0,
  endOffset: 500,
  firstParagraphIndex: 0,
  lastParagraphIndex: 2,
  isLastPage: true,
);

final _hash1 = BigInt.from(12345);
final _hash2 = BigInt.from(67890);

void main() {
  group('NextChapterStaging constructor', () {
    test('stores all fields correctly', () {
      final staging = NextChapterStaging(
        chapterIndex: 3,
        configHash: _hash1,
        descriptors: [_descriptor],
        firstPageContent: 'hello',
        isPartial: false,
        paginationMode: ChapterPaginationMode.contentBlocks,
        bookId: 'book-abc',
        anchorPageBlocks: [],
      );
      expect(staging.chapterIndex, 3);
      expect(staging.configHash, _hash1);
      expect(staging.descriptors, [_descriptor]);
      expect(staging.firstPageContent, 'hello');
      expect(staging.isPartial, false);
      expect(staging.paginationMode, ChapterPaginationMode.contentBlocks);
      expect(staging.bookId, 'book-abc');
      expect(staging.anchorPageBlocks, isEmpty);
    });

    test(
      'defaults: paginationMode=plainText, bookId=null, anchorPageBlocks=null',
      () {
        final staging = NextChapterStaging(
          chapterIndex: 1,
          configHash: _hash1,
          descriptors: [_descriptor],
          firstPageContent: 'page0',
          isPartial: true,
        );
        expect(staging.paginationMode, ChapterPaginationMode.plainText);
        expect(staging.bookId, isNull);
        expect(staging.anchorPageBlocks, isNull);
      },
    );

    test('bookId supports string value (M2: filePath replaced)', () {
      final staging = NextChapterStaging(
        chapterIndex: 0,
        configHash: _hash1,
        descriptors: [_descriptor],
        firstPageContent: '',
        isPartial: false,
        bookId: 'e7a9b300-c1d4-4f5e',
      );
      expect(staging.bookId, equals('e7a9b300-c1d4-4f5e'));
    });
  });

  group('matches', () {
    final staging = NextChapterStaging(
      chapterIndex: 2,
      configHash: _hash1,
      descriptors: [_descriptor],
      firstPageContent: 'p0',
      isPartial: true,
    );

    test('returns true when chapterIndex and configHash match', () {
      expect(staging.matches(2, _hash1), isTrue);
    });

    test('returns false when chapterIndex differs', () {
      expect(staging.matches(3, _hash1), isFalse);
    });

    test('returns false when configHash differs', () {
      expect(staging.matches(2, _hash2), isFalse);
    });

    test('returns false when both differ', () {
      expect(staging.matches(4, _hash2), isFalse);
    });
  });

  group('staging promotion expectations', () {
    test('staging with matching hash promotes forward (matches=true)', () {
      final staging = NextChapterStaging(
        chapterIndex: 5,
        configHash: _hash1,
        descriptors: [_descriptor],
        firstPageContent: 'forward page 0',
        isPartial: true,
        bookId: 'some-book',
      );
      expect(staging.matches(5, BigInt.from(12345)), isTrue);
    });

    test('staging with mismatched hash forces normal load (matches=false)', () {
      final staging = NextChapterStaging(
        chapterIndex: 5,
        configHash: _hash1,
        descriptors: [_descriptor],
        firstPageContent: 'should not be used',
        isPartial: true,
      );
      expect(staging.matches(5, BigInt.from(99999)), isFalse);
    });
  });
}

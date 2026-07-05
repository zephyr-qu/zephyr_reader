// test/features/reader/core/application/chapter_pagination_intent_resolver_test.dart
//
// 验证 chapter_pagination_intent_resolver 推导与 partial 页码推算。

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_request.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_pagination_intent.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_pagination_intent_resolver.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
import 'package:zephyr_reader/features/reader/core/data/next_chapter_staging.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

class _MockRepo extends Mock implements ReaderRepositoryInterface {}

class _MockPagination extends Mock implements PaginationCoordinator {}

const _descriptors = [
  PageDescriptor(
    pageIndex: 0,
    startOffset: 0,
    endOffset: 100,
    isLastPage: true,
    firstParagraphIndex: 0,
    lastParagraphIndex: 0,
  ),
];

void main() {
  late _MockRepo repo;
  late _MockPagination pagination;

  setUp(() {
    repo = _MockRepo();
    pagination = _MockPagination();

    when(() => repo.sessionConfigHash).thenReturn(null);
    when(() => repo.descriptors).thenReturn(null);
    when(() => repo.sessionChapterIndex).thenReturn(null);
    when(() => repo.nextChapterStaging).thenReturn(null);
    when(() => repo.prevChapterStaging).thenReturn(null);
  });

  group('resolveChapterPaginationIntent', () {
    test('returns normalLoad when session is null (no configHash)', () {
      final intent = resolveChapterPaginationIntent(
        chapterIndex: 0,
        navigationKind: ChapterNavigationKind.manualJump,
        repo: repo,
        pagination: pagination,
      );
      expect(intent, ChapterPaginationIntent.normalLoad);
    });

    test('returns normalLoad when session has no descriptors', () {
      when(() => repo.sessionConfigHash).thenReturn(12345 as BigInt?);
      when(() => repo.sessionChapterIndex).thenReturn(0);
      when(() => repo.descriptors).thenReturn([]);

      final intent = resolveChapterPaginationIntent(
        chapterIndex: 0,
        navigationKind: ChapterNavigationKind.manualJump,
        repo: repo,
        pagination: pagination,
      );
      expect(intent, ChapterPaginationIntent.normalLoad);
    });

    test('returns normalLoad when chapterIndex differs from session', () {
      when(() => repo.sessionConfigHash).thenReturn(BigInt.from(12345));
      when(() => repo.descriptors).thenReturn(_descriptors);

      final intent = resolveChapterPaginationIntent(
        chapterIndex: 1,
        navigationKind: ChapterNavigationKind.manualJump,
        repo: repo,
        pagination: pagination,
      );
      expect(intent, ChapterPaginationIntent.normalLoad);
    });

    test('returns configReload when configHash changed', () {
      when(() => repo.sessionConfigHash).thenReturn(BigInt.from(12345));
      when(() => repo.sessionChapterIndex).thenReturn(0);
      when(() => repo.descriptors).thenReturn(_descriptors);
      when(() => pagination.computeConfigHash()).thenReturn(BigInt.from(67890));

      final intent = resolveChapterPaginationIntent(
        chapterIndex: 0,
        navigationKind: ChapterNavigationKind.manualJump,
        repo: repo,
        pagination: pagination,
      );
      expect(intent, ChapterPaginationIntent.configReload);
    });

    test('returns expandOnly when session is valid and configHash matches', () {
      when(() => repo.sessionConfigHash).thenReturn(BigInt.from(12345));
      when(() => repo.sessionChapterIndex).thenReturn(0);
      when(() => repo.descriptors).thenReturn(_descriptors);
      when(() => pagination.computeConfigHash()).thenReturn(BigInt.from(12345));

      final intent = resolveChapterPaginationIntent(
        chapterIndex: 0,
        navigationKind: ChapterNavigationKind.manualJump,
        repo: repo,
        pagination: pagination,
      );
      expect(intent, ChapterPaginationIntent.expandOnly);
    });

    test('returns stagingPromoteForward when next staging matches', () {
      when(() => repo.nextChapterStaging).thenReturn(
        NextChapterStaging(
          chapterIndex: 2,
          configHash: BigInt.from(999),
          descriptors: _descriptors,
          firstPageContent: 'page0',
          isPartial: true,
        ),
      );
      when(() => pagination.computeConfigHash()).thenReturn(BigInt.from(999));

      final intent = resolveChapterPaginationIntent(
        chapterIndex: 2,
        navigationKind: ChapterNavigationKind.adjacentCrossChapter,
        repo: repo,
        pagination: pagination,
      );
      expect(intent, ChapterPaginationIntent.stagingPromoteForward);
    });

    test('returns stagingPromoteBackward when prev staging matches', () {
      when(() => repo.prevChapterStaging).thenReturn(
        NextChapterStaging(
          chapterIndex: 1,
          configHash: BigInt.from(888),
          descriptors: _descriptors,
          firstPageContent: 'last',
          isPartial: true,
        ),
      );
      when(() => pagination.computeConfigHash()).thenReturn(BigInt.from(888));

      final intent = resolveChapterPaginationIntent(
        chapterIndex: 1,
        navigationKind: ChapterNavigationKind.adjacentCrossChapter,
        repo: repo,
        pagination: pagination,
      );
      expect(intent, ChapterPaginationIntent.stagingPromoteBackward);
    });

    test('prefers forward staging over backward when both match', () {
      when(() => repo.nextChapterStaging).thenReturn(
        NextChapterStaging(
          chapterIndex: 3,
          configHash: BigInt.from(111),
          descriptors: _descriptors,
          firstPageContent: 'fwd',
          isPartial: true,
        ),
      );
      when(() => repo.prevChapterStaging).thenReturn(
        NextChapterStaging(
          chapterIndex: 3,
          configHash: BigInt.from(111),
          descriptors: _descriptors,
          firstPageContent: 'bwd',
          isPartial: true,
        ),
      );
      when(() => pagination.computeConfigHash()).thenReturn(BigInt.from(111));

      final intent = resolveChapterPaginationIntent(
        chapterIndex: 3,
        navigationKind: ChapterNavigationKind.adjacentCrossChapter,
        repo: repo,
        pagination: pagination,
      );
      expect(intent, ChapterPaginationIntent.stagingPromoteForward);
    });

    test('falls through to normalLoad when staging hash mismatches', () {
      when(() => repo.nextChapterStaging).thenReturn(
        NextChapterStaging(
          chapterIndex: 2,
          configHash: BigInt.from(999),
          descriptors: _descriptors,
          firstPageContent: 'page0',
          isPartial: true,
        ),
      );
      when(() => pagination.computeConfigHash()).thenReturn(BigInt.from(1000));

      final intent = resolveChapterPaginationIntent(
        chapterIndex: 2,
        navigationKind: ChapterNavigationKind.adjacentCrossChapter,
        repo: repo,
        pagination: pagination,
      );
      expect(intent, ChapterPaginationIntent.normalLoad);
    });
  });

  group('shouldPreserveContentForIntent', () {
    test('normalLoad clears content skeleton', () {
      expect(
        shouldPreserveContentForIntent(ChapterPaginationIntent.normalLoad),
        isFalse,
      );
    });

    test('non-normalLoad intents preserve content', () {
      for (final intent in ChapterPaginationIntent.values) {
        if (intent == ChapterPaginationIntent.normalLoad) continue;
        expect(shouldPreserveContentForIntent(intent), isTrue);
      }
    });
  });

  group('resolveQuickPageForPartial', () {
    const multiPageDescriptors = [
      PageDescriptor(
        pageIndex: 0,
        startOffset: 0,
        endOffset: 99,
        isLastPage: false,
        firstParagraphIndex: 0,
        lastParagraphIndex: 0,
      ),
      PageDescriptor(
        pageIndex: 1,
        startOffset: 100,
        endOffset: 199,
        isLastPage: true,
        firstParagraphIndex: 1,
        lastParagraphIndex: 1,
      ),
    ];

    test('resolves page from offset within partial range', () {
      final result = resolveQuickPageForPartial(
        descriptors: multiPageDescriptors,
        initialCharOffset: 150,
        isPartial: true,
        fallbackPageIndex: 0,
      );
      expect(result.pageIndex, 1);
      expect(result.charOffsetForPartial, 150);
    });

    test('clamps offset beyond partial to page 0', () {
      final result = resolveQuickPageForPartial(
        descriptors: multiPageDescriptors,
        initialCharOffset: 500,
        isPartial: true,
        fallbackPageIndex: 3,
      );
      expect(result.pageIndex, 0);
      expect(result.charOffsetForPartial, 199);
    });

    test('uses fallback when resolve returns negative', () {
      final result = resolveQuickPageForPartial(
        descriptors: multiPageDescriptors,
        initialCharOffset: -5,
        isPartial: false,
        fallbackPageIndex: 7,
      );
      expect(result.pageIndex, 0);
      expect(result.charOffsetForPartial, 0);
    });
  });
}

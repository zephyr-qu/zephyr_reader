// test/features/reader/core/application/chapter_pagination_intent_resolver_test.dart
//
// 验证 ChapterLoadOrchestrator.resolveIntent 自动推导逻辑。

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_orchestrator.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_request.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_pagination_intent.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

class _MockRepo extends Mock implements ReaderRepository {}
class _MockPagination extends Mock implements PaginationCoordinator {}

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

  group('resolveIntent', () {
    test('returns normalLoad when session is null (no configHash)', () {
      final intent = ChapterLoadOrchestrator.resolveIntent(
        chapterIndex: 0,
        navigationKind: ChapterNavigationKind.manualJump,
        repo: repo,
        pagination: pagination,
      );
      expect(intent, ChapterPaginationIntent.normalLoad);
    });

    test('returns normalLoad when session has no descriptors', () {
      when(() => repo.sessionConfigHash).thenReturn(12345);
      when(() => repo.sessionChapterIndex).thenReturn(0);
      when(() => repo.descriptors).thenReturn([]);

      final intent = ChapterLoadOrchestrator.resolveIntent(
        chapterIndex: 0,
        navigationKind: ChapterNavigationKind.manualJump,
        repo: repo,
        pagination: pagination,
      );
      expect(intent, ChapterPaginationIntent.normalLoad);
    });

    test('returns normalLoad when chapterIndex differs from session', () {
      when(() => repo.sessionConfigHash).thenReturn(12345);
      when(() => repo.descriptors).thenReturn([
        const PageDescriptor(
          pageIndex: 0,
          startOffset: 0,
          endOffset: 100,
          isLastPage: false,
        ),
      ]);

      final intent = ChapterLoadOrchestrator.resolveIntent(
        chapterIndex: 1,
        navigationKind: ChapterNavigationKind.manualJump,
        repo: repo,
        pagination: pagination,
      );
      expect(intent, ChapterPaginationIntent.normalLoad);
    });

    test('returns configReload when configHash changed', () {
      when(() => repo.sessionConfigHash).thenReturn(12345);
      when(() => repo.sessionChapterIndex).thenReturn(0);

      when(() => repo.descriptors).thenReturn([
        const PageDescriptor(
          pageIndex: 0,
          startOffset: 0,
          endOffset: 100,
          isLastPage: true,
        ),
      ]);
      when(() => pagination.computeConfigHash()).thenReturn(67890);

      final intent = ChapterLoadOrchestrator.resolveIntent(
        chapterIndex: 0,
        navigationKind: ChapterNavigationKind.manualJump,
        repo: repo,
        pagination: pagination,
      );
      expect(intent, ChapterPaginationIntent.configReload);
    });

    test('returns expandOnly when session is valid and configHash matches', () {
      when(() => repo.sessionConfigHash).thenReturn(12345);
      when(() => repo.sessionChapterIndex).thenReturn(0);

      when(() => repo.descriptors).thenReturn([
        const PageDescriptor(
          pageIndex: 0,
          startOffset: 0,
          endOffset: 100,
          isLastPage: true,
        ),
      ]);
      when(() => pagination.computeConfigHash()).thenReturn(12345);

      final intent = ChapterLoadOrchestrator.resolveIntent(
        chapterIndex: 0,
        navigationKind: ChapterNavigationKind.manualJump,
        repo: repo,
        pagination: pagination,
      );
      expect(intent, ChapterPaginationIntent.expandOnly);
    });
  });
}

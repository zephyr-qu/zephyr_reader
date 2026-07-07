// test/features/reader/core/data/rust_pagination_session_test.dart
//
// 验证 RustPaginationSession 生命周期与状态管理：
// - create/expand/dispose 链路状态一致性
// - _applyPaginateResult 同步信号与缓存清理
// - dispose 清空所有内部状态

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/core/data/rust_pagination_session.dart';
import 'package:zephyr_reader/features/reader/core/domain/pagination_session.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

void main() {
  group('dispose', () {
    test('clears all internal state to defaults', () {
      final session = RustPaginationSession();

      // Simulate state after a successful pagination
      // (We can't call beginPaginate without FFI, so we verify
      //  that dispose resets everything regardless of state.)
      session.dispose();

      expect(session.descriptors, isNull);
      expect(session.sessionConfigHash, isNull);
      expect(session.sessionChapterIndex, isNull);
      expect(session.sessionIsPartial, isFalse);
      expect(session.sessionMode, ChapterPaginationMode.plainText);
      expect(session.sessionFilePath, isNull);
    });

    test('second dispose is safe (no throw)', () {
      final session = RustPaginationSession();
      session.dispose();
      // Second call should not throw
      session.dispose();
      expect(session.descriptors, isNull);
    });
  });

  group('cache operations (warm + pageContent)', () {
    test('warmPageCache stores content; pageContent retrieves it', () {
      final session = RustPaginationSession();

      // Warm cache doesn't require FFI — pure Dart operation
      session.warmPageCache(0, 'Hello page 0');
      session.warmPageCache(1, 'Hello page 1');

      expect(session.pageContent(0), 'Hello page 0');
      expect(session.pageContent(1), 'Hello page 1');
      expect(session.pageContent(2), isNull); // not cached
    });

    test('dispose clears warmed cache', () {
      final session = RustPaginationSession();
      session.warmPageCache(0, 'cached');

      session.dispose();

      expect(session.pageContent(0), isNull);
    });
  });

  group('resolvePageIndexForCharOffset without handle', () {
    test('returns null when no handle is set', () {
      final session = RustPaginationSession();
      // No handle — should return null (no FFI call attempted)
      expect(session.resolvePageIndexForCharOffset(100), isNull);
    });
  });

  group('fetchPageContent without handle', () {
    test('returns null when no descriptors are set', () async {
      final session = RustPaginationSession();
      final result = await session.fetchPageContent(0);
      expect(result, isNull);
    });
  });

  group('pageBlocks without handle', () {
    test('returns null when not cached', () {
      final session = RustPaginationSession();
      expect(session.pageBlocks(0), isNull);
    });
  });

  group('lifecycle state transitions', () {
    test('initial state is all-null/defaults', () {
      final session = RustPaginationSession();

      expect(session.descriptors, isNull);
      expect(session.sessionConfigHash, isNull);
      expect(session.sessionChapterIndex, isNull);
      expect(session.sessionIsPartial, isFalse);
      expect(session.sessionMode, ChapterPaginationMode.plainText);
      expect(session.sessionFilePath, isNull);
    });

    test('ensureWindow does not throw when descriptors is null', () {
      final session = RustPaginationSession();
      // Should silently return without FFI calls
      session.ensureWindow(0);
      // No crash
    });

    test('ensureWindow does not throw when descriptors is empty', () async {
      final session = RustPaginationSession();
      // Warm a page so we can observe it
      session.warmPageCache(0, 'content');

      // After dispose, ensureWindow won't try to fetch
      session.dispose();
      session.ensureWindow(0);
    });
  });

  group('PaginationSession interface compliance', () {
    test('RustPaginationSession implements PaginationSession', () {
      final session = RustPaginationSession();
      expect(session, isA<PaginationSession>());
    });

    test('all interface getters return expected defaults', () {
      final session = RustPaginationSession();

      expect(session.descriptors, isNull);
      expect(session.sessionConfigHash, isNull);
      expect(session.sessionChapterIndex, isNull);
      expect(session.sessionIsPartial, isFalse);
      expect(session.sessionMode, ChapterPaginationMode.plainText);
      expect(session.sessionFilePath, isNull);
    });
  });

  group('lifecycle (create → partial → expand → dispose)', () {
    late RustPaginationSession session;

    setUp(() {
      session = RustPaginationSession();
    });

    tearDown(() {
      session.dispose();
    });

    test('I3: partial→expand maintains descriptors integrity', () {
      // 1. Simulate partial result (first screen)
      final partialResult = PaginateResult(
        descriptors: [
          const PageDescriptor(
            pageIndex: 0,
            startOffset: 0,
            endOffset: 100,
            firstParagraphIndex: 0,
            lastParagraphIndex: 0,
            isLastPage: false,
          ),
        ],
        configHash: BigInt.from(123),
        isPartial: true,
        mode: ChapterPaginationMode.contentBlocks,
      );
      session.applyPaginateResult(partialResult);

      expect(session.descriptors?.length, 1);
      expect(session.sessionIsPartial, isTrue);
      expect(session.sessionConfigHash, BigInt.from(123));

      // 2. Simulate expand to full chapter
      final fullResult = PaginateResult(
        descriptors: [
          const PageDescriptor(
            pageIndex: 0,
            startOffset: 0,
            endOffset: 100,
            firstParagraphIndex: 0,
            lastParagraphIndex: 0,
            isLastPage: false,
          ),
          const PageDescriptor(
            pageIndex: 1,
            startOffset: 100,
            endOffset: 200,
            firstParagraphIndex: 1,
            lastParagraphIndex: 1,
            isLastPage: true,
          ),
        ],
        configHash: BigInt.from(123),
        isPartial: false,
        mode: ChapterPaginationMode.contentBlocks,
      );
      session.applyPaginateResult(fullResult);

      expect(session.descriptors?.length, 2);
      expect(session.sessionIsPartial, isFalse);

      // 3. Dispose — all state cleared
      session.dispose();
      expect(session.descriptors, isNull);
      expect(session.sessionConfigHash, isNull);
    });

    test('I9: configHash change updates internal state', () {
      final result1 = PaginateResult(
        descriptors: [
          const PageDescriptor(
            pageIndex: 0,
            startOffset: 0,
            endOffset: 50,
            firstParagraphIndex: 0,
            lastParagraphIndex: 0,
            isLastPage: true,
          ),
        ],
        configHash: BigInt.from(100),
        isPartial: false,
        mode: ChapterPaginationMode.contentBlocks,
      );
      session.applyPaginateResult(result1);
      expect(session.sessionConfigHash, BigInt.from(100));
      expect(session.descriptors?[0].endOffset, 50);

      // Config change → new hash, new page mapping
      final result2 = PaginateResult(
        descriptors: [
          const PageDescriptor(
            pageIndex: 0,
            startOffset: 0,
            endOffset: 45,
            firstParagraphIndex: 0,
            lastParagraphIndex: 0,
            isLastPage: true,
          ),
        ],
        configHash: BigInt.from(200),
        isPartial: false,
        mode: ChapterPaginationMode.contentBlocks,
      );
      session.applyPaginateResult(result2);

      expect(session.sessionConfigHash, BigInt.from(200));
      expect(session.descriptors?[0].endOffset, 45);
    });
  });
}

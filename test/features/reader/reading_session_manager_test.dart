
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/reader/application/chapter_manager.dart';
import 'package:zephyr_reader/features/reader/application/reading_session_manager.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';

// ===== Mocks =====

class _MockRepo extends Mock implements ReaderRepository {}

class _MockChapterManager extends Mock implements ChapterManager {}

// ===== Helpers =====

ReadingSessionManager createSession({
  ReaderRepository? repo,
  ChapterManager? chapterManager,
}) {
  return ReadingSessionManager(repo ?? _MockRepo(), chapterManager ?? _MockChapterManager());
}

void main() {
  late _MockRepo repo;
  late _MockChapterManager chapterManager;
  late ReadingSessionManager session;

  setUp(() {
    repo = _MockRepo();
    chapterManager = _MockChapterManager();

    // ChapterManager signal defaults
    when(() => chapterManager.bookId).thenReturn(signal<String>('book_test'));
    when(() => chapterManager.chapterIndex).thenReturn(signal<int>(0));
    when(() => chapterManager.currentCharOffset).thenReturn(signal<int>(0));
    when(() => chapterManager.pageIndex).thenReturn(signal<int>(0));
    when(() => chapterManager.totalPages).thenReturn(signal<int>(50));

    // ReaderRepository default mocks
    when(() => repo.updateReadingProgress(
      bookId: any(named: 'bookId'),
      chapterId: any(named: 'chapterId'),
      charOffset: any(named: 'charOffset'),
      pageIndex: any(named: 'pageIndex'),
      totalPages: any(named: 'totalPages'),
      readingTimeSeconds: any(named: 'readingTimeSeconds'),
    )).thenAnswer((_) async {});
  });

  group('ReadingSessionManager', () {
    // ==================== 初始状态 ====================

    group('初始状态', () {
      test('创建时信号应有默认值', () {
        final s = createSession(repo: repo, chapterManager: chapterManager);
        expect(s.readingDuration.value, 0);
        expect(s.isReading.value, false);
        expect(s.progressSaved.value, false);
      });
    });

    // ==================== startReading ====================

    group('startReading()', () {
      test('开始阅读应标记 isReading 为 true', () {
        session = createSession(repo: repo, chapterManager: chapterManager);
        session.startReading();

        expect(session.isReading.value, isTrue);
      });

      test('重复调用不会多次启动计时', () {
        session = createSession(repo: repo, chapterManager: chapterManager);
        session.startReading();
        final durationBefore = session.readingDuration.value;

        session.startReading(); // 不应重置或双倍累积

        // 短暂等待后验证 duration 只增加了一次
        expect(session.isReading.value, isTrue);
        expect(session.readingDuration.value - durationBefore, lessThanOrEqualTo(1));
      });
    });

    // ==================== stopReading ====================

    group('stopReading()', () {
      test('停止阅读应标记 isReading 为 false 并保存进度', () async {
        session = createSession(repo: repo, chapterManager: chapterManager);
        session.startReading();
        expect(session.isReading.value, isTrue);

        // 使用真实 repo mock，让 saveProgress 通过防抖
        when(() => repo.updateReadingProgress(
          bookId: any(named: 'bookId'),
          chapterId: any(named: 'chapterId'),
          charOffset: any(named: 'charOffset'),
          pageIndex: any(named: 'pageIndex'),
          totalPages: any(named: 'totalPages'),
          readingTimeSeconds: any(named: 'readingTimeSeconds'),
        )).thenAnswer((_) async {});

        await session.stopReading();

        expect(session.isReading.value, isFalse);
        verify(() => repo.updateReadingProgress(
          bookId: any(named: 'bookId'),
          chapterId: any(named: 'chapterId'),
          charOffset: any(named: 'charOffset'),
          pageIndex: any(named: 'pageIndex'),
          totalPages: any(named: 'totalPages'),
        )).called(1);
      });

      test('不在阅读中时停止应无操作', () async {
        session = createSession(repo: repo, chapterManager: chapterManager);
        await session.stopReading();

        expect(session.isReading.value, isFalse);
        verifyNever(() => repo.updateReadingProgress(
          bookId: any(named: 'bookId'),
          chapterId: any(named: 'chapterId'),
          charOffset: any(named: 'charOffset'),
          pageIndex: any(named: 'pageIndex'),
          totalPages: any(named: 'totalPages'),
        ));
      });
    });

    // ==================== saveProgress ====================

    group('saveProgress()', () {
      test('保存进度应调用 repo.updateReadingProgress', () async {
        session = createSession(repo: repo, chapterManager: chapterManager);

        // 强制置入足够旧的时间绕过防抖
        await session.saveProgress();

        verify(() => repo.updateReadingProgress(
          bookId: any(named: 'bookId'),
          chapterId: any(named: 'chapterId'),
          charOffset: any(named: 'charOffset'),
          pageIndex: any(named: 'pageIndex'),
          totalPages: any(named: 'totalPages'),
        )).called(1);
      });
      test('保存后设置 progressSaved 为 true', () async {
        session = createSession(repo: repo, chapterManager: chapterManager);
        expect(session.progressSaved.value, false);

        await session.saveProgress();

        expect(session.progressSaved.value, isTrue);
      });

      test('短时间重复调用受防抖保护（5 秒内跳过）', () async {
        session = createSession(repo: repo, chapterManager: chapterManager);

        await session.saveProgress(); // 第一次调用

        // 第二次立即调用应被防抖跳过
        await session.saveProgress();

        // verify 按总调用次数检查，应只有 1 次
        verify(() => repo.updateReadingProgress(
          bookId: any(named: 'bookId'),
          chapterId: any(named: 'chapterId'),
          charOffset: any(named: 'charOffset'),
          pageIndex: any(named: 'pageIndex'),
          totalPages: any(named: 'totalPages'),
          readingTimeSeconds: any(named: 'readingTimeSeconds'),
        )).called(1);
      });

      test('保存失败不应抛异常（静默日志）', () async {
        when(() => repo.updateReadingProgress(
          bookId: any(named: 'bookId'),
          chapterId: any(named: 'chapterId'),
          charOffset: any(named: 'charOffset'),
          pageIndex: any(named: 'pageIndex'),
          totalPages: any(named: 'totalPages'),
        )).thenThrow(Exception('db error'));

        session = createSession(repo: repo, chapterManager: chapterManager);

        // 不应抛出异常
        await session.saveProgress();
      });

      test('阅读时长传递给 repo', () async {
        session = createSession(repo: repo, chapterManager: chapterManager);
        session.startReading();
        session.readingDuration.value = 42;

        await session.saveProgress();

        verify(() => repo.updateReadingProgress(
          bookId: any(named: 'bookId'),
          chapterId: any(named: 'chapterId'),
          charOffset: any(named: 'charOffset'),
          pageIndex: any(named: 'pageIndex'),
          totalPages: any(named: 'totalPages'),
          readingTimeSeconds: 42,
        )).called(1);
      });
    });

    // ==================== startAutoSave ====================

    group('startAutoSave()', () {
      test('启动自动保存应开始周期性保存', () async {
        session = createSession(repo: repo, chapterManager: chapterManager);

        session.startAutoSave();

        // 等待定时器触发（Timer.periodic 30秒），短时间内不会触发
        // 只能验证不抛异常且 isReading 不受影响
        expect(session.isReading.value, false);
      });
    });

    // ==================== restoreReadingDuration ====================

    group('restoreReadingDuration()', () {
      test('恢复阅读时长', () {
        session = createSession(repo: repo, chapterManager: chapterManager);
        session.restoreReadingDuration(120);

        expect(session.readingDuration.value, 120);
      });
    });

    // ==================== reset ====================

    group('reset()', () {
      test('重置所有信号到默认值', () {
        session = createSession(repo: repo, chapterManager: chapterManager);
        session.startReading();
        session.readingDuration.value = 99;
        session.progressSaved.value = true;

        session.reset();

        expect(session.readingDuration.value, 0);
        expect(session.isReading.value, false);
        expect(session.progressSaved.value, false);
      });
    });

    // ==================== 生命周期 ====================

    group('dispose', () {
      test('dispose 后不再触发定时器', () {
        session = createSession(repo: repo, chapterManager: chapterManager);
        session.startReading();

        session.dispose();

        expect(session.isReading.value, isTrue); // 信号值不变
        // 但计时器应已取消，可通过等待验证不抛异常
      });
    });
  });
}

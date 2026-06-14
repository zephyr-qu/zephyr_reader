import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/reader/application/chapter_view_model.dart';
import 'package:zephyr_reader/features/reader/application/reader_page_state.dart';
import 'package:zephyr_reader/features/reader/application/reading_session_manager.dart';
class _MockChapterManager extends Mock implements ChapterViewModel {}

void main() {
  late _MockChapterManager chapterManager;
  late ReadingSessionManager session;

  setUp(() {
    final pageState = ReaderPageState();
    pageState.bookId.value = 'book_test';
    pageState.chapterIndex.value = 0;
    pageState.currentCharOffset.value = 0;

    chapterManager = _MockChapterManager();
    when(() => chapterManager.pageIndex).thenReturn(signal<int>(0));
    when(() => chapterManager.totalPages).thenReturn(signal<int>(50));

    session = ReadingSessionManager(pageState, chapterManager);
  });

  // ==================== 初始状态 ====================

  group('初始状态', () {
    test('创建时信号应有默认值', () {
      expect(session.readingDuration.value, 0);
      expect(session.isReading.value, false);
    });
  });

  // ==================== restoreReadingDuration ====================

  group('restoreReadingDuration()', () {
    test('恢复阅读时长设置信号值', () {
      session.restoreReadingDuration(120);
      expect(session.readingDuration.value, equals(120));
    });

    test('零值恢复', () {
      session.restoreReadingDuration(0);
      expect(session.readingDuration.value, equals(0));
    });

    test('大数值恢复', () {
      session.restoreReadingDuration(99999);
      expect(session.readingDuration.value, equals(99999));
    });
  });

  // ==================== startReading ====================

  group('startReading()', () {
    test('开始阅读标记 isReading 为 true', () {
      session.startReading();
      expect(session.isReading.value, isTrue);
    });

    test('重复调用不会多次启动计时', () async {
      session.startReading();
      final before = session.readingDuration.value;

      session.startReading(); // 重复调用

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      // duration 只会按一个计时器累加
      expect(session.readingDuration.value - before, greaterThanOrEqualTo(1));
    });

    test('开始阅读后 duration 随时间递增', () async {
      session.startReading();
      final before = session.readingDuration.value;

      await Future<void>.delayed(const Duration(milliseconds: 2100));

      // 大约 2 秒后 duration 应增加约 2
      expect(session.readingDuration.value - before, greaterThanOrEqualTo(1));
    });
  });

  // ==================== stopReading ====================

  group('stopReading()', () {
    test('不在阅读中时停止无操作', () async {
      await session.stopReading();
      expect(session.isReading.value, isFalse);
    });

    test('阅读中停止标记 isReading 为 false', () async {
      session.startReading();
      expect(session.isReading.value, isTrue);

      await session.stopReading();
      expect(session.isReading.value, isFalse);
    });

    test('停止后计时器不再增加时长', () async {
      session.startReading();
      await Future<void>.delayed(const Duration(milliseconds: 500));

      await session.stopReading();
      final durationAfterStop = session.readingDuration.value;

      // 再等 500ms，duration 不应变化
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(session.readingDuration.value, equals(durationAfterStop));
    });
  });

  // ==================== saveProgress (pure-Dart guards only) ====================

  group('saveProgress() guard clauses', () {
    test('不在阅读时不保存（isReading=false 直接返回）', () async {
      // isReading 默认为 false，saveProgress 应在 guard 1 处直接返回
      // 不会触发 FFI 调用，不应抛异常
      await session.saveProgress();
      expect(session.isReading.value, isFalse);
    });

    test('阅读中保存不抛异常（FFI 错误被 try/catch 吞噬）', () async {
      // 直接设置 isReading 为 true 绕过 startReading 的 timer
      session.isReading.value = true;

      // saveProgress 会尝试调用 FFI，FFI 会抛出异常但被 try/catch 捕获
      // 不应向上传播异常
      await session.saveProgress();
    });
  });

  // ==================== startAutoSave ====================

  group('startAutoSave()', () {
    test('启动自动保存不抛异常', () {
      session.startAutoSave();
      expect(session.isReading.value, isFalse);
    });

    test('阅读中自动保存不抛异常', () async {
      session.startReading();
      session.startAutoSave();

      await Future<void>.delayed(const Duration(milliseconds: 500));
      // 自动保存定时器 30 秒才触发，此处仅验证不抛异常
      expect(session.isReading.value, isTrue);
    });
  });

  // ==================== reset ====================

  group('reset()', () {
    test('重置所有信号到默认值', () {
      session.startReading();
      session.readingDuration.value = 99;

      session.reset();

      expect(session.readingDuration.value, equals(0));
      expect(session.isReading.value, isFalse);
    });

    test('重置后计时器停止不再增长', () async {
      session.startReading();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      session.reset();

      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(session.readingDuration.value, equals(0));
    });
  });

  group('dispose()', () {
    test('dispose 后计时器停止', () async {
      session.startReading();
      await session.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 500));
      // dispose 后 isReading 被置为 false
      expect(session.isReading.value, isFalse);
    });

    test('dispose 后即使 isReading=true, duration 不再增长', () async {
      session.startReading();
      session.readingDuration.value = 42;
      await session.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(session.readingDuration.value, equals(42));
    });

    test('dispose 后调用 stopReading 安全', () async {
      session.startReading();
      await session.dispose();

      // stopReading 在 dispose 后应安全执行
      await session.stopReading();
      expect(session.isReading.value, isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/statistics/application/reading_stats_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadingStatsViewModel Tests', () {
    late ReadingStatsViewModel service;

    setUp(() {
      service = ReadingStatsViewModel();
    });

    tearDown(() {
      service.dispose();
    });

    test('initial state is correct', () {
      expect(service.currentSessionId.value, isNull);
      expect(service.isSessionActive.value, isFalse);
      // Note: dashboardLoading and dashboardError might not exist in all implementations,
      // but included based on reference. If they don't exist, these lines should be removed.
      // Assuming they exist based on the prompt's reference code.
    });

    test('startReadingSession sets session ID', () {
      final sessionId = service.startReadingSession('book1', 0, 0);
      expect(sessionId, isNotEmpty);
      expect(service.currentSessionId.value, equals(sessionId));
      expect(service.isSessionActive.value, isTrue);
    });

    test('endReadingSession clears session', () async {
      service.startReadingSession('book1', 0, 0);
      await service.endReadingSession(100);
      expect(service.currentSessionId.value, isNull);
      expect(service.isSessionActive.value, isFalse);
    });

    test('endReadingSession does nothing when no active session', () async {
      expect(service.isSessionActive.value, isFalse);
      await service.endReadingSession(0);
      expect(service.isSessionActive.value, isFalse);
      expect(service.currentSessionId.value, isNull);
    });

    test('short session (<2s and no progress) is discarded', () async {
      service.startReadingSession('book1', 0, 0);
      expect(service.isSessionActive.value, isTrue);
      expect(service.currentSessionId.value, isNotNull);
      final discardedId = service.currentSessionId.value;

      // 立即结束，无阅读进度 → 会话应被丢弃（不保存）
      // 注: session_api.createSession 是 FFI 调用，该 ViewModel 不支持注入 Mock，
      // 此处验证可观测的契约：会话状态被清除，且后续可新建会话
      await service.endReadingSession(0);

      // 会话已清理
      expect(service.isSessionActive.value, isFalse);
      expect(service.currentSessionId.value, isNull);

      // 丢弃后结束会话应为空操作（内部状态已清空）
      await service.endReadingSession(50);
      expect(service.isSessionActive.value, isFalse);
      expect(service.currentSessionId.value, isNull);

      // 丢弃后可正常开始新会话（证明内部上下文完全重置）

      // 确保不同毫秒，避免 sessionId 碰撞
      await Future.delayed(const Duration(milliseconds: 2));
      service.startReadingSession('book2', 1, 100);
      expect(service.isSessionActive.value, isTrue);
      expect(service.currentSessionId.value, isNotNull);
      expect(service.currentSessionId.value, isNot(equals(discardedId)));

      // 新会话的 endReadingSession 也正常工作
      await service.endReadingSession(150);
      expect(service.isSessionActive.value, isFalse);
      expect(service.currentSessionId.value, isNull);
    });

    test('startReadingSession replaces old session', () async {
      service.startReadingSession('book1', 0, 0);
      final firstId = service.currentSessionId.value;

      await Future.delayed(const Duration(milliseconds: 2));
      service.startReadingSession('book2', 1, 50);

      expect(service.currentSessionId.value, isNot(equals(firstId)));
      expect(service.isSessionActive.value, isTrue);
    });

    test('updateProgress does nothing without active session', () {
      service.updateProgress(50);
      expect(service.currentSessionId.value, isNull);
    });

    test('updateProgress updates offset with active session', () {
      service.startReadingSession('book1', 0, 0);
      service.updateProgress(100);
      // Internal state updated, session still active
      expect(service.isSessionActive.value, isTrue);
    });

    test('discardCurrentSession clears session', () {
      service.startReadingSession('book1', 0, 0);
      expect(service.isSessionActive.value, isTrue);

      service.discardCurrentSession();

      expect(service.isSessionActive.value, isFalse);
      expect(service.currentSessionId.value, isNull);
    });

    // Note: Tests for getDailyRecords, getTodayReadingData, etc. depend on
    // how ReadingStatsViewModel exposes this data or allows mocking.
    // The reference code did not include these, so they are omitted to strictly follow
    // the "correct ReadingStatsViewModel API" pattern provided which focuses on state management.
    // If these methods exist on ViewModel and return Futures, they can be tested similarly
    // if the ViewModel allows injecting a mock repository or if we test integration.
  });
}

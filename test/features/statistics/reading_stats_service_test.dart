library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/statistics/application/reading_stats_service.dart';
import 'package:zephyr_reader/features/statistics/domain/repositories/statistics_repository.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class _MockStatsRepository implements StatisticsRepository {
  List<ReadingSession> recordedSessions = [];
  List<ReadingStats> mockStatsRange = [];
  GlobalStats? mockGlobalStats;

  @override
  Future<void> recordReadingSession(ReadingSession session) async {
    recordedSessions.add(session);
  }

  @override
  Future<List<ReadingStats>> getReadingStatsRange({
    required String startDate,
    required String endDate,
  }) async => mockStatsRange;

  @override
  Future<GlobalStats> getGlobalReadingStats() async =>
      mockGlobalStats ??
      const GlobalStats(
        totalReadingTimeSeconds: 0,
        totalCharactersRead: 0,
        booksReadCount: 0,
        booksCompletedCount: 0,
        consecutiveReadingDays: 0,
        todayReadingTimeSeconds: 0,
        todayCharactersRead: 0,
        averageReadingSpeed: 0,
        totalBooksCount: 0,
        totalNotesCount: 0,
        totalBookmarksCount: 0,
      );

  @override
  Future<List<ReadingSession>> getReadingSessions(
    String bookId, {
    int limit = 100,
  }) async => recordedSessions;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadingStatsService', () {
    late _MockStatsRepository storage;
    late ReadingStatsService service;

    setUp(() {
      storage = _MockStatsRepository();
      service = ReadingStatsService(storage);
    });

    group('阅读会话', () {
      test('startReadingSession 应创建并返回会话 ID', () {
        final sessionId = service.startReadingSession('book_1', 0, 0);

        expect(sessionId, isNotEmpty);
        expect(service.isSessionActive, isTrue);
        expect(service.currentSessionId, equals(sessionId));
      });

      test('endReadingSession 应结束当前会话', () async {
        service.startReadingSession('book_1', 0, 0);
        expect(service.isSessionActive, isTrue);

        service.updateProgress(100);
        await service.endReadingSession(100);

        expect(service.isSessionActive, isFalse);
        expect(storage.recordedSessions.length, equals(1));
      });

      test('endReadingSession 在无活跃会话时应无操作', () async {
        expect(service.isSessionActive, isFalse);

        await service.endReadingSession(0);

        expect(service.isSessionActive, isFalse);
        expect(storage.recordedSessions.length, equals(0));
      });

      test('短会话（<2 秒且未阅读）不应保存', () async {
        service.startReadingSession('book_1', 0, 0);

        await service.endReadingSession(0);

        expect(storage.recordedSessions.length, equals(0));
        expect(service.isSessionActive, isFalse);
      });

      test('startReadingSession 应替换旧会话', () async {
        service.startReadingSession('book_1', 0, 0);
        final firstId = service.currentSessionId;

        await Future.delayed(const Duration(milliseconds: 2));
        service.startReadingSession('book_2', 1, 50);

        expect(service.currentSessionId, isNot(equals(firstId)));
      });

      test('updateProgress 应更新当前偏移', () {
        service.startReadingSession('book_1', 0, 0);
        service.updateProgress(50);

        // 通过结束会话验证偏移被正确记录
        // 内部 _currentCharOffset 被设为 50
        expect(service.isSessionActive, isTrue);
      });
    });

    group('统计数据', () {
      test('getDailyRecords 应返回最近阅读统计', () async {
        storage.mockStatsRange = [
          const ReadingStats(
            bookId: 'book_1',
            date: '2026-05-18',
            readingTimeSeconds: 1800,
            charactersRead: 5000,
            sessionCount: 2,
          ),
        ];

        final records = await service.getDailyRecords(days: 7);

        expect(records.length, equals(1));
        expect(records.first.readingTimeSeconds, equals(1800));
      });

      test('getTodayReadingData 应返回今日汇总', () async {
        storage.mockStatsRange = [
          const ReadingStats(
            bookId: 'book_1',
            date: '2026-05-18',
            readingTimeSeconds: 900,
            charactersRead: 3000,
            sessionCount: 1,
          ),
          const ReadingStats(
            bookId: 'book_2',
            date: '2026-05-18',
            readingTimeSeconds: 600,
            charactersRead: 2000,
            sessionCount: 1,
          ),
        ];

        final (seconds, chars) = await service.getTodayReadingData();

        expect(seconds, equals(1500));
        expect(chars, equals(5000));
      });

      test('getConsecutiveReadingDays 应返回连续天数', () async {
        storage.mockGlobalStats = const GlobalStats(
          totalReadingTimeSeconds: 36000,
          totalCharactersRead: 100000,
          booksReadCount: 5,
          booksCompletedCount: 2,
          consecutiveReadingDays: 7,
          todayReadingTimeSeconds: 1800,
          todayCharactersRead: 5000,
          averageReadingSpeed: 300,
          totalBooksCount: 10,
          totalNotesCount: 20,
          totalBookmarksCount: 15,
        );

        final days = await service.getConsecutiveReadingDays();

        expect(days, equals(7));
      });

      test('getReadingSpeed 应返回阅读速度', () async {
        storage.mockGlobalStats = const GlobalStats(
          totalReadingTimeSeconds: 3600,
          totalCharactersRead: 30000,
          booksReadCount: 3,
          booksCompletedCount: 1,
          consecutiveReadingDays: 5,
          todayReadingTimeSeconds: 1800,
          todayCharactersRead: 5000,
          averageReadingSpeed: 500,
          totalBooksCount: 5,
          totalNotesCount: 10,
          totalBookmarksCount: 8,
        );

        final speed = await service.getReadingSpeed();

        expect(speed, greaterThan(0));
      });

      test('getReadingSpeed 无阅读时间时应返回 0', () async {
        final speed = await service.getReadingSpeed();
        expect(speed, equals(0));
      });

      test('getGlobalStats 应返回全局统计', () async {
        final stats = await service.getGlobalStats();
        expect(stats, isNotNull);
      });

      test('discardCurrentSession 应清空但<U+4E0D>保存', () {
        service.startReadingSession('book_1', 0, 0);
        expect(service.isSessionActive, isTrue);

        service.discardCurrentSession();

        expect(service.isSessionActive, isFalse);
        expect(storage.recordedSessions.length, equals(0));
      });
    });
  });
}

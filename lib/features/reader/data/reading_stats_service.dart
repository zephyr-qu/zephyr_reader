/// 阅读统计服务（基于 Rust）
library;

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@injectable
class ReadingStatsService {
  final _storage = RustStorageService();

  Future<void> init() async {}

  Future<void> recordReadingSession({
    required int bookId,
    required int chapterId,
    required int durationSeconds,
    required int charactersRead,
  }) async {
    try {
      await _storage.recordReadingSession(
        bookId: 'book_$bookId',
        chapterIndex: chapterId,
        startOffset: 0,
        endOffset: charactersRead,
        durationSeconds: durationSeconds,
        charactersRead: charactersRead,
      );
    } catch (e) {
      debugPrint('ReadingStatsService.recordReadingSession error: $e');
      rethrow;
    }
  }

  Future<DbGlobalStats> getReadingStats() async {
    try {
      return await _storage.getReadingStats();
    } catch (e) {
      debugPrint('ReadingStatsService.getReadingStats error: $e');
      return const DbGlobalStats(
        totalReadingTimeSeconds: 0,
        totalCharactersRead: 0,
        booksReadCount: 0,
        booksCompletedCount: 0,
        consecutiveReadingDays: 0,
        todayReadingTimeSeconds: 0,
        todayCharactersRead: 0,
        averageReadingSpeed: 0.0,
      );
    }
  }

  Future<(int, int)> getTodayReadingData() async {
    try {
      return await _storage.getTodayReadingData();
    } catch (e) {
      debugPrint('ReadingStatsService.getTodayReadingData error: $e');
      return (0, 0);
    }
  }

  Future<DbDailyReadingStats?> getDailyReadingRecord(String date) async {
    try {
      return await _storage.getDailyReadingRecord(date);
    } catch (e) {
      debugPrint('ReadingStatsService.getDailyReadingRecord error: $e');
      return null;
    }
  }

  Future<dynamic> getDailyReadingRecordsInRange({
    required String startDate,
    required String endDate,
  }) async {
    try {
      return await _storage.getDailyReadingRecordsInRange(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      debugPrint('ReadingStatsService.getDailyReadingRecordsInRange error: $e');
      return [];
    }
  }

  Future<dynamic> getRecentReadingRecords(int days) async {
    try {
      return await _storage.getRecentReadingRecords(days);
    } catch (e) {
      debugPrint('ReadingStatsService.getRecentReadingRecords error: $e');
      return [];
    }
  }

  Future<int> getConsecutiveReadingDays() async {
    try {
      return await _storage.getConsecutiveReadingDays();
    } catch (e) {
      debugPrint('ReadingStatsService.getConsecutiveReadingDays error: $e');
      return 0;
    }
  }

  Future<double> getReadingSpeed() async {
    try {
      return await _storage.getReadingSpeed();
    } catch (e) {
      debugPrint('ReadingStatsService.getReadingSpeed error: $e');
      return 0.0;
    }
  }

  Future<void> incrementBooksReadCount() async {}
  Future<void> incrementBooksCompletedCount() async {}
}

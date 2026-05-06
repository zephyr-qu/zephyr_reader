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
      return _storage.getGlobalReadingStats();
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
        totalBooksCount: 0,
        totalNotesCount: 0,
        totalBookmarksCount: 0,
        maxConsecutiveReadingDays: 0,
      );
    }
  }

  Future<(int, int)> getTodayReadingData() async {
    try {
      final stats = _storage.getTodayReadingStats();
      return (
        stats.totalReadingTimeSeconds.toInt(),
        stats.totalCharactersRead.toInt()
      );
    } catch (e) {
      debugPrint('ReadingStatsService.getTodayReadingData error: $e');
      return (0, 0);
    }
  }

  Future<DbDailyReadingStats?> getDailyReadingRecord(String date) async {
    try {
      final stats = await _storage.getReadingStatsRange(
        startDate: date,
        endDate: date,
      );
      return stats.isNotEmpty ? stats.first : null;
    } catch (e) {
      debugPrint('ReadingStatsService.getDailyReadingRecord error: $e');
      return null;
    }
  }

  Future<List<DbDailyReadingStats>> getDailyReadingRecordsInRange({
    required String startDate,
    required String endDate,
  }) async {
    try {
      return await _storage.getReadingStatsRange(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      debugPrint('ReadingStatsService.getDailyReadingRecordsInRange error: $e');
      return [];
    }
  }

  Future<List<DbDailyReadingStats>> getRecentReadingRecords(int days) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days - 1));
      return await _storage.getReadingStatsRange(
        startDate: startDate.toIso8601String().split('T').first,
        endDate: endDate.toIso8601String().split('T').first,
      );
    } catch (e) {
      debugPrint('ReadingStatsService.getRecentReadingRecords error: $e');
      return [];
    }
  }

  Future<int> getConsecutiveReadingDays() async {
    try {
      final stats = _storage.getGlobalReadingStats();
      return stats.consecutiveReadingDays;
    } catch (e) {
      debugPrint('ReadingStatsService.getConsecutiveReadingDays error: $e');
      return 0;
    }
  }

  Future<double> getReadingSpeed() async {
    try {
      final stats = _storage.getGlobalReadingStats();
      return stats.averageReadingSpeed;
    } catch (e) {
      debugPrint('ReadingStatsService.getReadingSpeed error: $e');
      return 0.0;
    }
  }

  Future<void> incrementBooksReadCount() async {}
  Future<void> incrementBooksCompletedCount() async {}
}

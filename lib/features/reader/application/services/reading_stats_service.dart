/// 阅读统计服务（基于 Drift）
///
/// 功能：
/// - 记录阅读会话
/// - 获取阅读统计
/// - 获取每日阅读记录
library;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/core/database/tables/db_reading_stats.dart';
import 'package:zephyr_reader/src/rust/ffi/types.dart';

const _uuid = Uuid();

/// 阅读统计服务
class ReadingStatsService {
  final AppDatabase _db;

  ReadingStatsService(this._db);

  /// 初始化阅读统计
  Future<void> init() async {
    await _db.initReadingStats();
  }

  /// 记录阅读会话
  Future<void> recordReadingSession({
    required String bookId,
    required int chapterId,
    required int durationSeconds,
    required int charactersRead,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final sessionId = _uuid.v4();
      final today = DateTime.now().toString().split(' ')[0];

      // 记录会话
      await _db.recordReadingSession(
        sessionId: sessionId,
        bookId: bookId,
        chapterId: chapterId,
        startTimestamp: now - durationSeconds,
        endTimestamp: now,
        durationSeconds: durationSeconds,
        charactersRead: charactersRead,
      );

      // 更新每日记录
      await _db.updateDailyReadingRecord(
        date: today,
        readingTimeSeconds: durationSeconds,
        charactersRead: charactersRead,
      );

      // 更新累计统计
      await _updateStats(durationSeconds, charactersRead, today);
    } catch (e) {
      debugPrint('ReadingStatsService.recordReadingSession error: $e');
      rethrow;
    }
  }

  /// 更新累计统计
  Future<void> _updateStats(
    int durationSeconds,
    int charactersRead,
    String today,
  ) async {
    final stats = await _db.getReadingStats();

    if (stats == null) {
      await _db.initReadingStats();
      return;
    }

    // 检查连续阅读天数
    int consecutiveDays = stats.consecutiveReadingDays;
    final lastReadDate = stats.lastReadDate;

    if (lastReadDate == null) {
      consecutiveDays = 1;
    } else {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toString()
          .split(' ')[0];

      if (lastReadDate == today) {
        // 同一天，保持连续天数不变
      } else if (lastReadDate == yesterday) {
        // 昨天阅读过，连续天数 +1
        consecutiveDays++;
      } else {
        // 断掉了，重新开始
        consecutiveDays = 1;
      }
    }

    await _db.updateReadingStats(
      totalReadingTimeSeconds: stats.totalReadingTimeSeconds + durationSeconds,
      totalCharactersRead: stats.totalCharactersRead + charactersRead,
      booksReadCount: stats.booksReadCount,
      booksCompletedCount: stats.booksCompletedCount,
      lastReadDate: today,
      consecutiveReadingDays: consecutiveDays,
    );
  }

  /// 获取阅读统计
  Future<ReadingStats> getReadingStats() async {
    try {
      final stats = await _db.getReadingStats();

      if (stats == null) {
        return ReadingStats(
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

      // 获取今日数据
      final (todayTime, todayChars) = await _db.getTodayReadingData();

      // 计算平均阅读速度
      final avgSpeed = stats.totalReadingTimeSeconds > 0
          ? (stats.totalCharactersRead / stats.totalReadingTimeSeconds) * 60.0
          : 0.0;

      return ReadingStats(
        totalReadingTimeSeconds: stats.totalReadingTimeSeconds,
        totalCharactersRead: stats.totalCharactersRead,
        booksReadCount: stats.booksReadCount,
        booksCompletedCount: stats.booksCompletedCount,
        consecutiveReadingDays: stats.consecutiveReadingDays,
        todayReadingTimeSeconds: todayTime,
        todayCharactersRead: todayChars,
        averageReadingSpeed: avgSpeed,
      );
    } catch (e) {
      debugPrint('ReadingStatsService.getReadingStats error: $e');
      return ReadingStats(
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

  /// 获取今日阅读数据
  Future<(int, int)> getTodayReadingData() async {
    try {
      return await _db.getTodayReadingData();
    } catch (e) {
      debugPrint('ReadingStatsService.getTodayReadingData error: $e');
      return (0, 0);
    }
  }

  /// 获取指定日期的阅读记录
  Future<DailyReadingRecordItem?> getDailyReadingRecord(String date) async {
    try {
      return await _db.getDailyReadingRecord(date);
    } catch (e) {
      debugPrint('ReadingStatsService.getDailyReadingRecord error: $e');
      return null;
    }
  }

  /// 获取日期范围内的阅读记录
  Future<List<DailyReadingRecord>> getDailyReadingRecordsInRange({
    required String startDate,
    required String endDate,
  }) async {
    try {
      return await _db.getDailyReadingRecordsInRange(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      debugPrint('ReadingStatsService.getDailyReadingRecordsInRange error: $e');
      return [];
    }
  }

  /// 获取最近 N 天的阅读记录
  Future<List<DailyReadingRecord>> getRecentReadingRecords(int days) async {
    try {
      return await _db.getRecentReadingRecords(days);
    } catch (e) {
      debugPrint('ReadingStatsService.getRecentReadingRecords error: $e');
      return [];
    }
  }

  /// 获取连续阅读天数
  Future<int> getConsecutiveReadingDays() async {
    try {
      return await _db.getConsecutiveReadingDays();
    } catch (e) {
      debugPrint('ReadingStatsService.getConsecutiveReadingDays error: $e');
      return 0;
    }
  }

  /// 获取平均阅读速度
  Future<double> getReadingSpeed() async {
    try {
      return await _db.getReadingSpeed();
    } catch (e) {
      debugPrint('ReadingStatsService.getReadingSpeed error: $e');
      return 0.0;
    }
  }

  /// 更新书籍阅读计数
  Future<void> incrementBooksReadCount() async {
    try {
      await _db.incrementBooksReadCount();
    } catch (e) {
      debugPrint('ReadingStatsService.incrementBooksReadCount error: $e');
    }
  }

  /// 更新完成阅读书籍计数
  Future<void> incrementBooksCompletedCount() async {
    try {
      await _db.incrementBooksCompletedCount();
    } catch (e) {
      debugPrint('ReadingStatsService.incrementBooksCompletedCount error: $e');
    }
  }
}

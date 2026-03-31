/// 阅读统计领域模型
library;

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr_reader/core/database/database.dart';

part 'reading_stats.freezed.dart';

/// 阅读统计领域模型
@freezed
abstract class ReadingStats with _$ReadingStats {
  const factory ReadingStats({
    /// 固定 ID = 1
    @Default(1) int id,

    /// 总阅读时长（秒）
    @Default(0) int totalReadingTimeSeconds,

    /// 总阅读字数
    @Default(0) int totalCharactersRead,

    /// 阅读书籍数量
    @Default(0) int booksReadCount,

    /// 完成阅读书籍数量
    @Default(0) int booksCompletedCount,

    /// 最后阅读日期（YYYY-MM-DD 格式）
    String? lastReadDate,

    /// 连续阅读天数
    @Default(0) int consecutiveReadingDays,
  }) = _ReadingStats;

  /// 从数据库模型转换
  factory ReadingStats.fromDb(DbReadingStats db) {
    return ReadingStats(
      id: db.id,
      totalReadingTimeSeconds: db.totalReadingTimeSeconds,
      totalCharactersRead: db.totalCharactersRead,
      booksReadCount: db.booksReadCount,
      booksCompletedCount: db.booksCompletedCount,
      lastReadDate: db.lastReadDate,
      consecutiveReadingDays: db.consecutiveReadingDays,
    );
  }

  /// 空统计
  factory ReadingStats.empty() {
    return const ReadingStats(
      totalReadingTimeSeconds: 0,
      totalCharactersRead: 0,
      booksReadCount: 0,
      booksCompletedCount: 0,
    );
  }
}

/// 每日阅读记录领域模型
library;

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr_reader/core/database/database.dart';

part 'daily_reading_record.freezed.dart';

/// 每日阅读记录领域模型
@freezed
abstract class DailyReadingRecord with _$DailyReadingRecord {
  const factory DailyReadingRecord({
    /// 日期（YYYY-MM-DD 格式）
    required String date,

    /// 阅读时长（秒）
    @Default(0) int readingTimeSeconds,

    /// 阅读字数
    @Default(0) int charactersRead,

    /// 阅读章节数
    @Default(0) int chaptersRead,

    /// 阅读页数
    @Default(0) int pagesRead,
  }) = _DailyReadingRecord;

  /// 从数据库模型转换
  factory DailyReadingRecord.fromDb(DbDailyReadingRecord db) {
    return DailyReadingRecord(
      date: db.date,
      readingTimeSeconds: db.readingTimeSeconds,
      charactersRead: db.charactersRead,
      chaptersRead: db.chaptersRead,
      pagesRead: db.pagesRead,
    );
  }

  /// 空记录
  factory DailyReadingRecord.empty() {
    return const DailyReadingRecord(
      date: '',
      readingTimeSeconds: 0,
      charactersRead: 0,
      chaptersRead: 0,
      pagesRead: 0,
    );
  }
}

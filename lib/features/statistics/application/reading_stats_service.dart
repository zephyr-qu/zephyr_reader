/// 阅读统计服务
///
/// 负责采集、存储和查询阅读统计数据
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/src/rust/api.dart';

import '../../../src/rust/ffi/types.dart';

/// 每日阅读记录
class DailyReadingRecord {
  final DateTime date;
  final int readingTimeSeconds;
  final int charactersRead;
  final int chaptersRead;
  final int pagesRead;
  final int booksRead;

  DailyReadingRecord({
    required this.date,
    required this.readingTimeSeconds,
    required this.charactersRead,
    required this.chaptersRead,
    required this.pagesRead,
    this.booksRead = 0,
  });

  /// Rust 结构转换
  factory DailyReadingRecord.fromRust(RustDailyReadingRecord rust) {
    return DailyReadingRecord(
      date: DateTime.parse(rust.date),
      readingTimeSeconds: rust.readingTimeSeconds.toInt(),
      charactersRead: rust.charactersRead.toInt(),
      chaptersRead: rust.chaptersRead,
      pagesRead: rust.pagesRead,
    );
  }

  /// 转换JSON
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'readingTimeSeconds': readingTimeSeconds,
      'charactersRead': charactersRead,
      'chaptersRead': chaptersRead,
      'pagesRead': pagesRead,
      'booksRead': booksRead,
    };
  }

  /// JSON 创建
  factory DailyReadingRecord.fromJson(Map<String, dynamic> json) {
    return DailyReadingRecord(
      date: DateTime.parse(json['date'] as String),
      readingTimeSeconds: json['readingTimeSeconds'] as int? ?? 0,
      charactersRead: json['charactersRead'] as int? ?? 0,
      chaptersRead: json['chaptersRead'] as int? ?? 0,
      pagesRead: json['pagesRead'] as int? ?? 0,
      booksRead: json['booksRead'] as int? ?? 0,
    );
  }
}

/// 阅读会话记录
class ReadingSession {
  final String sessionId;
  final int bookId;
  final int chapterId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final int charactersRead;

  ReadingSession({
    required this.sessionId,
    required this.bookId,
    required this.chapterId,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.charactersRead,
  });

  /// 转换JSON
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'bookId': bookId,
      'chapterId': chapterId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationSeconds': durationSeconds,
      'charactersRead': charactersRead,
    };
  }

  /// JSON 创建
  factory ReadingSession.fromJson(Map<String, dynamic> json) {
    return ReadingSession(
      sessionId: json['sessionId'] as String,
      bookId: json['bookId'] as int,
      chapterId: json['chapterId'] as int,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      durationSeconds: json['durationSeconds'] as int,
      charactersRead: json['charactersRead'] as int,
    );
  }
}

/// 阅读统计数据
class ReadingStatistics {
  /// 总阅读时长（秒）
  final int totalReadingTimeSeconds;

  /// 总阅读字
  final int totalCharactersRead;

  /// 阅读书籍数量
  final int booksReadCount;

  /// 完成阅读书籍数量
  final int booksCompletedCount;

  /// 连续阅读天数
  final int consecutiveReadingDays;

  /// 今日阅读时长（秒
  final int todayReadingTimeSeconds;

  /// 今日阅读字数
  final int todayCharactersRead;

  /// 平均阅读速度（字/分钟
  final double averageReadingSpeed;

  ReadingStatistics({
    required this.totalReadingTimeSeconds,
    required this.totalCharactersRead,
    required this.booksReadCount,
    required this.booksCompletedCount,
    required this.consecutiveReadingDays,
    required this.todayReadingTimeSeconds,
    required this.todayCharactersRead,
    required this.averageReadingSpeed,
  });

  /// Rust 结构转换
  factory ReadingStatistics.fromRust(ReadingStats rust) {
    return ReadingStatistics(
      totalReadingTimeSeconds: rust.totalReadingTimeSeconds.toInt(),
      totalCharactersRead: rust.totalCharactersRead.toInt(),
      booksReadCount: rust.booksReadCount,
      booksCompletedCount: rust.booksCompletedCount,
      consecutiveReadingDays: rust.consecutiveReadingDays,
      todayReadingTimeSeconds: rust.todayReadingTimeSeconds.toInt(),
      todayCharactersRead: rust.todayCharactersRead.toInt(),
      averageReadingSpeed: rust.averageReadingSpeed,
    );
  }

  /// 空统计数
  factory ReadingStatistics.empty() {
    return ReadingStatistics(
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

/// 阅读统计服务
class ReadingStatsService {
  static ReadingStatsService? _instance;
  late final Directory _dataDir;
  ReadingSession? _currentSession;

  ReadingStatsService._() {
    _initDataDir();
  }

  static ReadingStatsService get instance {
    _instance ??= ReadingStatsService._();
    return _instance!;
  }

  Future<void> _initDataDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    _dataDir = Directory(p.join(appDir.path, 'data', 'stats'));
    if (!await _dataDir.exists()) {
      await _dataDir.create(recursive: true);
    }
  }

  /// 开始阅读会
  Future<void> startReadingSession(int bookId, int chapterId) async {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentSession = ReadingSession(
      sessionId: sessionId,
      bookId: bookId,
      chapterId: chapterId,
      startTime: DateTime.now(),
      endTime: DateTime.now(),
      durationSeconds: 0,
      charactersRead: 0,
    );

    debugPrint('开始阅读会话：$sessionId, book=$bookId, chapter=$chapterId');
  }

  /// 更新阅读会话
  Future<void> updateReadingSession(int charactersRead) async {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.copyWith(
      endTime: DateTime.now(),
      durationSeconds: DateTime.now()
          .difference(_currentSession!.startTime)
          .inSeconds,
      charactersRead: charactersRead,
    );

    // 保存到会话日
    await _saveSessionLog(_currentSession!);

    // 更新每日记录
    await _updateDailyRecord(_currentSession!);
  }

  /// 结束阅读会话
  Future<void> endReadingSession() async {
    if (_currentSession == null) return;

    debugPrint('结束阅读会话{_currentSession!.sessionId}');
    _currentSession = null;
  }

  /// 保存会话日志
  Future<void> _saveSessionLog(ReadingSession session) async {
    final logFile = File(p.join(_dataDir.path, 'session_log.json'));

    List<ReadingSession> sessions = [];
    if (await logFile.exists()) {
      final content = await logFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      sessions = jsonList.map((j) => ReadingSession.fromJson(j)).toList();
    }

    // 添加新会话，保留最1000
    sessions.add(session);
    if (sessions.length > 1000) {
      sessions = sessions.sublist(sessions.length - 1000);
    }

    await logFile.writeAsString(
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
  }

  /// 更新每日记录
  Future<void> _updateDailyRecord(ReadingSession session) async {
    final today = DateTime.now();

    final recordFile = File(p.join(_dataDir.path, 'daily_records.json'));

    List<DailyReadingRecord> records = [];
    if (await recordFile.exists()) {
      final content = await recordFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      records = jsonList.map((j) => DailyReadingRecord.fromJson(j)).toList();
    }

    // 查找今日记录
    final todayIndex = records.indexWhere(
      (r) =>
          r.date.year == today.year &&
          r.date.month == today.month &&
          r.date.day == today.day,
    );

    if (todayIndex >= 0) {
      // 更新今日记录
      records[todayIndex] = DailyReadingRecord(
        date: today,
        readingTimeSeconds:
            records[todayIndex].readingTimeSeconds + session.durationSeconds,
        charactersRead:
            records[todayIndex].charactersRead + session.charactersRead,
        chaptersRead: records[todayIndex].chaptersRead + 1,
        pagesRead: records[todayIndex].pagesRead,
        booksRead: records[todayIndex].booksRead,
      );
    } else {
      // 添加新记
      records.add(
        DailyReadingRecord(
          date: today,
          readingTimeSeconds: session.durationSeconds,
          charactersRead: session.charactersRead,
          chaptersRead: 1,
          pagesRead: 0,
          booksRead: 1,
        ),
      );
    }

    // 保留最365 天记
    if (records.length > 365) {
      records = records.sublist(records.length - 365);
    }

    await recordFile.writeAsString(
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }

  /// 获取统计数据
  Future<ReadingStatistics> getStatistics() async {
    try {
      // 使用 Rust 引擎获取统计数据
      final rustStats = getReadingStats();
      return ReadingStatistics.fromRust(rustStats);
    } catch (e) {
      debugPrint('获取统计数据失败e');
      return ReadingStatistics.empty();
    }
  }

  /// 获取每日阅读记录
  Future<List<DailyReadingRecord>> getDailyRecords({int days = 30}) async {
    try {
      final recordFile = File(p.join(_dataDir.path, 'daily_records.json'));
      if (!await recordFile.exists()) {
        return [];
      }

      final content = await recordFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      final records = jsonList
          .map((j) => DailyReadingRecord.fromJson(j))
          .toList();

      // 返回最N 天记
      return records.reversed.take(days).toList();
    } catch (e) {
      debugPrint('获取每日记录失败e');
      return [];
    }
  }

  /// 获取阅读会话历史
  Future<List<ReadingSession>> getSessionHistory({int limit = 100}) async {
    try {
      final logFile = File(p.join(_dataDir.path, 'session_log.json'));
      if (!await logFile.exists()) {
        return [];
      }

      final content = await logFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      final sessions = jsonList.map((j) => ReadingSession.fromJson(j)).toList();

      // 返回最N 条记
      return sessions.reversed.take(limit).toList();
    } catch (e) {
      debugPrint('获取会话历史失败e');
      return [];
    }
  }

  /// 清除所有统计数
  Future<void> clearAllStats() async {
    if (await _dataDir.exists()) {
      await _dataDir.delete(recursive: true);
      await _dataDir.create(recursive: true);
    }
    debugPrint('所有统计数据已清除');
  }
}

/// Rust 每日阅读记录（用FFI
class RustDailyReadingRecord {
  final String date;
  final int readingTimeSeconds;
  final int charactersRead;
  final int chaptersRead;
  final int pagesRead;
  final int booksRead;

  RustDailyReadingRecord({
    required this.date,
    required this.readingTimeSeconds,
    required this.charactersRead,
    required this.chaptersRead,
    required this.pagesRead,
    required this.booksRead,
  });
}

/// 扩展 ReadingSession 以支copyWith
extension ReadingSessionExtension on ReadingSession {
  ReadingSession copyWith({
    String? sessionId,
    int? bookId,
    int? chapterId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    int? charactersRead,
  }) {
    return ReadingSession(
      sessionId: sessionId ?? this.sessionId,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      charactersRead: charactersRead ?? this.charactersRead,
    );
  }
}

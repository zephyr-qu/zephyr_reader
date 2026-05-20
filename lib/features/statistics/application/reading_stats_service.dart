/// 阅读统计服务
///
/// 负责采集、存储和查询阅读统计数据
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 阅读统计服务
@LazySingleton()
class ReadingStatsService {
  final RustStorageService _storage;

  ReadingStatsService(this._storage);

  String? _currentSessionId;
  String? _currentBookId;
  int? _currentChapterIndex;
  DateTime? _sessionStartTime;
  int? _sessionStartCharOffset;
  int? _currentCharOffset;

  /// 开始阅读会话
  String startReadingSession(
    String bookId,
    int chapterIndex,
    int startCharOffset,
  ) {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

    _currentSessionId = sessionId;
    _currentBookId = bookId;
    _currentChapterIndex = chapterIndex;
    _sessionStartTime = DateTime.now();
    _sessionStartCharOffset = startCharOffset;
    _currentCharOffset = startCharOffset;

    Logging.debug(
      '开始阅读会话：$sessionId, book=$bookId, chapter=$chapterIndex, offset=$startCharOffset',
    );
    return sessionId;
  }

  /// 更新阅读会话进度
  void updateProgress(int currentCharOffset) {
    if (_currentSessionId == null || _sessionStartTime == null) return;
    _currentCharOffset = currentCharOffset;
  }

  /// 结束阅读会话
  Future<void> endReadingSession(int currentCharOffset) async {
    if (_currentBookId == null ||
        _currentChapterIndex == null ||
        _sessionStartTime == null ||
        _sessionStartCharOffset == null) {
      return;
    }

    final effectiveCurrentOffset = _currentCharOffset ?? currentCharOffset;
    final now = DateTime.now();
    final duration = now.difference(_sessionStartTime!).inSeconds;
    final charactersRead = effectiveCurrentOffset - _sessionStartCharOffset!;
    final charsRead = charactersRead > 0 ? charactersRead : 0;

    if (duration < 2 && charsRead <= 0) {
      _clearSession();
      return;
    }

    Logging.debug('结束阅读会话：$_currentSessionId, 时长=$duration秒, 阅读字符=$charsRead');

    try {
      await _storage.recordReadingSession(
        ReadingSession(
          id: 'session_${now.millisecondsSinceEpoch}',
          bookId: _currentBookId!,
          chapterIndex: _currentChapterIndex!,
          startCharOffset: _sessionStartCharOffset!,
          endCharOffset: effectiveCurrentOffset,
          startedAt: _sessionStartTime!,
          endedAt: now,
          durationSeconds: duration,
        ),
      );
    } catch (e) {
      Logging.debug('保存阅读会话失败: $e');
    }

    _clearSession();
  }

  /// 获取当前会话 ID
  String? get currentSessionId => _currentSessionId;

  /// 是否有活跃的阅读会话
  bool get isSessionActive => _currentSessionId != null;

  /// 获取每日阅读统计
  Future<List<ReadingStats>> getDailyRecords({int days = 7}) async {
    try {
      final now = DateTime.now();
      final start = now.subtract(Duration(days: days));

      return await _storage.getReadingStatsRange(
        startDate: _formatDate(start),
        endDate: _formatDate(now),
      );
    } catch (e) {
      Logging.debug('获取每日统计异常: $e');
      return [];
    }
  }

  /// 获取今日阅读数据
  Future<(int seconds, int characters)> getTodayReadingData() async {
    try {
      final now = DateTime.now();
      final today = _formatDate(now);
      final records = await _storage.getReadingStatsRange(
        startDate: today,
        endDate: today,
      );
      int totalSeconds = 0;
      int totalChars = 0;
      for (final r in records) {
        totalSeconds += r.readingTimeSeconds;
        totalChars += r.charactersRead;
      }
      return (totalSeconds, totalChars);
    } catch (e) {
      Logging.debug('获取今日数据异常: $e');
      return (0, 0);
    }
  }

  /// 获取连续阅读天数
  Future<int> getConsecutiveReadingDays() async {
    try {
      final stats = await _storage.getGlobalReadingStats();
      return stats.consecutiveReadingDays;
    } catch (e) {
      Logging.debug('获取连续阅读天数异常: $e');
      return 0;
    }
  }

  /// 获取阅读速度（字符/分钟）
  Future<double> getReadingSpeed() async {
    try {
      final stats = await _storage.getGlobalReadingStats();
      final minutes = stats.totalReadingTimeSeconds / 60;
      if (minutes <= 0) return 0;
      return stats.totalCharactersRead / minutes;
    } catch (e) {
      Logging.debug('获取阅读速度异常: $e');
      return 0;
    }
  }

  /// 获取全局统计
  Future<GlobalStats?> getGlobalStats() async {
    try {
      return await _storage.getGlobalReadingStats();
    } catch (e) {
      Logging.debug('获取全局统计异常: $e');
      return null;
    }
  }

  /// 获取阅读统计数据
  Future<List<ReadingStats>> getReadingStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      return await _storage.getReadingStatsRange(
        startDate: _formatDate(start),
        endDate: _formatDate(end),
      );
    } catch (e) {
      Logging.debug('获取阅读统计异常: $e');
      return [];
    }
  }

  /// 获取阅读会话历史
  Future<List<ReadingSession>> getSessionHistory({
    required String bookId,
    int limit = 100,
  }) async {
    try {
      return _storage.getReadingSessions(bookId, limit: limit);
    } catch (e) {
      Logging.debug('获取会话历史异常: $e');
      return [];
    }
  }

  /// 清除当前会话（不保存）
  void discardCurrentSession() {
    _clearSession();
  }

  void _clearSession() {
    _currentSessionId = null;
    _currentBookId = null;
    _currentChapterIndex = null;
    _sessionStartTime = null;
    _sessionStartCharOffset = null;
    _currentCharOffset = null;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

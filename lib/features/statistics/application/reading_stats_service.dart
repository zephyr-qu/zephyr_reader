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

    Logging.debug(
      '开始阅读会话：$sessionId, book=$bookId, chapter=$chapterIndex, offset=$startCharOffset',
    );
    return sessionId;
  }

  /// 更新阅读会话进度
  void updateProgress(int currentCharOffset) {
    if (_currentSessionId == null || _sessionStartTime == null) return;
  }

  /// 结束阅读会话
  Future<void> endReadingSession(int currentCharOffset) async {
    if (_currentBookId == null ||
        _currentChapterIndex == null ||
        _sessionStartTime == null ||
        _sessionStartCharOffset == null) {
      return;
    }

    final now = DateTime.now();
    final duration = now.difference(_sessionStartTime!).inSeconds;
    final charactersRead = currentCharOffset - _sessionStartCharOffset!;
    final charsRead = charactersRead > 0 ? charactersRead : 0;

    Logging.debug('结束阅读会话：$_currentSessionId, 时长=$duration秒, 阅读字符=$charsRead');

    try {
      await _storage.recordReadingSession(
        bookId: _currentBookId!,
        chapterIndex: _currentChapterIndex!,
        startOffset: _sessionStartCharOffset!,
        endOffset: currentCharOffset,
        durationSeconds: duration,
        charactersRead: charsRead,
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
  Future<List<DbDailyReadingStats>> getDailyRecords({int days = 7}) async {
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

  /// 获取全局统计
  Future<DbGlobalStats?> getGlobalStats() async {
    try {
      return  _storage.getGlobalReadingStats();
    } catch (e) {
      Logging.debug('获取全局统计异常: $e');
      return null;
    }
  }

  /// 获取阅读统计数据
  Future<List<DbDailyReadingStats>> getReadingStats({
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
  Future<List<DbReadingSession>> getSessionHistory({
    required String bookId,
    int limit = 100,
  }) async {
    try {
      return _storage.getReadingSessions('book_$bookId', limit: limit);
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
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

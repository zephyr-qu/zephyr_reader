/// 阅读统计服务
///
/// 负责采集、存储和查询阅读统计数据
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/storage.dart' as rust_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

/// 解包 Rust ApiResult
T _unwrap<T>(dynamic result) {
  final value = (result as dynamic).value;
  if (value == null) throw Exception('Rust API returned null');
  return value as T;
}

/// 阅读统计服务
@injectable
class ReadingStatsService {
  static final ReadingStatsService _instance = ReadingStatsService._internal();
  
  factory ReadingStatsService() => _instance;
  
  ReadingStatsService._internal();
  
  static ReadingStatsService get instance => _instance;
  
  String? _currentSessionId;
  String? _currentBookId;
  int? _currentChapterIndex;
  DateTime? _sessionStartTime;
  int? _sessionStartCharOffset;

  /// 开始阅读会话
  ///
  /// 返回会话 ID，用于后续跟踪
  String startReadingSession(String bookId, int chapterIndex, int startCharOffset) {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

    _currentSessionId = sessionId;
    _currentBookId = bookId;
    _currentChapterIndex = chapterIndex;
    _sessionStartTime = DateTime.now();
    _sessionStartCharOffset = startCharOffset;

    Logging.debug('开始阅读会话：$sessionId, book=$bookId, chapter=$chapterIndex, offset=$startCharOffset');
    return sessionId;
  }

  /// 更新阅读会话进度
  /// 
  /// 注意：此方法仅更新内部状态，不会写入数据库。
  /// 数据在 [endReadingSession] 时统一保存。
  void updateProgress(int currentCharOffset) {
    if (_currentSessionId == null || _sessionStartTime == null) return;
    // 仅更新内部状态，不触发数据库写入
  }

  /// 结束阅读会话
  Future<void> endReadingSession(int currentCharOffset) async {
    if (_currentBookId == null || _currentChapterIndex == null ||
        _sessionStartTime == null || _sessionStartCharOffset == null) {
      return;
    }

    final now = DateTime.now();
    final duration = now.difference(_sessionStartTime!).inSeconds;
    final charactersRead = currentCharOffset - _sessionStartCharOffset!;
    final charsRead = charactersRead > 0 ? charactersRead : 0;

    Logging.debug('结束阅读会话：$_currentSessionId, 时长=$duration秒, 阅读字符=$charsRead');

    try {
      await rust_api.recordReadingSession(
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

  /// 获取阅读统计数据
  Future<List<DbDailyReadingStats>> getDailyRecords({int days = 7}) async {
    try {
      final now = DateTime.now();
      final start = now.subtract(Duration(days: days));

      final result = await rust_api.getReadingStatsRange(
        startDate: _formatDate(start),
        endDate: _formatDate(now),
      );

      return _unwrap<List<DbDailyReadingStats>>(result);
    } catch (e) {
      Logging.debug('获取每日统计异常: $e');
      return [];
    }
  }

  /// 获取全局统计
  Future<DbGlobalStats?> getGlobalStats() async {
    try {
      final result = await rust_api.getGlobalReadingStats();
      return _unwrap<DbGlobalStats?>(result);
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
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final result = await rust_api.getReadingStatsRange(
        startDate: _formatDate(start),
        endDate: _formatDate(end),
      );

      return _unwrap<List<DbDailyReadingStats>>(result);
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
      final result = await rust_api.getReadingSessions(
        bookId: bookId,
        limit: BigInt.from(limit),
      );

      return _unwrap<List<DbReadingSession>>(result);
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

  /// 格式化日期为 YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

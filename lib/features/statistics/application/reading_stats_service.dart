import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/date_formatters.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/session.dart' as session_api;
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as stats_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 阅读统计 ViewModel
///
/// - 会话状态通过 Signals 暴露，UI 可响应式绑定
/// - 查询方法保持纯异步，由调用方（UI / 其他 VM）按需触发
@LazySingleton()
class ReadingStatsViewModel {
  // ==================== 响应式会话状态 ====================

  /// 当前活跃会话 ID，null 表示无活跃会话
  final currentSessionId = signal<String?>(null);

  /// 是否有活跃的阅读会话（派生信号，零额外状态）
  late final ReadonlySignal<bool> isSessionActive = computed(
    () => currentSessionId.value != null,
  );

  // ==================== Dashboard 状态 ====================

  /// 近 7 天阅读记录
  final dailyRecords = signal<List<ReadingStats>>([]);

  /// 全局阅读统计
  final globalStats = signal<GlobalStats?>(null);

  /// Dashboard 加载中
  final dashboardLoading = signal<bool>(false);

  /// Dashboard 错误信息
  final dashboardError = signal<String?>(null);

  /// 每日阅读分钟数（图表数据，派生自 dailyRecords）
  late final dailyMinutes = computed(
    () => dailyRecords.value
        .map((r) => r.readingTimeSeconds.toInt() / 60.0)
        .toList(),
  );

  /// 加载 Dashboard 数据
  Future<void> loadDashboard() async {
    dashboardLoading.value = true;
    dashboardError.value = null;
    try {
      final results = await Future.wait([
        stats_api.getReadingStatsByDaysWithFill(days: 7),
        stats_api.getGlobalReadingStats(),
      ]);
      dailyRecords.value = results[0] as List<ReadingStats>;
      globalStats.value = results[1] as GlobalStats?;
    } catch (e) {
      dashboardError.value = e.toString();
    } finally {
      dashboardLoading.value = false;
    }
  }

  // ==================== 内部会话上下文（不暴露给 UI） ====================

  String? _currentBookId;
  int? _currentChapterIndex;
  DateTime? _sessionStartTime;
  int? _sessionStartCharOffset;
  int? _currentCharOffset;

  // ==================== 会话生命周期 ====================

  /// 开始阅读会话，返回会话 ID
  String startReadingSession(
    String bookId,
    int chapterIndex,
    int startCharOffset,
  ) {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

    _currentBookId = bookId;
    _currentChapterIndex = chapterIndex;
    _sessionStartTime = DateTime.now();
    _sessionStartCharOffset = startCharOffset;
    _currentCharOffset = startCharOffset;

    // ✅ 最后更新信号，触发 UI 响应
    currentSessionId.value = sessionId;

    Logging.debug(
      '开始阅读会话：$sessionId, book=$bookId, chapter=$chapterIndex, offset=$startCharOffset',
    );
    return sessionId;
  }

  /// 更新阅读进度（高频调用，不触发信号更新）
  void updateProgress(int currentCharOffset) {
    if (currentSessionId.value == null || _sessionStartTime == null) return;
    _currentCharOffset = currentCharOffset;
  }

  /// 结束阅读会话并持久化
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
    final charsRead = (effectiveCurrentOffset - _sessionStartCharOffset!).clamp(
      0,
      999999999,
    );

    // 过短或无进度的会话直接丢弃
    if (duration < 2 && charsRead <= 0) {
      _clearSession();
      return;
    }

    Logging.debug(
      '结束阅读会话：${currentSessionId.value}, 时长=${duration}s, 字符=$charsRead',
    );

    try {
      final startedAt = _sessionStartTime!.millisecondsSinceEpoch ~/ 1000;
      await session_api.createSession(
        bookId: _currentBookId!,
        chapterIndex: _currentChapterIndex!,
        startCharOffset: _sessionStartCharOffset!,
        endCharOffset: effectiveCurrentOffset,
        startedAt: startedAt,
      );
    } catch (e) {
      Logging.error('保存阅读会话失败: $e');
    }

    _clearSession();
  }

  /// 放弃当前会话（不保存）
  void discardCurrentSession() => _clearSession();

  void _clearSession() {
    _currentBookId = null;
    _currentChapterIndex = null;
    _sessionStartTime = null;
    _sessionStartCharOffset = null;
    _currentCharOffset = null;
    // ✅ 信号置空，UI 自动响应
    currentSessionId.value = null;
  }

  // ==================== 查询方法（纯异步，无状态） ====================

  /// 获取每日阅读统计
  Future<List<ReadingStats>> getDailyRecords({int days = 7}) async {
    try {
      final now = DateTime.now();
      final start = now.subtract(Duration(days: days));
      return await stats_api.getReadingStatsByRange(
        startDate: formatDateYYYYMMDD(start),
        endDate: formatDateYYYYMMDD(now),
      );
    } catch (e) {
      Logging.error('获取每日统计异常: $e');
      return [];
    }
  }

  /// 获取今日阅读数据 (秒数, 字符数)
  Future<(int seconds, int characters)> getTodayReadingData() async {
    try {
      final today = formatDateYYYYMMDD(DateTime.now());
      final records = await stats_api.getReadingStatsByRange(
        startDate: today,
        endDate: today,
      );
      var totalSeconds = 0;
      var totalChars = 0;
      for (final r in records) {
        totalSeconds += r.readingTimeSeconds.toInt();
        totalChars += r.charactersRead.toInt();
      }
      return (totalSeconds, totalChars);
    } catch (e) {
      Logging.error('获取今日数据异常: $e');
      return (0, 0);
    }
  }

  /// 获取连续阅读天数
  Future<int> getConsecutiveReadingDays() async {
    try {
      final stats = await stats_api.getGlobalReadingStats();
      return stats.consecutiveReadingDays;
    } catch (e) {
      Logging.error('获取连续阅读天数异常: $e');
      return 0;
    }
  }

  /// 获取阅读速度（字符/分钟）
  Future<double> getReadingSpeed() async {
    try {
      final stats = await stats_api.getGlobalReadingStats();
      final minutes = stats.totalReadingTimeSeconds.toInt() / 60.0;
      if (minutes <= 0) return 0;
      return stats.totalCharactersRead.toInt() / minutes;
    } catch (e) {
      Logging.error('获取阅读速度异常: $e');
      return 0;
    }
  }

  /// 获取全局统计
  Future<GlobalStats?> getGlobalStats() async {
    try {
      return await stats_api.getGlobalReadingStats();
    } catch (e) {
      Logging.error('获取全局统计异常: $e');
      return null;
    }
  }

  /// 获取指定书籍的会话历史
  Future<List<ReadingSession>> getSessionHistory({
    required String bookId,
    int limit = 100,
  }) async {
    try {
      return await session_api.listSessionsByBook(
        bookId: bookId,
        limit: BigInt.from(limit),
      );
    } catch (e) {
      Logging.error('获取会话历史异常: $e');
      return [];
    }
  }

  /// 释放信号资源（Injectable @disposeMethod）
  void dispose() {
    currentSessionId.dispose();
  }
}

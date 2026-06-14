import 'dart:async';

import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/api/data/session.dart' as session_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

import 'chapter_view_model.dart';

/// 阅读会话管理器
///
/// 管理阅读计时、进度保存和自动保存。
/// 依赖 ChapterManager 读取书籍/章节状态。
class ReadingSessionManager {
  final ChapterViewModel _chapterManager;

  ReadingSessionManager(this._chapterManager);

  // ==================== 信号 ====================

  /// 阅读时长（秒）
  final _readingDuration = signal<int>(0);

  /// 是否正在阅读（计时）
  final _isReading = signal<bool>(false);

  /// 阅读时长（秒，只读）
  Signal<int> get readingDuration => _readingDuration;

  /// 是否正在阅读（只读）
  Signal<bool> get isReading => _isReading;

  // ==================== 定时器 ====================

  Timer? _readingTimer;
  Timer? _saveTimer;

  /// 进度保存防抖（5 秒内不重复保存）
  DateTime? _lastSaveTime;

  // ==================== 方法 ====================
  /// 本次阅读会话的起始字符偏移（用于创建 session）
  int _sessionStartOffset = 0;

  /// 本次阅读会话的开始时间
  DateTime _sessionStartTime = DateTime.now();

  /// 加载上次的阅读时长（从进度中恢复）
  void restoreReadingDuration(int seconds) {
    _readingDuration.value = seconds;
  }

  /// 开始阅读计时
  void startReading() {
    if (_isReading.value) return;
    _isReading.value = true;

    _sessionStartOffset = _chapterManager.currentCharOffset.value;
    _sessionStartTime = DateTime.now();

    _readingTimer?.cancel();
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _readingDuration.value++;
    });
  }

  /// 停止阅读计时并保存进度，同时记录本次阅读会话。
  Future<void> stopReading() async {
    if (!_isReading.value) return;
    _readingTimer?.cancel();

    // 先保存进度（saveProgress 依赖 isReading=true 的 guard）
    await saveProgress();

    // 再记录会话并标记结束
    _isReading.value = false;
    try {
      await session_api.createSession(
        bookId: _chapterManager.bookId.value,
        chapterIndex: _chapterManager.chapterIndex.value,
        startCharOffset: _sessionStartOffset,
        endCharOffset: _chapterManager.currentCharOffset.value,
        startedAt: _sessionStartTime.millisecondsSinceEpoch ~/ 1000,
      );
    } catch (e) {
      Logging.warning('记录阅读会话失败: $e');
    }
  }

  /// 启动定时保存（每 30 秒）
  void startAutoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isReading.value) return;
      saveProgress();
    });
  }

  /// 保存阅读进度
  Future<void> saveProgress() async {
    if (!_isReading.value) return;
    final now = DateTime.now();
    if (_lastSaveTime != null && now.difference(_lastSaveTime!).inSeconds < 5) {
      return;
    }
    _lastSaveTime = now;
    try {
      final cm = _chapterManager;
      final totalPages = cm.totalPages.value;
      final pct = totalPages > 0
          ? ((cm.pageIndex.value + 1) / totalPages).clamp(0.0, 1.0)
          : 0.0;
      await progress_api.upsertProgress(
        progress: ReadingProgress(
          bookId: cm.bookId.value,
          chapterIndex: cm.chapterIndex.value,
          chunkIndex: 0,
          charOffset: cm.currentCharOffset.value,
          pageIndex: cm.pageIndex.value,
          totalPages: totalPages,
          progress: pct,
          readingTimeSeconds: _readingDuration.value,
          lastReadAt: now,
          isCompleted: pct >= 1.0,
        ),
      );
    } catch (e) {
      Logging.error('保存阅读进度失败', exception: e);
    }
  }

  /// 重置
  void reset() {
    _readingTimer?.cancel();
    _saveTimer?.cancel();
    _readingDuration.value = 0;
    _isReading.value = false;
  }

  Future<void> dispose() async {
    _readingTimer?.cancel();
    _saveTimer?.cancel();
    if (!_isReading.value) return;

    // 记录本次阅读会话
    try {
      await session_api.createSession(
        bookId: _chapterManager.bookId.value,
        chapterIndex: _chapterManager.chapterIndex.value,
        startCharOffset: _sessionStartOffset,
        endCharOffset: _chapterManager.currentCharOffset.value,
        startedAt: _sessionStartTime.millisecondsSinceEpoch ~/ 1000,
      );
    } catch (e) {
      Logging.warning('记录阅读会话失败: $e');
    }

    await saveProgress();
    _isReading.value = false;
  }
}

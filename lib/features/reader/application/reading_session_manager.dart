import 'dart:async';

import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

import 'chapter_manager.dart';

/// 阅读会话管理器
///
/// 管理阅读计时、进度保存和自动保存。
/// 依赖 ChapterManager 读取书籍/章节状态。
class ReadingSessionManager {
  final ChapterManager _chapterManager;

  ReadingSessionManager(this._chapterManager);

  // ==================== 信号 ====================

  /// 阅读时长（秒）
  final readingDuration = signal<int>(0);

  /// 是否正在阅读（计时）
  final isReading = signal<bool>(false);

  // ==================== 定时器 ====================

  Timer? _readingTimer;
  Timer? _saveTimer;

  /// 进度保存防抖（5 秒内不重复保存）
  DateTime? _lastSaveTime;

  // ==================== 方法 ====================

  /// 加载上次的阅读时长（从进度中恢复）
  void restoreReadingDuration(int seconds) {
    readingDuration.value = seconds;
  }

  /// 开始阅读计时
  void startReading() {
    if (isReading.value) return;
    isReading.value = true;

    _readingTimer?.cancel();
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      readingDuration.value++;
    });
  }

  /// 停止阅读计时并保存进度
  Future<void> stopReading() async {
    if (!isReading.value) return;
    isReading.value = false;
    _readingTimer?.cancel();

    await saveProgress();
  }

  /// 启动定时保存（每 30 秒）
  void startAutoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!isReading.value) return;
      saveProgress();
    });
  }

  /// 保存阅读进度
  Future<void> saveProgress() async {
    if (!isReading.value) return;
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
          readingTimeSeconds: readingDuration.value,
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
    readingDuration.value = 0;
    isReading.value = false;
  }

  Future<void> dispose() async {
    _readingTimer?.cancel();
    _saveTimer?.cancel();
    if (isReading.value) {
      await saveProgress();
    }
  }
}

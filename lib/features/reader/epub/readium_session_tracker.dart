import 'dart:async';

import 'package:flutter_readium/flutter_readium.dart';

typedef SessionRecorder =
    Future<void> Function({
      required String bookId,
      required int chapterIndex,
      required int startedAt,
      required int durationSeconds,
    });

class ReadiumSessionTracker {
  ReadiumSessionTracker({
    required this.bookId,
    required this.recordSession,
    required this.chapterIndexForHref,
    required this.charOffsetFor,
    required this.isActive,
  });

  final String bookId;
  final SessionRecorder recordSession;
  final int Function(String href) chapterIndexForHref;
  final int Function(Locator locator) charOffsetFor;
  /// 会话是否活跃（视口就绪且未在关闭），track 时守卫。
  final bool Function() isActive;

  DateTime? _startedAt;
  int? _chapterIndex;
  int _lastOffset = 0;
  DateTime? _lastActivityAt;
  int _activeSeconds = 0;

  /// 相邻翻页间隔超过该值时视为离开阅读（发呆/切走），不计入活跃时长。
  static const Duration _activityWindow = Duration(seconds: 90);
  static const Duration _minRecordedDuration = Duration(seconds: 1);
  Future<void> _recordQueue = Future<void>.value();

  int? get currentChapterIndex => _chapterIndex;

  void reset() {
    _startedAt = null;
    _chapterIndex = null;
    _lastOffset = 0;
    _lastActivityAt = null;
    _activeSeconds = 0;
  }

  /// 逐位置累计活跃时长：上一次翻页到现在的时间差计入，
  /// 超过 [_activityWindow] 视为会话中断（该间隔整体不累计）。
  void _accumulateActiveTime(DateTime now) {
    final last = _lastActivityAt;
    if (last != null) {
      final gap = now.difference(last);
      if (gap <= _activityWindow) {
        _activeSeconds += gap.inSeconds;
      }
    }
    _lastActivityAt = now;
  }

  void track(Locator locator) {
    if (!isActive()) return;
    final chapterIndex = chapterIndexForHref(locator.href);
    final offset = charOffsetFor(locator);
    if (_startedAt == null || _chapterIndex == null) {
      _start(chapterIndex, offset);
    } else if (chapterIndex != _chapterIndex) {
      unawaited(finalize());
      _start(chapterIndex, offset);
    } else if (offset > _lastOffset) {
      _lastOffset = offset;
      _accumulateActiveTime(DateTime.now());
    }
  }

  Future<void> finalize() async {
    final startedAt = _startedAt;
    final chapterIndex = _chapterIndex;
    if (startedAt == null || chapterIndex == null) return;
    // 活跃时长 = 相邻翻页间隔累计（间隔 ≤ 活动窗口才计入）。
    // 收尾再评估最后一翻到 finalize 的间隔，随后各状态复位。
    _accumulateActiveTime(DateTime.now());
    final duration = _activeSeconds;
    _startedAt = null;
    _chapterIndex = null;
    _activeSeconds = 0;
    _lastActivityAt = null;
    final next = _recordQueue.then(
      (_) => _recordOne(
        chapterIndex: chapterIndex,
        startedAt: startedAt,
        durationSeconds: duration >= _minRecordedDuration.inSeconds ? duration : 0,
      ),
    );
    _recordQueue = next;
    await next;
  }

  Future<void> _recordOne({
    required int chapterIndex,
    required DateTime startedAt,
    required int durationSeconds,
  }) async {
    try {
      await recordSession(
        bookId: bookId,
        chapterIndex: chapterIndex,
        startedAt: startedAt.millisecondsSinceEpoch ~/ 1000,
        durationSeconds: durationSeconds,
      );
    } catch (_) {
      // Session recording is best-effort and must not interrupt reading.
    }
  }

  void _start(int chapterIndex, int offset) {
    _startedAt = DateTime.now();
    _chapterIndex = chapterIndex;
    _lastOffset = offset;
    _lastActivityAt = _startedAt;
    _activeSeconds = 0;
  }
}

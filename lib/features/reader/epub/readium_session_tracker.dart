import 'dart:async';

import 'package:flutter_readium/flutter_readium.dart';

typedef SessionRecorder =
    Future<void> Function({
      required String bookId,
      required int chapterIndex,
      required int startCharOffset,
      required int endCharOffset,
      required int startedAt,
    });

class ReadiumSessionTracker {
  ReadiumSessionTracker({
    required this.bookId,
    required this.recordSession,
    required this.chapterIndexForHref,
    required this.charOffsetFor,
    required this.isReady,
    required this.isClosing,
  });

  final String bookId;
  final SessionRecorder recordSession;
  final int Function(String href) chapterIndexForHref;
  final int Function(Locator locator) charOffsetFor;
  final bool Function() isReady;
  final bool Function() isClosing;

  DateTime? _startedAt;
  int? _chapterIndex;
  int _startOffset = 0;
  int _lastOffset = 0;
  Future<void> _recordQueue = Future<void>.value();

  int? get currentChapterIndex => _chapterIndex;

  void reset() {
    _startedAt = null;
    _chapterIndex = null;
    _startOffset = 0;
    _lastOffset = 0;
  }

  void track(Locator locator) {
    if (!isReady() || isClosing()) return;
    final chapterIndex = chapterIndexForHref(locator.href);
    final offset = charOffsetFor(locator);
    if (_startedAt == null || _chapterIndex == null) {
      _start(chapterIndex, offset);
    } else if (chapterIndex != _chapterIndex) {
      unawaited(finalize());
      _start(chapterIndex, offset);
    } else if (offset > _lastOffset) {
      _lastOffset = offset;
    }
  }

  Future<void> finalize() async {
    final startedAt = _startedAt;
    final chapterIndex = _chapterIndex;
    final startOffset = _startOffset;
    final endOffset = _lastOffset;
    if (startedAt == null || chapterIndex == null) return;
    _startedAt = null;
    _chapterIndex = null;
    final next = _recordQueue.then(
      (_) => _recordOne(
        chapterIndex: chapterIndex,
        startOffset: startOffset,
        endOffset: endOffset,
        startedAt: startedAt,
      ),
    );
    _recordQueue = next;
    await next;
  }

  Future<void> _recordOne({
    required int chapterIndex,
    required int startOffset,
    required int endOffset,
    required DateTime startedAt,
  }) async {
    try {
      await recordSession(
        bookId: bookId,
        chapterIndex: chapterIndex,
        startCharOffset: startOffset,
        endCharOffset: endOffset,
        startedAt: startedAt.millisecondsSinceEpoch ~/ 1000,
      );
    } catch (_) {
      // Session recording is best-effort and must not interrupt reading.
    }
  }

  void _start(int chapterIndex, int offset) {
    _startedAt = DateTime.now();
    _chapterIndex = chapterIndex;
    _startOffset = offset;
    _lastOffset = offset;
  }
}

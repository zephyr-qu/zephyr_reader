import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';

/// 滚动模式多章拼接的滑动窗口（最多 3 段：prev/current/next）。
///
/// 不负责文本加载（由外部调用 [appendNext] / [prependPrev] 喂数据），
/// 只管理段列表、段落索引映射、以及远距离段的 trim。
class ScrollDocumentComposer {
  /// 滑动窗口段，按章节升序排列。下标 0 对应最早（最小 chapterIndex）段。
  List<ScrollChapterSegment> _segments = [];

  /// 窗口中心章节 —— 用于进度/高亮定位。
  int _centerChapterIndex;

  ScrollDocumentComposer({required this._centerChapterIndex});

  /// 当前窗口段（防外部变异）。
  List<ScrollChapterSegment> get segments => List.unmodifiable(_segments);

  /// 窗口中心章节索引。
  int get centerChapterIndex => _centerChapterIndex;

  /// 各段段落总数。
  int get totalParagraphCount =>
      _segments.fold(0, (sum, s) => sum + s.paragraphCount);

  /// [centerChapterIndex] 对应段在 segments 中的下标，无对应段时返回 -1。
  int get centerSegmentIndex =>
      _segments.indexWhere((s) => s.chapterIndex == _centerChapterIndex);

  /// 全局段落索引 → (段下标, 段内段落索引)。
  ({int segIdx, int localIdx})? resolveGlobalIndex(int globalIndex) {
    var remaining = globalIndex;
    for (var i = 0; i < _segments.length; i++) {
      if (remaining < _segments[i].paragraphCount) {
        return (segIdx: i, localIdx: remaining);
      }
      remaining -= _segments[i].paragraphCount;
    }
    return null;
  }

  /// 在窗口末尾追加下一章。
  bool appendNext(ScrollChapterSegment segment) {
    if (_segments.isNotEmpty &&
        segment.chapterIndex <= _segments.last.chapterIndex) {
      return false;
    }
    _segments = [..._segments, segment];
    _trim();
    return true;
  }

  /// 在窗口开头插入上一章。
  bool prependPrev(ScrollChapterSegment segment) {
    if (_segments.isNotEmpty &&
        segment.chapterIndex >= _segments.first.chapterIndex) {
      return false;
    }
    _segments = [segment, ..._segments];
    _trim();
    return true;
  }

  /// 重置窗口到指定章节。
  void reset(ScrollChapterSegment segment) {
    _segments = [segment];
    _centerChapterIndex = segment.chapterIndex;
  }

  /// 移除距中心超过 1 章的段（即窗口外 cleanup），保持最多 3 段。
  void _trim() {
    final centerIdx = _segments
        .indexWhere((s) => s.chapterIndex == _centerChapterIndex);
    if (centerIdx < 0) return;

    final keepStart = (centerIdx - 1).clamp(0, _segments.length);
    // 最多保留 3 段：keepStart, keepStart+1, keepStart+2
    final keepEnd = (keepStart + 3).clamp(0, _segments.length);

    if (keepStart > 0 || keepEnd < _segments.length) {
      _segments = _segments.sublist(keepStart, keepEnd);
    }
  }

  /// 由外部通知中心章节已改变（用户滚过章界时调用）。
  void updateCenterChapter(int chapterIndex) {
    _centerChapterIndex = chapterIndex;
    _trim();
  }

  /// 计算 [scrollOffset] 处的 charOffset。
  ({int chapterIndex, int charOffset}) charOffsetAtOffset(
    double scrollOffset,
    double Function(int globalIndex) paragraphExtent,
  ) {
    if (_segments.isEmpty) {
      return (chapterIndex: _centerChapterIndex, charOffset: 0);
    }

    var remaining = scrollOffset;
    for (var gi = 0; gi < totalParagraphCount; gi++) {
      final ext = paragraphExtent(gi);
      if (remaining <= ext) {
        final resolved = resolveGlobalIndex(gi)!;
        final seg = _segments[resolved.segIdx];
        final metrics = seg.listMetrics;
        final localIdx = resolved.localIdx;
        if (localIdx < 0 || localIdx >= metrics.itemCount) {
          return (
            chapterIndex: seg.chapterIndex,
            charOffset: seg.totalCharLength,
          );
        }
        final ratio = ext <= 0 ? 0.0 : (remaining / ext).clamp(0.0, 1.0);
        final charLen = metrics.charLengthAt(localIdx);
        final charOffset = metrics.charOffsetAt(localIdx) +
            (charLen * ratio).round();
        return (chapterIndex: seg.chapterIndex, charOffset: charOffset);
      }
      remaining -= ext;
    }

    final lastSeg = _segments.last;
    return (
      chapterIndex: lastSeg.chapterIndex,
      charOffset: lastSeg.totalCharLength,
    );
  }

  /// 章节内容是否就绪。
  bool hasChapter(int chapterIndex) =>
      _segments.any((s) => s.chapterIndex == chapterIndex);
}

import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/features/reader/spike/spike_page.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

/// Spike 进度：charOffset ↔ pageIndex（ADR-001 半开区间语义）。
abstract final class SpikeProgress {
  /// 章级 [charOffset] 落在哪一页（与 [PaginationEngine.resolvePageIndexForOffset] 一致）。
  static int pageIndexAtCharOffset(List<SpikePage> pages, int charOffset) {
    if (pages.isEmpty) return 0;
    return PaginationEngine.resolvePageIndexForOffset(
      [
        for (final p in pages)
          PageDescriptor(
            pageIndex: p.pageIndex,
            startOffset: p.startOffset,
            endOffset: p.endOffset,
            firstParagraphIndex: 0,
            lastParagraphIndex: 0,
            isLastPage: p.isLastPage,
          ),
      ],
      charOffset,
    );
  }

  /// 翻页写回用的锚点：页内偏移（避免边界落在上一页）。
  ///
  /// 与 [ChapterNavigator.loadPage] 对齐：`end > start + 1` 时用 `start + 1`。
  static int charOffsetForPage(List<SpikePage> pages, int pageIndex) {
    if (pages.isEmpty) return 0;
    final i = pageIndex.clamp(0, pages.length - 1);
    final p = pages[i];
    final start = p.startOffset;
    final end = p.endOffset;
    return end > start + 1 ? start + 1 : start;
  }

  /// 重装箱后：旧 [charOffset] 是否仍落在解析出的页区间内（或章末夹紧）。
  static bool offsetStillOnResolvedPage({
    required List<SpikePage> pages,
    required int charOffset,
  }) {
    if (pages.isEmpty) return charOffset == 0;
    final maxOff = pages.last.endOffset;
    final clamped = charOffset.clamp(0, maxOff);
    final idx = pageIndexAtCharOffset(pages, clamped);
    final p = pages[idx];
    // 半开 [start, end)：末页允许 offset == end（夹紧到章末）
    if (clamped == maxOff && idx == pages.length - 1) return true;
    return clamped >= p.startOffset && clamped < p.endOffset;
  }
}

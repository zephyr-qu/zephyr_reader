import 'package:zephyr_reader/core/reader_engine/pagination/page_plan.dart';

/// 无状态分页工具方法。
class PaginationUtils {
  /// 首屏快速分页截止字符数（2000 字符）。
  static final BigInt firstScreenMaxChars = BigInt.from(2000);

  static int _resolvePageIndex<T>(
    List<T> pages,
    int charOffset, {
    required int Function(T) getStart,
    required int Function(T) getEnd,
  }) {
    if (pages.isEmpty) return 0;
    int lo = 0, hi = pages.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final page = pages[mid];
      if (charOffset < getStart(page)) {
        hi = mid - 1;
      } else if (charOffset >= getEnd(page)) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }
    return charOffset < getStart(pages[0]) ? 0 : pages.length - 1;
  }

  /// 二分查找字符偏移所在的页码（PagePlan 列表）。
  static int resolvePageIndexForPagePlan(
    List<PagePlan> pages,
    int charOffset,
  ) => _resolvePageIndex(
    pages,
    charOffset,
    getStart: (p) => p.startUtf16,
    getEnd: (p) => p.endUtf16,
  );

  /// 计算段落内最大字符偏移，用于 clamp 上限。
  static int chapterCharOffsetMax({
    required List<PagePlan>? pages,
    required String phase1PlainContent,
  }) {
    if (pages != null && pages.isNotEmpty) {
      return pages.last.endUtf16;
    }
    return phase1PlainContent.length;
  }
}

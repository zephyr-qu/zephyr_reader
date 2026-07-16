import 'package:zephyr_reader/core/reader_engine/pagination/packed_page.dart';

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

  /// 二分查找字符偏移所在的页码（PageInfo 列表）。

  /// 二分查找字符偏移所在的页码（PackedPage 列表）。
  static int resolvePageIndexForOffset(
    List<PackedPage> descriptors,
    int charOffset,
  ) => _resolvePageIndex(
    descriptors,
    charOffset,
    getStart: (d) => d.startOffset,
    getEnd: (d) => d.endOffset,
  );
}

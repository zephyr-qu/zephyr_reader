import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';
import 'package:zephyr_reader/features/reader/domain/model/page_info.dart';

/// 无状态分页引擎。
///
/// 封装 Rust 全量分页、部分分页和 Dart 估算分页算法。
/// 所有方法为纯计算或 FFI 调用，不持有任何可变状态。
class PaginationEngine {
  /// Rust 分页排版。
  ///
  /// 返回完整的 [PaginateResult]（含 isPartial 标记）。
  /// 调用方负责缓存描述符和预加载页面内容。
  Future<PaginateResult> paginateChapter({
    required String filePath,
    required int chapterIndex,
    required TypesetConfig config,
    BigInt? maxChars,
  }) async {
    return core_api.paginateChapter(
      filePath: filePath,
      chapterIndex: chapterIndex,
      config: config,
      maxChars: maxChars,
    );
  }

  /// 首屏快速分页截止字符数（2000 字符）。
  static final BigInt firstScreenMaxChars = BigInt.from(2000);

  /// Dart 估算分页（无需 TextPainter，毫秒级）。
  ///
  /// 基于字符宽度和行高近似计算每页容纳的字符数，
  /// 在段落边界处断页以避免截断。
  static List<PageInfo> paginateApproximate(
    String content, {
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
    required double padding,
  }) {
    final maxWidth = width - padding * 2;
    final availableHeight = height - padding * 2;
    final charsPerLine = (maxWidth / fontSize).floor().clamp(10, 200);
    final linesPerPage = (availableHeight / (fontSize * lineHeight))
        .floor()
        .clamp(1, 100);
    final charsPerPage = charsPerLine * linesPerPage;

    final pages = <PageInfo>[];
    var offset = 0;
    var pageIndex = 0;

    while (offset < content.length) {
      var end = offset + charsPerPage;
      if (end >= content.length) {
        end = content.length;
      } else {
        // 在段落边界处断开，避免断词
        final searchStart = (end - (charsPerLine ~/ 2)).clamp(
          0,
          content.length,
        );
        final newlinePos = content.lastIndexOf('\n', end);
        if (newlinePos > searchStart) {
          end = newlinePos + 1;
        } else {
          final paraBreak = content.lastIndexOf('\n\n', end);
          if (paraBreak > searchStart) {
            end = paraBreak + 2;
          }
        }
      }

      pages.add(
        PageInfo(
          pageIndex: pageIndex,
          content: content.substring(offset, end),
          startOffset: offset,
          endOffset: end,
        ),
      );
      offset = end;
      pageIndex++;
    }

    if (pages.isEmpty) {
      pages.add(
        PageInfo(
          pageIndex: 0,
          content: content,
          startOffset: 0,
          endOffset: content.length,
        ),
      );
    }
    return pages;
  }

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
  static int resolvePageIndexFromPageInfo(
    List<PageInfo> pages,
    int charOffset,
  ) => _resolvePageIndex(
    pages,
    charOffset,
    getStart: (p) => p.startOffset,
    getEnd: (p) => p.endOffset,
  );

  /// 二分查找字符偏移所在的页码（PageDescriptor 列表）。
  static int resolvePageIndexForOffset(
    List<PageDescriptor> descriptors,
    int charOffset,
  ) => _resolvePageIndex(
    descriptors,
    charOffset,
    getStart: (d) => d.startOffset,
    getEnd: (d) => d.endOffset,
  );
}

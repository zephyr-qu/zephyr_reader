import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';

/// 估算分页结果。
///
/// 用于无需 FFI 的快速分页场景（首屏渲染、预加载）。
class PageInfo {
  final int pageIndex;
  final String content;
  final int startOffset;
  final int endOffset;
  PageInfo({
    required this.pageIndex,
    required this.content,
    required this.startOffset,
    required this.endOffset,
  });
}

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
    final sw = Stopwatch()..start();
    final result = await core_api.paginateChapter(
      filePath: filePath,
      chapterIndex: chapterIndex,
      config: config,
      maxChars: maxChars,
    );
    final tRust = sw.elapsedMilliseconds;
    Logging.info(
      '[Timing] Rust paginateChapter: ${tRust}ms '
      '(maxChars=${maxChars ?? "full"}, isPartial=${result.isPartial}, pages=${result.descriptors.length})',
    );
    return result;
  }

  /// 部分分页截止字符数（50K 字符）。
  static final BigInt partialMaxChars = BigInt.from(50000);

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

  /// 二分查找字符偏移所在的页码（PageInfo 列表）。
  static int resolvePageIndexFromPageInfo(
    List<PageInfo> pages,
    int charOffset,
  ) {
    if (pages.isEmpty) return 0;
    int lo = 0, hi = pages.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final page = pages[mid];
      if (charOffset < page.startOffset) {
        hi = mid - 1;
      } else if (charOffset >= page.endOffset) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }
    return charOffset < pages[0].startOffset ? 0 : pages.length - 1;
  }

  /// 二分查找字符偏移所在的页码（PageDescriptor 列表）。
  static int resolvePageIndexForOffset(
    List<PageDescriptor> descriptors,
    int charOffset,
  ) {
    if (descriptors.isEmpty) return 0;
    int lo = 0, hi = descriptors.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final page = descriptors[mid];
      if (charOffset < page.startOffset) {
        hi = mid - 1;
      } else if (charOffset >= page.endOffset) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }
    return charOffset < descriptors[0].startOffset ? 0 : descriptors.length - 1;
  }
}

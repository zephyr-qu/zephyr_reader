import 'package:flutter/material.dart';
import 'package:zephyr_reader/features/reader/data/pagination_viewport_index.dart';
import 'package:zephyr_reader/features/reader/rendering/page_curl_widget.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

/// pageTurn 皮肤：物理页索引 ↔ 逻辑页码映射 + [PageCurlWidget] 动画。
///
/// 不读取 descriptors / Rust API；仅透传 [pageBuilder] 产出的 Widget。
/// staging 虚拟页由调用方在 [pageBuilder] 内处理。
class PageTurnShell extends StatelessWidget {
  const PageTurnShell({
    super.key,
    required this.logicalPageIndex,
    required this.logicalPageCount,
    required this.hasPreviousChapter,
    required this.hasNextStagingPage,
    required this.pageBuilder,
    required this.onLogicalPageChanged,
    this.onReachEnd,
    this.onReachStart,
    this.onPositionChanged,
    this.descriptors,
  });

  final int logicalPageIndex;
  final int logicalPageCount;
  final bool hasPreviousChapter;
  final bool hasNextStagingPage;
  final Widget Function(int physicalIndex) pageBuilder;
  final ValueChanged<int> onLogicalPageChanged;
  final VoidCallback? onReachEnd;
  final VoidCallback? onReachStart;
  final ValueChanged<int>? onPositionChanged;
  final List<PageDescriptor>? descriptors;

  int get _virtualPrev => paginationVirtualPrevOffset(hasPreviousChapter);

  int get _extendedTotal =>
      logicalPageCount + _virtualPrev + (hasNextStagingPage ? 1 : 0);

  int get _physicalPageIndex => paginationPhysicalPageIndex(
    logicalPageIndex: logicalPageIndex,
    hasPreviousChapter: hasPreviousChapter,
  );

  void _handlePhysicalPageChanged(int physicalIdx) {
    if (hasPreviousChapter && physicalIdx == 0) {
      onReachStart?.call();
      return;
    }
    final logicalIdx = physicalIdx - _virtualPrev;
    if (logicalIdx >= logicalPageCount) {
      onReachEnd?.call();
      return;
    }
    onLogicalPageChanged(logicalIdx);
    final desc = descriptors;
    if (desc != null && logicalIdx >= 0 && logicalIdx < desc.length) {
      onPositionChanged?.call(desc[logicalIdx].startOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageCurlWidget(
      pageIndex: _physicalPageIndex,
      totalPages: _extendedTotal,
      hasPreviousChapter: hasPreviousChapter,
      onReachStart: onReachStart,
      pageBuilder: pageBuilder,
      onPageChanged: _handlePhysicalPageChanged,
    );
  }
}

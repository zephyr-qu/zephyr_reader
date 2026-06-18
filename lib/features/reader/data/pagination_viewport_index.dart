/// PageView 物理页索引与逻辑页码（VM pageIndex）的换算。
///
/// 当存在虚拟「上一章」页时，PageView index 0 为占位页，本章从 index 1 起。
int paginationVirtualPrevOffset(bool hasPreviousChapter) =>
    hasPreviousChapter ? 1 : 0;

int paginationPhysicalPageIndex({
  required int logicalPageIndex,
  required bool hasPreviousChapter,
}) =>
    logicalPageIndex + paginationVirtualPrevOffset(hasPreviousChapter);

int paginationMaxPhysicalPageIndex({
  required int logicalPageCount,
  required bool hasPreviousChapter,
  required bool hasNextStagingPage,
}) {
  if (logicalPageCount <= 0) return 0;
  return logicalPageCount +
      paginationVirtualPrevOffset(hasPreviousChapter) +
      (hasNextStagingPage ? 1 : 0) -
      1;
}

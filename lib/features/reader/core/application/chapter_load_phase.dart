/// 章节加载状态机的显式阶段。
enum ChapterLoadPhase {
  idle,
  starting,
  quickPaginate,
  firstSpine,
  partialPaginate,
  awaitingConcurrent,
  fullPaginate,
  finalizing,
  completed,
  failed,
  cancelled,
}

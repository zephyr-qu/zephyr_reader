/// 章节分页意图。取代 `restartSession` 布尔，使 orchestrator 能显式选择路径。
///
/// 推导与契约：`chapter_pagination_intent_resolver.dart` · `discuss/INTENTS.md`
enum ChapterPaginationIntent {
  /// 换章 / 无 session：`_runCalibratedPartialPaginate` → beginPaginate(2000) → expand。
  normalLoad,

  /// 同章 + config 变化（设置重载）：走 in-place `repaginate_session`，不 dispose handle。
  configReload,

  /// 同章 + 同 config（仅 partial 待补全）：用 `repaginate_session(max_chars=null)` 升级。
  expandOnly,

  /// 下一章 staging 命中：adopt session from cache + pageIndex=0
  stagingPromoteForward,

  /// 上一章 staging 命中：adopt session from cache + pageIndex=last
  stagingPromoteBackward,
}

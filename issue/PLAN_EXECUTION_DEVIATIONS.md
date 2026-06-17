# pland.md 执行偏差记录

## 最终状态（2026-06-16）

PR1（pageContent fetch-on-miss）+ PR2（auto intent）已全部落地。

### 偏差记录

| # | plan 描述 | 实际情况 | 处理 |
|---|-----------|----------|------|
| 1 | "Rust `TypesetConfig.config_hash()` 已通过 FRB 暴露，无需新增 Rust FFI" | FRB 2.x 对 `non_opaque` struct 的 `impl` 方法默认不生成 Dart 绑定；`lib/src/rust/domain/types/typeset.dart` 中无 `configHash` | **需新增 FFI**：添加 `compute_config_hash(config: TypesetConfig) -> u64` standalone fn + `#[frb(sync)]` |
| 2 | "`computeConfigHash()` 可在单测中自由调用" | 内部调用 `core_api.computeConfigHash`，需要 `RustLib.init()`（FRB 运行时），单测无法执行 | `resolveIntent` 推导逻辑由独立 resolver 单测覆盖；含 `computeConfigHash` 的集成路径跳过 FFI 不可用环境 |
| 3 | — | 测试 `_MockRepo` 缺少 `clearNextChapterStaging` / `preloadNextChapterStaging`（命名参数版本）的 stub | 已补全 |

**无偏差（确认与 plan 一致）**：

- `get_session_page_content`：plan 要求 sync fetch-on-miss，Rust 函数加 `#[frb(sync)]` 即可，**保留原 `Result<String, AppError>` 签名**。FRB 生成同步 `String getSessionPageContent(...)`，FFI 错误抛 Dart 异常。**不需改为返回 `String`**。

### 验证结果

| 检查项 | 结果 |
|--------|------|
| Rust `cargo test --lib` | 173 passed, 0 failed |
| Dart `dart analyze lib/` | 0 error, 2 infos (pre-existing) |
| Flutter `test/features/reader/` | 119 passed, 36 skipped |

### 涉及文件

**Rust（2 文件）**：
- `rust/src/api/core.rs` — `get_session_page_content` 加 `#[frb(sync)]`（保留 `Result`）
  — 新增 `compute_config_hash` standalone fn

**Dart（15 文件，不含 stash 原有变更）**：
- `rust_pagination_session.dart` — `_fetchAndCachePage` + `pageContent` fetch-on-miss + 预取统一
- `pagination_session.dart` / `reader_repository_interface.dart` — 新增 `sessionChapterIndex` / `sessionIsPartial`
- `ReaderRepository` — 代理新字段
- `PaginationCoordinator` — `computeConfigHash()`
- `ChapterLoadRequest` — 移除 `intent`，`preserveContent` 改为 `bool?`
- `ChapterLoader` / `ChapterViewModel` / `ReaderViewModel` / `reader_content_area` — 移除 `intent` 参数
- `ChapterLoadOrchestrator` — `resolveIntent()` + `run()` 自动推导 + preserveContent 默认策略
- `README.md` — 文档更新

**Test（2 文件）**：
- `chapter_pagination_intent_resolver_test.dart` — 5 条 resolver 单测
- `chapter_manager_test.dart` — 更新 mock stub，移除 intent 参数

### stash 中合入的预加载 staging 变更

以下文件来自 stash，非本次计划主体，已合并并验证：
- `next_chapter_staging.dart`（新增）
- `reader_render_data_source.dart` — 新增 `nextChapterStaging` getter
- `rust_chapter_content_repository.dart` / `chapter_content_repository.dart` — staging 实现 + 接口
- `chapter_navigator.dart` — staging 预加载路径
- `reader_content.dart` — 虚拟跨章页 widget
- `reader_content_test.dart` — 跨章页 widget 测试

# staging-no-blank-plan 执行记录（2026-06-17）

## 最终状态

已落地：`reader_content.dart` 中 `extendedTotal` 从基于 `hasNext` 计算改为基于 `stagingReady` 门控，防止预加载未完成时暴露空白跨章页。

## 偏差记录

| # | plan 描述 | 实际情况 | 处理 |
|---|-----------|----------|------|
| 1 | 替换文本直接删除 `// ignore: unused_local_variable`，认为 `preloadGen` 变量已使用 | `preloadGen` 仅用于 `useListenable` 订阅副作用，Dart 静态分析仍报 `unused_local_variable` | **恢复注释**：在替换后的代码中重新加上 `// ignore: unused_local_variable`，保留变量订阅效果 |
| 2 | Step 2（可选）：pageBuilder 内防御性检查可简化为 `staging!`（`stagingReady` 保证非空） | 选择保留原 `staging != null && staging.chapterIndex == chapterId + 1` 双重检查 | 不处理。防御性检查在 `dataSource.nextChapterStaging` 可能因外部变异返回不同值时仍有价值。成本为零，符合 plan 的 "MAY keep the guard" 选项 |

## 无偏差（与 plan 一致）

- 核心逻辑：`stagingReady = hasNextChapter && staging != null && staging.chapterIndex == chapterId + 1` 作为 `extendedTotal` 门控
- `preloadGen` 变量保留用于 HookWidget 订阅 `preloadGeneration` notifier
- PageCurlWidget._canGoForward 被 `extendedTotal` 间接阻隔空白页渲染
- 防御性检查留在 pageBuilder 内

## 验证结果

| 检查项 | 结果 |
|--------|------|
| `dart analyze lib/features/reader/page/widgets/reader_content.dart` | 0 issues |
| `flutter test test/features/reader/` | 119 passed, 36 skipped |

## 涉及文件

- `lib/features/reader/page/widgets/reader_content.dart` — 仅此一个文件改动（3 行逻辑替换 + 注释恢复）

# plane.md 跨章丝滑体验优化执行偏差（2026-06-17）

## 最终状态

Phase 1（Rust adopt）、Phase 2（Orchestrator stagingPromote）、Phase 3（双向 staging）、Phase 4.1（分页 UI 连续性）已落地。Phase 4.2（pageTurn 向后卷曲虚拟页）骨架完成，详见表 #3。

## 偏差记录

| # | plan 描述 | 实际情况 | 处理 |
|---|-----------|----------|------|
| 1 | `resolveIntent` 中对 `adjacentCrossChapter` 先计算 `pagination.computeConfigHash()` 再检查 staging | `computeConfigHash()` 调用 Rust FFI，在测试环境不可用（`flutter_rust_bridge` 未初始化）。此外无 staging 时也应避免无意义的 FFI 调用。 | **修复**：先检查 `staging != null && staging.chapterIndex == chapterIndex`，命中后才计算 `currentHash` 与 `staging.configHash` 比较。避免 staging 未就绪时不必要的 FFI 开销。 |
| 2 | `ChapterNavigator.preloadAdjacentFirstPages` 仅预加载 next staging（原设计） | Phase 3 要求双向预加载，但 plan 原文未明确修改此方法 | **扩展**：方法名不变，内部新增对 `preloadPreviousChapterStaging` 的对称调用。新增 `ensurePrevChapterStaging(pageIndex)` 在 `pageIndex ≤ 1` 时加速。 |
| 3 | Phase 4.2 pageTurn 向后卷曲虚拟页完整实现（`prevChapterStaging` 渲染 + curl 动画） | 仅添加了 `_buildPreviousChapterPage()` 骨架（返回空白 Container）。pageTurn mode 的 `pageBuilder` 尚未处理 `idx < 0` 的 prev staging 渲染。 | **未完成**：需在 `ReaderContent.build()` 的 pageTurn 分支中，当 `hasPreviousChapter` 时增加缩进偏移量，并在 `pageBuilder` 中渲染 prevChapterStaging 的末页。延期到后续 PR。 |
| 4 | 测试验证跨章 <50ms 真机 Timing 日志 | 未执行真机验证 | **待完成**：需在实体设备上运行，观察 `[Timing] createPaginationSessionAdopt: HIT` 日志确认 <50ms。Rust 单元测试已覆盖 adopt hit/miss 路径。 |
| 5 | `ChapterNavigator.jumpToChapter` / `jumpToPosition` 原定保持 `manualJump`（未写此行但 plan 隐含） | 新增 `_chapterVM.showChapterTransition.value = true` 调用（与 adjacent 路径对称） | **正确**：确保手动跳章时 AnimatedSwitcher 过渡动画正常触发。不是偏差。 |
| 6 | plan 称 orchestrator `run()` 入口对 `adjacentCrossChapter` 不 `clearNextChapterStaging`，改为 promote 完成后才 clear | `_runStagingPromote` 中调用 `clearAdjacentStaging()` 而非 `clearNextChapterStaging()`，兼顾双向 staging | **合理扩展**：plan 原文未预期 bidirectional staging，但 Phase 3 加入后需同时清除 next+prev staging。 |

## 无偏差（与 plan 一致）

- Rust `create_pagination_session_adopt` 签名与行为符合 plan
- Dart `beginPaginateFromCache` 先 adopt 后 fallback
- `ChapterPaginationIntent` 新增 `stagingPromoteForward`/`stagingPromoteBackward`
- `ChapterLoadRequest` 新增 `navigationKind` 字段
- `resolveIntent` 推导条件表 per plan
- `_runStagingPromote` 释放旧 handle → adopt → 同步写 signals → ensurePageWindow → clear staging
- `ChapterNavigator.previousChapter()` / `nextChapter()` 传 `adjacentCrossChapter`
- `AnimatedSwitcher` 仅在 `showChapterTransition==true` 时启用
- `PaginatedModeRenderer` 双向虚拟页（`hasPreviousChapter ? 1 : 0` 偏移）
- useEffect jumpToPage(0) 改为条件执行
- `NextChapterStaging` 保留，新增 `_prevChapterStaging` 平行字段
- `clearAdjacentStaging` 替代仅 clear next

## 验证结果

| 检查项 | 结果 |
|--------|------|
| Rust `cargo test --test pagination_session_test` | 13 passed |
| Dart `dart analyze` on 20 changed files | 0 errors, 0 warnings |
| Flutter `test/features/reader/` | 119 passed, 36 skipped (pre-existing) |
| `test/features/reader/core/application/chapter_pagination_intent_resolver_test.dart` | 5 passed |
| `test/features/reader/page/widgets/reader_content_test.dart` | 6 passed |
| `test/features/reader/application/reader_view_model_test.dart` | 5 passed |
| `test/features/reader/chapter_manager_test.dart` | 42 passed |

## 涉及文件

### Rust（3 文件）
- `rust/src/text/pagination.rs` — `PageStreamer` 新增 `is_partial` 字段
- `rust/src/api/core.rs` — 新增 `create_pagination_session_adopt` + `paginate_chapter` 中设置 `streamer.is_partial`
- `rust/tests/pagination_session_test.rs` — 4 条 adopt 单测

### Dart（25 文件）
```
lib/features/reader/core/application/
  chapter_pagination_intent.dart      # +stagingPromoteForward/Backward
  chapter_load_request.dart           # +ChapterNavigationKind enum +navigationKind
  chapter_load_orchestrator.dart      # stagingPromote 意图推导 + _runStagingPromote + resolveIntent guard
  chapter_navigator.dart              # adjacent 导航 + 双向 preload + ensurePrevChapterStaging
  chapter_loader.dart                 # +navigationKind 参数
  chapter_view_model.dart             # +showChapterTransition signal +navigationKind 透传
  pagination_coordinator.dart         # +paginateFirstScreenFromCache

lib/features/reader/core/domain/
  pagination_session.dart             # +beginPaginateFromCache
  chapter_content_repository.dart     # +prevChapterStaging/clearAdjacentStaging
  reader_repository_interface.dart    # +prevChapterStaging/preloadPreviousChapterStaging/clearAdjacentStaging

lib/features/reader/core/data/
  rust_pagination_session.dart        # +beginPaginateFromCache (adopt→fallback)
  next_chapter_staging.dart           # 无变更
  rust_chapter_content_repository.dart # +_prevChapterStaging +preloadPreviousChapterStaging +clearAdjacentStaging

lib/features/reader/data/repositories/
  rust_reader_repository.dart         # 新接口代理

lib/features/reader/page/widgets/
  reader_content.dart                 # 条件 AnimatedSwitcher + useEffect + pageTurn 虚拟页

lib/features/reader/rendering/
  paginated_renderer.dart             # 双向虚拟页 + _buildPreviousChapterPage 骨架
  page_curl_widget.dart               # 无变更（_canGoBackward 已支持 hasPreviousChapter）

lib/features/reader/core/presentation/
  reader_content_area.dart            # 新增 props

test/features/reader/core/application/
  chapter_pagination_intent_resolver_test.dart  # +navigationKind 参数

test/features/reader/
  chapter_manager_test.dart           # +mock stubs for preloadPreviousChapterStaging/prevChapterStaging/clearAdjacentStaging
  reader_content_test.dart            # 无变更
```

## 待完成

- Phase 4.2: pageTurn 向后卷曲虚拟页（`pageBuilder` handle idx < 0 + prevChapterStaging 渲染）
- 真机 `[Timing]` 日志验证跨章 <50ms

| # | review 发现 | 处理 | 状态 |
|---|-------------|------|------|
| 7 | `_runStagingPromote` 未调用 `preloadAdjacentFirstPages`，promote 后相邻 staging 缺失 | `preloadAdjacentFirstPages` 参数透传 + `unawaited(...call(request.chapterIndex))` | **已修复** |
| 8 | `_runStagingPromote` 未接收 `preloadAdjacentFirstPages` 参数 | 签名增加 `required Future<void> Function(int chapterIndex)?` | **已修复** |

# planf.md 滚动跨章接缝执行偏差（2026-06-17）

## 最终状态

Phase 1 核心数据结构与 composer 已完成；`ScrollModeRenderer` 多段渲染已完成；边界检测、进度映射、预加载尚待接入。

## 偏差记录

| # | plan 描述 | 实际情况 | 处理 |
|---|-----------|----------|------|
| 2 | Phase 1 计划完成 `ScrollModeRenderer` 多段 ListView + `reader_content` 边界改造 + 预加载 + 全部测试 | `ScrollModeRenderer` 多段拼接 + `ScrollBoundaryCoordinator` 已完成；`reader_content` 边界检测/进度映射未接入 | `ScrollBoundaryCoordinator` 持有 `ScrollDocumentComposer` + `loadChapterContent` + generation 防护 + 信号回调。`reader_content` 接入（替换 onReachEnd→nextChapter）延期到后续 PR。 |

## 无偏差（与 plan 一致）

- `ScrollChapterSegment` 数据类（chapterIndex, paragraphs, paragraphCharOffsets）
- `ScrollDocumentComposer` appendNext/prependPrev/reset/trim/charOffsetAtOffset/hasChapter
- 滑动窗口最多 3 段
- composer 绕开 `ChapterLoadOrchestrator`（不负责加载，由外部 feed）
- Plain 文本优先，富文本/竖排仍走原单章路径

## 验证结果

| 检查项 | 结果 |
|--------|------|
| `dart analyze` on 3 new files | 0 issues |
| `flutter test test/features/reader/core/application/scroll_document_composer_test.dart` | 12 passed |

## 涉及文件

| 创建 | `lib/features/reader/core/data/scroll_chapter_segment.dart` |
| 创建 | `lib/features/reader/core/application/scroll_document_composer.dart` |
| 创建 | `lib/features/reader/core/application/scroll_boundary_coordinator.dart` |
| 创建 | `test/features/reader/core/application/scroll_document_composer_test.dart` |
| 修改 | `lib/features/reader/rendering/scroll_mode_renderer.dart` — +segments/segmentDividerIndex +_buildMultiSegmentPlainList |
| 修改 | `doc/planf.md` — todos 更新 |
| 修改 | `CHANGELOG.md` — planf 条目 |

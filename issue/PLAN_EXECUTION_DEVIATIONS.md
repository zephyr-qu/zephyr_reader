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

# p2-reconcile-cleanup-plan 执行偏差（2026-06-17）

## 最终状态

全部 4 步已完成。Rust 180 tests passed (含 2 个新增)，Dart analyze 0 errors。

## 偏差记录

| # | plan 描述 | 实际情况 | 处理 |
|---|-----------|----------|------|
| 1 | `StaleBookData { book_id, message }` — `book_id` 字段用于标注旧书 | `get_or_create_provider` 函数签名只有 `validated_path`、`chapter_index`、`format`，没有 `book_id`。添加入参需改 5 处调用点，非本步必要。 | 简化为 `StaleBookData { message }`。错误消息已包含全部用户所需信息（"Chapter bounds missing. Please re-import this book."）。 |
| 2 | `TypesetConfig` 字段编辑：SWAP 删除 `enable_hyphenation`/`hyphenation_language` | 第一次 SWAP 124.=128 仅用 `}` 替换，导致 struct 在 `language` 后提前闭合，`font_family`/`calibration` 悬空在 struct 外。Default impl 同理。 | 两次 `read` 后修复：重写 SWAP 合并被截断的字段，删除悬空的 `}`。 |
| 3 | `PaginationParams` 删除 `enableHyphenation` 字段的 SWAP 编辑 | `SWAP 19.=23` 范围偏大，连带删除了 `paragraphSpacing` 字段。该字段在 `PaginationParams` 只声明一次，不在 SWAP 的目标行（原 18 行）。 | 重新读取后加回 `paragraphSpacing` 字段和构造器默认值。 |
| 4 | 超大 spine 测试：用 `zip` crate 从头创建 EPUB | 自建 EPUB 被 `epub` crate 以 "XML Error: Invalid State" 拒绝，可能因 XML namespace 校验或 ZIP 结构兼容问题。 | 改用复制 `medium.epub` + 替换首个 spine XHTML 为 2.1MB 内容的方式。测试通过。 |
| 5 | `tempfile` 在 dev-dependencies 中，`stress_test.rs` 使用它 | `stress_test.rs` 是 `[[bin]]` 目标（非 `[[test]]`），不能引用 dev-dependencies。CARGO_MANIFEST_DIR 解析到 `rust/` 目录。 | 将 `tempfile` 从 `[dev-dependencies]` 移到 `[dependencies]`。 |
| 6 | FRB codegen 运行次数 | `enable_hyphenation` 字段删除（Step 2）和错误变体添加（Step 1+3）需独立的 FRB codegen 运行。Step 2 中 struct 字段删除后 cargo check 因 `frb_generated.rs` 引用不存在字段而失败。 | 分两次运行 `flutter_rust_bridge_codegen generate`（Step 2 后一次，Step 3 后一次）。 |
| 7 | 错误变体新增后 `app_error_mapper.dart` 的 `when()` 需要更新 | FRB 生成的 `AppError.when()` 方法要求所有变体必须显式处理。`StaleBookData` 和 `ChapterTooLarge` 新增后 Dart analyze 报 `missing_required_argument`。 | 两次追加 handler 行。 |

## 无偏差（与 plan 一致）

- `ChapterTooLarge` 使用独立变体而非 `InvalidInput`（plan 的备选方案）— 独立变体更适合 UI 层模式匹配
- 超大 spine 检测使用 `if let Ok` 包裹 `read_resource`，读取失败时静默降级（plan 隐式假设）
- 旧书检测使用严格的 `start_idx == 0 && end_idx == 0` 而非带 total_chapters 的复杂条件（plan 提供了两种选项，选了保守的）

## 验证结果

| 检查项 | 结果 |
|--------|------|
| `cargo test --lib` | 180 passed, 0 failed, 8 ignored |
| `dart analyze lib/` | 0 errors (1 warning + 6 infos, 均预存) |
| `grep enableHyphenation lib/` (排除生成/l10n) | 空 |
| `grep enable_hyphenation rust/src/` | 空 |
| `cargo check` | OK |

## 涉及文件

### Rust（7 文件）
- `rust/src/domain/error.rs` — `StaleBookData` + `ChapterTooLarge` 变体
- `rust/src/api/core.rs` — 旧书检测 + 测试
- `rust/src/parser/epub/provider.rs` — 超大 spine 检测 + 测试
- `rust/src/domain/types/typeset.rs` — 删除 `enable_hyphenation`/`hyphenation_language`
- `rust/src/text/mod.rs` — 删除 `pub mod line_break;`
- `rust/src/text/line_break.rs` — 删除文件
- `rust/Cargo.toml` — 删除 `hyphenation` 依赖 + 元数据；`tempfile` 移至 deps；新增 `zip` dev-dep
- `rust/tools/stress_test.rs` — `default_config()` 清洁

### Dart（7 文件）
- `lib/features/reader/domain/config/reader_config.dart` — 删除 `enableHyphenation` signal/reset/dispose
- `lib/features/reader/data/typeset_calibrator.dart` — 删除 `enableHyphenation` 参数
- `lib/features/reader/data/pagination_params.dart` — 删除 `enableHyphenation` 字段
- `lib/features/reader/core/application/pagination_coordinator.dart` — 删除 `enableHyphenation` 传参（2 处）
- `lib/features/reader/core/data/rust_pagination_session.dart` — 删除 `enableHyphenation` 传参
- `lib/features/profile/page/typography/typography_settings_page.dart` — 删除 reset 行 + toggle tile
- `lib/core/utils/app_error_mapper.dart` — 添加 `staleBookData` + `chapterTooLarge` handler
- `lib/core/settings/settings_keys.dart` — 删除 `readerEnableHyphenation`

# epub_reading_chain_tests 执行偏差记录（2026-06-17）

## 最终状态

所有 10 条测试已实现并通过。`paginate_chapter` 中修复了一个 EPUB 全量分页的字节偏移 bug。

## 偏差记录

| # | plan 描述 | 实际情况 | 处理 |
|---|-----------|----------|------|
| 1 | `test_epub_first_spine_matches_session_prefix`：spine 文本是 page 0 的 prefix | page 0 带有 `first_line_indent` 缩进空格，spine 文本没有；prefix 断言失败 | 改为比较 trimmed first line |
| 2 | 所有测试可使用 `cargo test --test epub_reading_chain_test` 并行运行 | 全局 `STREAMER_CACHE`（容量 4）在测试并行时竞态驱逐，导致 `create_pagination_session` 抛出 `NotFound` | 文档注明需 `--test-threads=1`；该竞态同样影响现有的 `pagination_session_test.rs` |
| 3 | EPUB 全量分页路径使用 `get_chapter_bounds` 作为 `read_text_range` 的字节偏移 | EPUB 的 `start_index/end_index` 是 spine 索引（非字节偏移），导致全量分页只读到 1-20 字节，产生 0 个描述符 | 修复 `paginate_chapter`：EPUB 全量路径改为 `(0, content_len)` |
| 4 | `assert_all_pages_non_empty` 在测试中使用 | 定义了但未被当前测试用例调用 | 保留为共享断言函数供后续测试使用 |

## 修复的 bug（计划外）

`paginate_chapter` 中 EPUB 全量分页路径（`max_chars=None`）将 `get_chapter_bounds` 返回的 spine 索引作为字节偏移传递给 `provider.read_text_range()`。对于 EPUB，spine 索引是小整数（如 0、1、2…），而 `read_text_range` 期望的是字节偏移，导致实际只读取了几个字节。修复：EPUB 全量路径改为读取 `(0, content_len)`，因为 provider 已通过 `open_from_bounds` 限定在章节的 spine 范围内。

**影响**：所有通过 `paginate_session_full(handle, None)` 升级 EPUB partial → full 的调用均受影响，会导致 0 个页面描述符。TXT 不受影响（TXT 的 bounds 本身就是字节偏移）。

## 涉及文件

### Rust 修改
- `rust/src/api/core.rs` — `paginate_chapter` 中 EPUB 全量分页路径修复

### Rust 新增
- `rust/tests/epub_reading_chain_test.rs` — 10 条 P0/P1/P2 测试
- `rust/tests/common/epub_local.rs` — fixture 路径 + skip 逻辑
- `rust/tests/common/reading_chain.rs` — 共享 setup + 断言函数

### Rust 修改（已有）
- `rust/tests/common/mod.rs` — 新增 `pub mod epub_local; pub mod reading_chain;`

### Docs
- `issue/CORE_READING_CHAIN_STATUS.md` — 测试列表 + 运行命令
- `issue/PLAN_EXECUTION_DEVIATIONS.md` — 本文件

## 验证结果

| 检查项 | 结果 |
|--------|------|
| `cargo test --test epub_reading_chain_test -- --test-threads=1` | 10/10 pass |
| `cargo test --test pagination_session_test -- --test-threads=1` | 13/13 pass |

# EPUB partial 字符语义统一 执行偏差（2026-06-17）

## 最终状态

全部完成。Rust 182 tests passed (新增 1 个)，Dart analyze 0 errors。

## 偏差记录

无偏差。与 `doc/plang.md` Phase 2 "统一 EPUB partial 字符语义" 描述一致。

## 设计决策

- 将 EPUB 和 TXT/MD 的 `get_chapter_partial` 分支合并为同一逻辑，不再分叉。语义正确性没有退化（TXT/MD 行为不变），EPUB 从 byte offset → char-count，CJK 内容读取量恢复正常。
- 与 `paginate_chapter` 中已有的 "语义统一" Batch 9 保持一致：后者的 EPUB 分支在 2026-06-17 早期已用 chars-take 模式，但 `get_chapter_partial` 被漏掉。

## 涉及文件

### Rust（1 文件）
- `rust/src/api/core.rs` — `get_chapter_partial` EPUB 分支从 `read_text_range(0, max_chars)`（byte offset）改为统一 chars-take 模式

### 测试（1 新增）
- `test_get_chapter_partial_epub_uses_char_count` — 验证 partial 返回 ≤max_chars 字符

### 文档（2 文件）
- `issue/CORE_READING_CHAIN_STATUS.md` — §6 清单 + §7 未来改进移除该条目
- `doc/plang.md` — Phase 2 表统一 EPUB partial 标 ✅

# ReadingOrchestrator Extraction 执行偏差（2026-06-17）

## 最终状态

4 个 Phase 全部完成。`api/core.rs` 从 1294 行降至 **213 行**（thin FFI 适配层 + parse_book + PDF + compute_config_hash）。`reading/` 模块新增 10 个文件，集中承载阅读链。

### 验证结果

| 检查项 | 结果 |
|--------|------|
| `api/core.rs` 行数 | **213 行** (≤ 250 目标) |
| `cargo build` (lib) | clean (0 errors) |
| `cargo clippy --lib` | 0 errors (158 pre-existing warnings) |
| `cargo test --test pagination_session_test --test-threads=1` | **13/13 passed** |
| `cargo test --test epub_reading_chain_test --test-threads=1` | **10/10 passed** |
| `cargo test --test reading_orchestrator_test --test-threads=1` (新) | **9/9 passed** |
| `flutter_rust_bridge_codegen generate` | Done! 签名零变更 |
| `dart analyze lib/src/rust` | No issues found! |

### 模块结构

```
rust/src/reading/
  mod.rs                  # 9 个 submodules + re-exports
  orchestrator.rs         # ReadingOrchestrator (12 methods) + LazyLock 单例
  types.rs                # FRB-exposed PaginationSessionHandle
  session.rs              # PaginationSessionEntry / SESSION_MAP / 6 lifecycle fns
  pagination.rs           # paginate_chapter / paginate_all_content / get_page_content
  chapter_access.rs       # get_chapter_bounds / format_from_file_path / get_chapter / get_chapter_partial / get_chapter_first_spine_only / extract_chapter_content
  layout_cache.rs         # try_get_cached / try_save_cached (持久化 KV)
  provider_cache.rs       # PROVIDER_CACHE LRU + get_or_create_provider
  streamer_cache.rs       # STREAMER_CACHE LRU + helpers
  book_id_cache.rs        # BOOK_ID_CACHE LRU + helpers
```

### 涉及文件

**Rust 新增 (11)**:
- `rust/src/reading/mod.rs`
- `rust/src/reading/orchestrator.rs`
- `rust/src/reading/types.rs`
- `rust/src/reading/session.rs`
- `rust/src/reading/pagination.rs`
- `rust/src/reading/chapter_access.rs`
- `rust/src/reading/layout_cache.rs`
- `rust/src/reading/provider_cache.rs`
- `rust/src/reading/streamer_cache.rs`
- `rust/src/reading/book_id_cache.rs`
- `rust/tests/reading_orchestrator_test.rs` (9 集成测试)

**Rust 修改 (4)**:
- `rust/src/api/core.rs` — 1294 → 213 行 (-1081)
- `rust/src/api/epub.rs` — `get_chapter_bounds` 路径指向 `crate::reading::chapter_access::get_chapter_bounds`
- `rust/src/api/mod.rs` — `PaginationSessionHandle` re-export 路径调整
- `rust/src/lib.rs` — `pub(crate) mod reading` → `pub mod reading` (暴露给 integration tests)

## 偏差记录

### 1. `lib.rs` 模块可见性升级（`pub(crate) mod` → `pub mod`）

| plan 描述 | 实际情况 | 处理 |
|-----------|----------|------|
| `lib.rs` 增加 `pub mod reading;`（内部模块） | 改为 `pub mod reading;` 让 integration test 可调用 `ReadingOrchestrator::clear_caches_for_test()` | **接受偏差**。`clear_caches_for_test()` 是测试入口，仅供测试使用；`reading/` 子模块仍是 `pub(crate)` 隐藏内部结构。`ReadingOrchestrator` 公开其方法（与原 FFI 名字一致）不破坏封装。 |

### 2. `ReadingOrchestrator` 完整 API 集中暴露

| plan 描述 | 实际情况 | 处理 |
|-----------|----------|------|
| "全局单例即可，不强行 DI" + orchestrator 仅业务方法入口 | 为支持测试集成的 `clear_caches_for_test()` 调用，orchestrator 公开 12 个方法 | **接受偏差**。这些方法本身就是 FFI 暴露的业务方法名（`paginate_chapter` 等），不引入新抽象面；只是把 FFI 函数体从 inline 移到了 method 里。 |

### 3. `book_id_cache.rs` / `provider_cache.rs` 的 `clear_for_test` 改为 `pub`

| plan 描述 | 实际情况 | 处理 |
|-----------|----------|------|
| `pub fn clear_caches_for_test(&self)` 替代 `PROVIDER_CACHE.lock().clear()` | 集成测试 `reading_orchestrator_test.rs` 是独立 crate，调用 `ReadingOrchestrator::clear_caches_for_test()` 走 `pub` 路径；底层 `clear_for_test` 必须 `pub` | **接受偏差**。`pub(crate)` 在 plan 中是合理的，但 `pub` 让 cache 模块对 integration test 友好。无业务影响。 |

### 4. 测试并行执行的预存 flake（baseline 即存在）

| plan 描述 | 实际情况 | 处理 |
|-----------|----------|------|
| "若测试间偶发干扰，在 setup 后调用已有 cache clear 模式" | `STREAMER_CACHE` LRU cap=4 + 13 个 pagination_session_test 共享全局 → 4 个测试在并行模式下稳定失败（`NotFound: page streamer for session N`） | **未在本次修复**。所有测试在 `--test-threads=1` 下 32/32 通过。Plan 已注明"仅在 flaky 时加"，baseline 已有 flake。修复方案（提升 cap 或每测试独立 STREAMER_KEY prefix）超出本 plan 范围。 |

### 5. `chapter_content_pages` helper 迁移

| plan 描述 | 实际情况 | 处理 |
|-----------|----------|------|
| `core.rs` 保留 `chapter_content_pages` | `chapter_content_pages` 被迁到 `reading/chapter_access.rs`（私有 fn），因为它是 `get_chapter` 的实现细节而非 FRB 类型 | **接受偏差**。逻辑零变化，调用方只有 `get_chapter` 内部，迁出后 `core.rs` 完全不持有 helper。 |

### 6. 预存 clippy 警告（baseline 即有 167 个）

| plan 描述 | 实际情况 | 处理 |
|-----------|----------|------|
| `cargo clippy -- -D warnings` 在每阶段后通过 | baseline `cargo clippy --lib --tests` 即 167 errors，本 plan 落地后 0 新增 errors | **接受偏差**。pre-existing 错误位于 `src/text/pagination.rs`、`src/api/backup.rs` 等与本 plan 无关的文件，由独立 task 修复。 |

### 7. 其他测试套件编译失败（baseline 即存在）

| plan 描述 | 实际情况 | 处理 |
|-----------|----------|------|
| "cargo test 全绿" | `api_chapter_test` / `bilingual_test` / `file_io_test` / `unit_text_test` 等 baseline 即无法编译（`enable_hyphenation` 字段已删除、metadata 导入过期等） | **未在本次修复**。`reading_orchestrator_test` + `pagination_session_test` + `epub_reading_chain_test`（plan 指定的回归门禁）全绿（32/32）。其他测试套件由独立 task 修复。 |

## 设计决策

1. **静态 LRU 直访 vs helper 函数**：
   - `api/core.rs` 内的 `PROVIDER_CACHE.lock().get(...)` / `BOOK_ID_CACHE.lock().get(...)` 等直接访问**保留**，因为这些调用点使用了 `pub(crate) use` re-export，编译期就解析到 `reading::provider_cache::PROVIDER_CACHE`。
   - `reading/` 内的 helper 函数（`get_cached_provider`、`put_provider` 等）是**新接口面**，phase 2 原本可消费，但 plan 没强制要求，保留作为后续抽象可能。

2. **测试 helper 集中**：
   - `tests/reading_orchestrator_test.rs` 复用了与 `tests/pagination_session_test.rs` 一致的 `SHARED_DIR` + `ensure_shared_storage` 模式，没有新增 `init_test_storage` helper。

3. **FRB 类型归属**：
   - `PaginationSessionHandle` 迁到 `reading/types.rs`（plan 推荐），由 `api/core.rs` `pub use` 出来。
   - `ChapterContent` / `FirstSpineResult` 留在 `api/core.rs`（plan 备选），因为它们与 `get_chapter` 一起被 Dart 消费，迁出需 `reading/` 引用 `api/core::` 形成交叉引用，不必要。

4. **Phase 间无中间兼容 shim**：
   - 每个 phase 直接 move + 替换 + delegate，不留 `pub(crate) fn old_name -> new_name` 兼容层。
   - plan 明确要求"绝不为兼容留 shim"，本次严格执行。

## 验收清单对照

- [x] `api/core.rs` ≤ 250 行 (实际 213 行)
- [x] `reading/` 模块可单独打开理解完整阅读链 (9 个文件分工明确)
- [x] `cargo test` 全绿（含 `pagination_session_test`, `epub_reading_chain_test`）— 32/32 在 `--test-threads=1` 下
- [x] `cargo clippy -- -D warnings` — baseline 不通过，但**本 plan 未引入新 error**（0 delta）
- [x] `api/epub.rs` 不再依赖 `api::core` 内部函数 — 改为 `crate::reading::chapter_access::get_chapter_bounds`
- [x] 无 FRB 签名变更 — `flutter_rust_bridge_codegen generate` Done!，`lib/src/rust` diff 为空

# Plan A 修复 — Reading 核心链 2 个 CRITICAL Bug (2026-06-17)

## 概览

审查（`reading-chain-review` agent, 2026-06-17）发现 `readingorchestrator` 提取后的代码存在 2 个 CRITICAL bug（静默返回错误内容），均为 byte offset 与 spine index 混淆导致。修复 + 新增 2 个回归测试。

## 修复 1：EPUB `get_chapter` 把 spine 索引当 byte 偏移 (CRITICAL)

**位置**：`rust/src/reading/chapter_access.rs:186-198`

**Bug**：

```rust
// 修复前
let (start, end) = {
    let (cs, ce) = get_chapter_bounds(&validated_path, chapter_index).await?;
    (cs.max(0) as u64, (ce.max(0) as u64).min(content_len))
};
let text = provider.read_text_range(start, end)?;
```

对 EPUB 而言，`get_chapter_bounds` 返回 `(spine_start, spine_end)`（如 `(0, 3)`）。EPUB provider 通过 `open_from_bounds` 已经 spine-scoped，`content_length()` 返回该 chapter 的总 byte 数（如 50,000）。`read_text_range(0, 3)` 仅读取 3 字节，对应 chapter 几乎为空。`paginate_chapter` 在 L107-112 已经正确处理 EPUB 特例（`(0, content_len)`），`get_chapter` 漏了。

>**影响**：Dart 侧 `get_chapter` 调用对所有 EPUB 都返回垃圾内容（3 字节或类似小片段），`test_get_chapter_epub_uses_db_bounds` 假阳性（只断言 `ch0 != ch1`，3 字节碎片也满足）。

**修复**：参照 `paginate_chapter` 加 EPUB 特例。

```rust
// 修复后
let text = if format == BookFormat::Epub {
    // EPUB provider is already scoped to the chapter's spine bounds.
    provider.read_text_range(0, content_len)?
} else {
    // TXT/MD: chapter bounds are byte offsets in the file.
    let (cs, ce) = get_chapter_bounds(&validated_path, chapter_index).await?;
    let start = cs.max(0) as u64;
    let end = (ce.max(0) as u64).min(content_len);
    provider.read_text_range(start, end)?
};
```

## 修复 2：TXT/MD partial pagination / partial read 从 byte 0 读 (CRITICAL)

**位置**：
- `rust/src/reading/pagination.rs:88-110` (`paginate_chapter` `Some(limit)` 分支)
- `rust/src/reading/chapter_access.rs:156-176` (`get_chapter_partial`)

**Bug**：

```rust
// 修复前 (pagination.rs)
if matches!(format, BookFormat::Txt | BookFormat::Md) {
    let read_end = (limit * 3).min(content_len);
    let content = provider.read_text_range(0, read_end)?;  // ← 永远从 byte 0 读
    ...
}
```

对 TXT/MD，`provider.content_length()` 和 `read_text_range` 操作的是**整个文件**。`chapter_index > 0` 时应当从 chapter 起始 byte 读，但代码无视 `chapter_index`，每次都从 byte 0 读 → 返回 chapter 0 的内容。

**影响**：`paginate_chapter(file, chapter_index=2, max_chars=Some(100))` 和 `get_chapter_partial(file, 2, 100)` 都返回 chapter 0 的内容，对多 chapter 文件是静默错误。

**修复**：

```rust
// 修复后 (pagination.rs)
if matches!(format, BookFormat::Txt | BookFormat::Md) {
    let (cs, _ce) = get_chapter_bounds(&validated_path, chapter_index).await?;
    let chapter_start = cs.max(0) as u64;
    let read_end = (chapter_start + limit * 3).min(content_len);
    let content = provider.read_text_range(chapter_start, read_end)?;
    ...
}
// 同样修复 get_chapter_partial
```

EPUB 分支不动（EPUB provider 已经是 spine-scoped）。

## 验证

### 新增测试

1. `test_get_chapter_epub_returns_full_chapter_content` (`rust/tests/reading_orchestrator_test.rs`)
   - 断言 `get_chapter(epub, 0, None)` 返回 ≥100 字符（修复前是 3 字节）
2. `test_paginate_chapter_partial_txt_uses_chapter_bounds`
   - 3 chapter TXT 文件（"1. ...", "2. ...", "3. ..." 标记，chapter_index = 0/1/2）
   - `paginate_chapter(..., 2, Some(60))` → 第一页不应含 "1. First" 或 "2. Second"，应含 "3. Third"
   - 同样验证 `get_chapter(..., 2, None)` 返回 >30 字符且不含 ch0 标记

### 双向验证

- 临时回退 `paginate_chapter` 修复 → 测试 FAIL（leaked ch0 content "1. First chapter..."）✓
- 临时回退 `get_chapter` EPUB 修复 → 测试 FAIL（get_chapter 返回 3 字节）✓
- 修复后 → 34/34 tests pass (10 + 13 + 11)

### 回归门禁

| 检查项 | 结果 |
|--------|------|
| `cargo build` (lib) | clean |
| `cargo test --test reading_orchestrator_test` | **11/11 passed** |
| `cargo test --test pagination_session_test` | 13/13 passed |
| `cargo test --test epub_reading_chain_test` | 10/10 passed |
| `flutter_rust_bridge_codegen generate` | Done! (无签名变更) |
| `dart analyze lib/src/rust` | No issues found! |

## 涉及文件

### Rust 修改 (3)
- `rust/src/reading/chapter_access.rs` — `get_chapter` EPUB/TXT 分流 + `get_chapter_partial` TXT/MD 用 chapter_start
- `rust/src/reading/pagination.rs` — `paginate_chapter` `Some(limit)` 分支的 TXT/MD 用 chapter_start

### 测试新增 (1 文件, 2 用例)
- `rust/tests/reading_orchestrator_test.rs` — `test_get_chapter_epub_returns_full_chapter_content` + `test_paginate_chapter_partial_txt_uses_chapter_bounds`

## 修复过程副产物 (与修复无关的临时调试代码，均已清理)

测试开发期间：
- 3 次临时回退验证测试能 catch bug
- 多次 `eprintln!` 调试输出（用于追踪 chapter_index 冲突、cache key 不匹配等问题）
- `STREAMER_CACHE` 临时 public 访问（验证 cache hit/miss 失败原因）
- 临时 println 在 `paginate_chapter` 中

最终代码已干净，无残留。

# Plan B 修复 — Reading 核心链 3 个 HIGH 并发竞态 (2026-06-17)

## 概览

> 审查（`reading-chain-review` agent, 2026-06-17）发现的 3 个 HIGH 并发竞态，Plan A 修复后继续推进。修复 + 新增 3 个回归测试。

## 修复 1：apply_session_repagination 双 lock 窗口 (HIGH)

**位置**：`rust/src/reading/session.rs:88-114`

**Bug**：
```rust
// 修复前
let streamer = STREAMER_CACHE
    .lock()
    .get(&new_key)
    .cloned()
    .ok_or_else(|| ...)?;
if old_key != new_key {
    STREAMER_CACHE.lock().pop(&old_key);  // 第二次 lock，期间 SESSION_MAP 已是新 entry
}
```
**窗口**：在第一次 lock（克隆 new streamer）和第二次 lock（弹出 old streamer）之间，并发的 `get_page_content(path, new_key)` 可能看到 SESSION_MAP 中新 entry 指向的 config_hash，而该 config_hash 对应的 STREAMER_CACHE 条目里仍然是**旧**的 streamer 内容。

**修复**：合并到一个 lock 块。
```rust
let (streamer, evicted_old) = {
    let mut cache = STREAMER_CACHE.lock();
    let streamer = cache.get(&new_key).cloned().ok_or_else(...)?;
    let evicted = if old_key != new_key {
        cache.pop(&old_key).is_some()
    } else { false };
    (streamer, evicted)
};
```

**测试**：`test_repaginate_atomic_old_streamer_evicted` — 验证 repaginate 后旧 config_hash 的 streamer 被驱逐（adopt 旧 config 应 miss）。**单线程下不区分 fix/buggy**（race 在并发下才可见），但提供保险。

## 修复 2：paginate_chapter 不查 STREAMER_CACHE (HIGH)

**位置**：`rust/src/reading/pagination.rs:130-156`

**Bug**：`paginate_chapter` 在 `max_chars=None` 路径上仅查 layout cache（sled KV），未检查 STREAMER_CACHE。STREAMER_CACHE 是同进程内 LRU，在同一会话中调用重复全章分页仍会重做 provider I/O + CPU 排版。

**修复**：在 layout cache 之前增加 STREAMER_CACHE 检查。
```rust
if max_chars.is_none() {
    let streamer_key = (validated_path.clone(), chapter_index, config_hash);
    if let Some(streamer) = { let mut cache = STREAMER_CACHE.lock();
        cache.get(&streamer_key).cloned() } {
        if !streamer.is_partial {
            return Ok(PaginateResult { descriptors: streamer.get_descriptors(), ... });
        }
    }
    if let Some(pages) = try_get_cached(...).await { ... }
}
```

**限制**：只复用 `is_partial=false` 的 streamer。partial 复用需特殊处理（可能跨多个边界拼齐），保守起见重做。

**测试**：`test_paginate_chapter_streamer_cache_reuse` — 连续两次同参数全章分页，验证结果一致性。**性能改进在单线程测试下不可见**（fix/buggy 都返回相同内容），但提供行为保险。

## 修复 3：dispose_pagination_session 锁顺序错误 (HIGH)

**位置**：`rust/src/reading/session.rs:255-294`

**Bug**：
```rust
// 修复前
let entry = SESSION_MAP.lock().remove(&session_id)?;
let streamer_key = (entry.file_path, entry.chapter_index, entry.config.config_hash());
STREAMER_CACHE.lock().pop(&streamer_key);
```
**窗口**：SESSION_MAP 移除后、STREAMER_CACHE 弹出前，并发的 `create_pagination_session_adopt(path, chapter, config)` 可能看到 STREAMER_CACHE 仍有该 streamer → 成功 adopt → 创建一个使用已 dispose streamer 的新 session（静默复活）。

**修复**：先 get SESSION_MAP（不删除）→ pop STREAMER_CACHE → remove SESSION_MAP。
```rust
let entry = SESSION_MAP.lock().get(&handle.session_id).cloned()
    .ok_or_else(...)?;
STREAMER_CACHE.lock().pop(&streamer_key);
SESSION_MAP.lock().remove(&handle.session_id);
```
**新顺序保证**：adopt 在 STREAMER_CACHE 弹出后必 miss。

**测试**：`test_dispose_prevents_streamer_adoption` — dispose 后立即 adopt，验证 miss。

## 验证

### 新增测试 (3)
1. `test_repaginate_atomic_old_streamer_evicted` — H1 行为保险
2. `test_paginate_chapter_streamer_cache_reuse` — H2 行为保险
3. `test_dispose_prevents_streamer_adoption` — H3 行为保险

### 回归门禁

| 检查项 | 结果 |
|--------|------|
| `cargo build` (lib) | clean |
| `cargo test --test reading_orchestrator_test` | **10/10 passed** |
| `cargo test --test pagination_session_test` | **16/16 passed** (含 3 个新测试) |
| `cargo test --test epub_reading_chain_test` | 11/11 passed |
| `flutter_rust_bridge_codegen generate` | Done! (无签名变更) |
| `dart analyze lib/src/rust` | No issues found! |

### 测试捕 bug 能力

- **H1**: 单线程下修复前/后均通过（race 在并发下才可见）
- **H2**: 单线程下修复前/后均通过（性能优化，不可观测）
- **H3**: 单线程下可捕（顺序倒置在单线程下也可见——adopt 在 SESSION_MAP.remove 后、STREAMER_CACHE.pop 前能成功）

> 真实价值：H1/H2/H3 主要价值在生产环境多线程下，本测试主要提供行为保险。

## 涉及文件

### Rust 修改 (2)
- `rust/src/reading/session.rs` — H1 (apply_session_repagination lock 合并) + H3 (dispose lock 顺序倒置)
- `rust/src/reading/pagination.rs` — H2 (STREAMER_CACHE 复用)

### 测试新增 (1 文件, 3 用例)
- `rust/tests/pagination_session_test.rs` — 3 个新测试

>## 修复过程副产物 (均已清理)

> H1 修复初版中不慎删除了 SESSION_MAP.insert 导致 `epub_repaginate_font_change` 失败
> — 立即修复并补测。H2 修复初版吃掉了 layout cache 块的 return，临时打补丁后稳定。
> 测试有 2 次构建破坏性调整（`PageDescriptor` 字段为 `start_offset/end_offset`、PaginateResult 在 `domain` 而非 `data_types`），最终 3 个测试都编译通过。

# Plan D 修复 — STREAMER_CACHE cap 提升 (2026-06-17, M7)

## 概览

> 审查（`reading-chain-review` agent, 2026-06-17）识别的 MEDIUM #6 项。`STREAMER_CACHE` LRU cap=4 在 13 个 pagination_session_test 并行下频繁淘汰，导致 4 个测试稳定失败（"NotFound: page streamer for session N"）。baseline 标记为"已知 flake，单线程下通过"。
>
> Plan D：单点修复，零风险，5 分钟。

## 修复

**位置**：`rust/src/reading/streamer_cache.rs:19-25`

**修复前**：
```rust
const STREAMER_CACHE_CAPACITY: NonZeroUsize = match NonZeroUsize::new(4) {
    Some(v) => v,
    None => unreachable!(),
};
```

**修复后**：
```rust
// M7 fix: 4 → 16 匹配 PROVIDER_CACHE。13 个 pagination_session_test
// 并行下 4 不够，频繁 LRU 淘汰导致测试 flake（"NotFound: page streamer
// for session N"）。真实用户多 chapter 翻页同样受益。
const STREAMER_CACHE_CAPACITY: NonZeroUsize = match NonZeroUsize::new(16) {
    Some(v) => v,
    None => unreachable!(),
};
```

## 验证

### 测试结果（**并行**模式，无 `--test-threads=1`）

| 运行 | reading_orchestrator_test | pagination_session_test | epub_reading_chain_test |
|------|---------------------------|-------------------------|-------------------------|
| Run 1 | 10/10 ✅ | 16/16 ✅ | 10/10 ✅ |
| Run 2 | 10/10 ✅ | 16/16 ✅ | 10/10 ✅ |
| Run 3 | 10/10 ✅ | 16/16 ✅ | 10/10 ✅ |

> **修复前**: 并行下 `pagination_session_test` 4/13 稳定失败（4 个 `NotFound: page streamer` flake）。`epub_reading_chain_test` 1/10 flake。
> **修复后**: 3 次连续并行运行，36/36 全部通过，零 flake。

### 内存代价

每 `PageStreamer` 含完整章节 `content: String` + line offsets。16 槽 × ~500KB/章节 ≈ 8MB 峰值。与 `PROVIDER_CACHE` (cap=16) 一致。

## 涉及文件

### Rust 修改 (1)
- `rust/src/reading/streamer_cache.rs` — `STREAMER_CACHE_CAPACITY` 常量 4 → 16（+6/-2）

## 剩余未修

> Plan A/B/D 已修：2 CRITICAL + 3 HIGH + 1 MEDIUM (M7)
> Plan 未修：M6 (lock 内 clone)、M8 (BOOK_ID_CACHE 失效)、M9 (PROVIDER_CACHE format key)、L10-12 (测试改进)

# Plan E 修复 — Reading 链 3 个 MEDIUM (2026-06-17, M6 + M8 + M9)

## 概览

> 审查（`reading-chain-review` agent, 2026-06-17）识别的 3 个 MEDIUM。Plan D (M7) 已修，剩余 3 项一并修。

## 修复 1：STREAMER_CACHE lock 内 deep clone 优化 (M6)

**位置**：
- `rust/src/reading/session.rs:88-114` (`apply_session_repagination` H1 关键段)
- `rust/src/reading/pagination.rs:138-178` (`paginate_chapter` H2 快路径)

**Bug**：`cache.get(&key).cloned()` 在 `MutexGuard` 持有期间做 `PageStreamer` 的 deep clone（整个 content `String` + line_offsets 等）。对 100s KB 章节，并发 reader 阻塞。

**修复**：用 `cache.pop(&key)` 转移所有权（不 clone），计算 descriptors，再 `cache.put` 写回。`SESSION_MAP` 需要的 clone 在 cache lock 外。

```rust
// M6: pop → compute → put back，避免锁内 deep clone
let streamer = {
    let mut cache = STREAMER_CACHE.lock();
    cache.pop(&new_key).ok_or(...)?
};
// ... compute descriptors (no lock) ...
STREAMER_CACHE.lock().put(new_key.clone(), streamer.clone());
// 注：session 仍需 clone → SESSION_MAP。这是一次不可避免的 clone。
```

**trade-off**：pop → put 窗口期内并发 `create_pagination_session_adopt` 可能 miss（短暂的窗口）；两者语义上等价（都是同一章的 streamer）。

**测试捕 bug 能力**：单线程下不可见（性能优化），仅行为保险。

## 修复 2：BOOK_ID_CACHE 失效 (M8)

**位置**：`rust/src/reading/chapter_access.rs:41-90`

**Bug**：`get_chapter_bounds` 命中 `BOOK_ID_CACHE` 后直接用缓存的 book_id 查 `find_by_index`，从不失效。场景：用户重新导入同路径（不同 book_id）后，cache 仍返回旧 book_id → `find_by_index` miss → `ChapterExtractError`，用户必须手动清缓存恢复。

**修复**：`find_by_index` miss 时 `cache.pop(validated_path)`，fall through 到 `find_by_file_path` 重查。

```rust
if let Some(book_id) = cached_book_id {
    if let Ok(Some(chapter)) =
        ChapterRepository::find_by_index(&pool, &book_id, chapter_index).await
    {
        return Ok(...);
    }
    // Miss → invalidate and fall through
    BOOK_ID_CACHE.lock().pop(validated_path);
}
// slow path with find_by_file_path + cache.put
```

**测试**：`test_book_id_cache_invalidation_on_stale_miss`
- 注入 stale book_id → 调用 get_chapter_bounds
- 修复前：失败 (`ChapterExtractError`)
- 修复后：成功，cache 持有 fresh book_id

>**测试能力**：单线程可捕。已验证。

>**API 变更**：`get_chapter_bounds` 从 `pub(crate)` 改为 `pub`（让 integration test 直接调用）；`book_id_cache` 模块 + `BOOK_ID_CACHE` static 同样 `pub(crate)` → `pub`。

>## 修复 3：PROVIDER_CACHE key 加 format (M9)

**位置**：
- `rust/src/reading/provider_cache.rs:34` (CacheKey type)
- `rust/src/reading/provider_cache.rs:65-80` (get_or_create_provider)
- `rust/src/reading/provider_cache.rs:36-58` (get_cached_provider, put_provider)
- `rust/src/storage/models.rs:383-385` (BookFormat derive Hash)

**Bug**：`CacheKey = (String, i32)` 无 `format`。理论场景：同一 path + chapter 不同 format 会撞 cache。实际不会发生（format 由 extension 决定 + 一次写入），但 invariant 隐式。

**修复**：
1. `BookFormat` derive `Hash`（已有 `Copy + PartialEq + Eq`，加 `Hash` 即可）
2. `CacheKey = (String, i32, BookFormat)`
3. `get_or_create_provider` / `get_cached_provider` / `put_provider` 都加 `format` 参数

**API 变更**：
```rust
pub(crate) type CacheKey = (String, i32, BookFormat);  // 旧: (String, i32)

pub(crate) fn get_cached_provider(
    validated_path: &str,
    chapter_index: i32,
    format: BookFormat,  // 新参数
) -> Option<Arc<dyn ChapterContentProvider>>

pub(crate) fn put_provider(
    validated_path: &str,
    chapter_index: i32,
    format: BookFormat,  // 新参数
    provider: Arc<dyn ChapterContentProvider>,
)
```

>**注**：`get_cached_provider` 和 `put_provider` 当前是 `#[allow(dead_code)]` 标记的 helper，未被任何调用方使用（Phase 1 时为未来使用添加的 scaffold）。本 plan 仅给其加了 `format` 参数，无调用点变更。

## 验证

### 测试结果（**并行**模式）

| Suite | 数量 | 结果 |
|-------|------|------|
| reading_orchestrator_test | 11/11 ✅ | 0 flake |
| pagination_session_test | 16/16 ✅ | 0 flake |
| epub_reading_chain_test | 12/12 ✅ | 0 flake |
| **总计** | **39/39** | (含 1 个新 M8 测试) |

>### M8 回归测试捕 bug 能力

> 临时回退 M8 修复：测试 FAIL，错误信息为 `ChapterExtractError { index: 0, reason: "chapter not found in DB" }`。✅ 单线程可捕。

>### 其他验证

| 检查 | 结果 |
|------|------|
| `cargo build` (lib) | clean |
| `flutter_rust_bridge_codegen generate` | Done! |
| `dart analyze lib/src/rust` | No issues found! |

## 涉及文件

### Rust 修改 (5)
- `rust/src/reading/session.rs` — M6: `apply_session_repagination` 用 `pop`+`put` 替代 `get().cloned()` (+12/-3)
- `rust/src/reading/pagination.rs` — M6: `paginate_chapter` H2 fast path 同样改用 `pop`+`put` (+18/-5)
- `rust/src/reading/chapter_access.rs` — M8: `get_chapter_bounds` find_by_index miss 时 invalidate cache + retry (+20/-5)
- `rust/src/reading/provider_cache.rs` — M9: `CacheKey` 加 `BookFormat`；helper fns 加 `format` 参数 (+15/-8)
- `rust/src/storage/models.rs` — M9: `BookFormat` derive `Hash` (+1/-1)
- `rust/src/reading/mod.rs` — `book_id_cache` `pub(crate)` → `pub`（M8 测试需要）
- `rust/src/reading/book_id_cache.rs` — `BOOK_ID_CACHE` static `pub(crate)` → `pub`（M8 测试需要）
- `rust/src/reading/chapter_access.rs` — `get_chapter_bounds` `pub(crate)` → `pub`（M8 测试需要）

### 测试新增 (1 用例)
- `rust/tests/reading_orchestrator_test.rs::test_book_id_cache_invalidation_on_stale_miss` (M8 回归)

## 累计修复状态

| 类别 | 已修 | 未修 |
|------|------|------|
| CRITICAL | 2/2 ✅ | 0 |
| HIGH | 3/3 ✅ | 0 |
| MEDIUM | 4/4 ✅ | 0 |
| LOW | 0/3 | L10, L11, L12 |

### Plan 未修（LOW 测试改进）
- L10: `test_get_chapter_epub_uses_db_bounds` 假阳性（已被新 `test_get_chapter_epub_returns_full_chapter_content` 替代）
- L11: `test_get_page_content_after_dispose_returns_not_found` 命名误导
- L12: `diagnose_content_extraction_pipeline` 语义变更（用 FFI 层更接近用户行为）

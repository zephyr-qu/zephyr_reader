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

---
# pland.md 执行偏差记录

## 最终状态（2026-06-16 二次执行）

PR1（pageContent fetch-on-miss）+ PR2（auto intent）全部落地。

### 已修正的偏差

1. **`get_session_page_content` 同步化** — plan 假设 `Result<String, AppError>` 可通过 FRB 生成同步绑定。
   实际 `#[frb(sync)]` 需返回非 `Result` 类型。
   **方案**：改为返回 `String`，session 不存在时返回空串。

2. **`TypesetConfig.config_hash()` 暴露** — plan 说"无需新增 Rust FFI"。
   实际 FRB 2.x 不暴露 `non_opaque` impl 方法。
   **方案**：新增 `compute_config_hash` standalone fn。

3. **`computeConfigHash` 无法在单测中 mock** — plan 假设可在单测中直接调用。
   实际它调用 FRB，需要运行时初始化。
   **方案**：保留真实调用，configReload 集成测试由 resolver 单测覆盖。

### 验证结果

| 检查项 | 结果 |
|--------|------|
| Rust `cargo test --lib` | 173 passed, 0 failed |
| Dart `dart analyze lib/` | 0 error, 1 info (pre-existing) |
| Flutter `test/features/reader/` | 119 passed, 36 skipped |

### 涉及文件

**Rust (2 文件)**:
- `rust/src/api/core.rs` — `get_session_page_content` sync; `compute_config_hash` 新增

**Dart (15 文件)**:
- `rust_pagination_session.dart` — `_fetchAndCachePage`, `pageContent` fetch-on-miss, 统一预取
- `pagination_session.dart` — `sessionChapterIndex`/`sessionIsPartial` getter
- `reader_repository_interface.dart` — 同上 + staging 方法
- `ReaderRepository` — 代理新字段
- `PaginationCoordinator` — `computeConfigHash()`
- `ChapterLoadRequest` — 移除 intent，`preserveContent` 可空
- `ChapterLoader` / `ChapterViewModel` / `ReaderViewModel` / `reader_content_area` — 移除 intent 参数
- `ChapterLoadOrchestrator` — `resolveIntent()` + `run()` 自动推导 + preserveContent 默认策略
- `README.md` — 更新文档

**Test (2 文件)**:
- `chapter_pagination_intent_resolver_test.dart` — 5 条 resolver 单测
- `chapter_manager_test.dart` — 更新 mock stub，移除 intent 参数

### 未触及的文件（但 stash 中有变更）

以下文件在 stash@{0} 中有变更且已合入当前工作区：
- `next_chapter_staging.dart` — 新增
- `reader_render_data_source.dart` — 新增 `nextChapterStaging` getter
- `rust_chapter_content_repository.dart` — `preloadNextChapterStaging`/`clearNextChapterStaging`
- `chapter_content_repository.dart` — 接口方法
- `chapter_navigator.dart` — staging 预加载路径
- `reader_content.dart` — widget 层预加载
- `AGENTS.md` — 无关改动


---

## 原始偏差记录（初次执行）


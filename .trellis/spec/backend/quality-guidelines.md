# Quality Guidelines

> Code quality standards for backend development.

---

## Overview

<!--
Document your project's quality standards here.

Questions to answer:
- What patterns are forbidden?
- What linting rules do you enforce?
- What are your testing requirements?
- What code review standards apply?
-->

(To be filled by the team)

---

## Forbidden Patterns

<!-- Patterns that should never be used and why -->

(To be filled by the team)

---

## Common Mistakes

### `<span>` 内联容器吞没 `<img>`

**Symptom**: `<span><img src="..." /></span>` 中图片被静默丢失，不产生 `ImageBlock`。

**Cause**: `rich_text.rs` 中两个函数之间缺少图片检测协调：

1. `walk_inline_subtree()` 对 `"span"` arm 调 `collect_text_spans()`，但该函数无 `try_emit_image_paragraph` 调用。
2. `collect_text_spans()` 中 `"img" => {}` 是空分支 — 图片被吞没。

相比之下，`walk_paragraph_children()` 在顶层循环中调 `try_emit_image_paragraph`，所以 `<p><img/></p>` 正常。

**Fix**: 在 `collect_text_spans` 中增加 `<img>` 检测：遇到 `img` 元素时 flush 当前 spans 并 emit `RichParagraph::image_placeholder`。

```rust
// rich_text.rs — collect_text_spans 函数
"img" => {
    let src = get_attribute(attrs, "src").unwrap_or_default();
    let alt = get_attribute(attrs, "alt").unwrap_or_default();
    // flush existing text spans first, then emit image
    paragraphs.push(RichParagraph::image_placeholder(src, alt));
}
```

**Status**: Known — 未修复（Phase 5 bug bash 目标）。

**Related**: `walk_inline_subtree` 的 `try_emit_image_paragraph` 未覆盖通过 `collect_text_spans` 路径的子元素。

---

## Phase 5 完成清单

### #1 — TODO(ponytail) 注释更新 ✅ 已解决

- `rust/src/parser/epub/content_ir.rs:rich_paragraph_style` 的 TODO 已替换为 ADR-015 完成注释。
- 白名单过滤已在 `apply_declaration` 实现（Phase 1），`font_family`/`line_height` 字段已移除（Phase 2）。

### #3 — 容错日志 ✅ 已实施（Phase 5）

### M1 — 可观测性 ✅ 已完成

审计结果：

### M3 — 测试补齐 ✅ 已完成（4 核心场景）

| 场景 | 不变量 | 文件 | 测试数 | 状态 |
| ------ | ------- | ------ | -------- | ------ |
| I3 | Session 全生命周期：partial→expand→dispose | `rust_pagination_session_test.dart` | 1 | ✅ |
| I9 | configHash 变更→descriptors 内部状态更新 | `rust_pagination_session_test.dart` | 1 | ✅ |
| I2 | staging promote 正确设置页码信号 + 失败后保护可见内容 | `chapter_load_orchestrator_test.dart` | 2 | ✅ |
| I4 | calibration 注入→params 包含校准信息 + repaginate 委托 | `pagination_coordinator_test.dart` | 2 | ✅ |

**实现手段**：@visibleForTesting 暴露 `applyPaginateResult` + Mocktail 驱动 Orchestrator/Coordinator 集成测试。

| 文件 | 改动 |
| ------ | ------ |
| `rust_pagination_session.dart` | 新增 `@visibleForTesting applyPaginateResult()` |
| `rust_pagination_session_test.dart` | I3 + I9 测试 |
| `chapter_load_orchestrator_test.dart` | I2 测试（+ GetIt 注册 + pageWidth/Height mock） |
| `pagination_coordinator_test.dart` | I4 测试（+ typeset_calibrator 导入） |

审核结果：

### M4 — 小清理 ✅ 已完成

| # | 项 | 状态 | 说明 |
| --- | ----- | ------ | ------ |
| 5-5 | `chapterHasImageBlocks` 废弃函数 | ✅ 已在 Phase 5 前期删除 | 代码无残留 |
| 5-11 | `BookStatus` 默认值统一 | ✅ 已有 `#[default] Planned` | Rust Default 与 SQL DEFAULT 一致 |
| 5-12 | `paragraphSpacing` 语义标注 | ✅ 已补 | 详注倍数→dp→px 跨层数据流 |
| 5-13 | `_Semaphore` 递归改循环 | ✅ 已是 `while(true)` 循环 | 无需额外改动 |
| 5-14 | sled 容量上限 | ✅ `PAGINATION_ENGINE_CACHE_CAPACITY` 16→32 | LRU 缓存容量调整 |

**改动文件**：`typeset.rs`（doc）/ `pagination_store.rs`（const）

- 全库 `catch (_)` 静默吞错：**0 处**（已在 Phase 4/5 前置工作中清理殆尽）。
- 所有 15 处 `catch (e)` 均有 `Logging.*` 调用。
- `chapter_loader.dart:82` 补充了 `Logging.error(exception: e)`。
- `Logging.error` 结构化形式（`exception:` + `stackTrace:`）覆盖了 annotation/bookmark/loader 路径。
- `Logging.warning` + `$e` 覆盖了 orchestrator/repository 路径。
- 唯一真正缺口 `chapter_loader.dart` 的 `loadChapters()` 已补。

- `rich_text.rs#collect_text_spans`: 为 `img`/`ul`/`ol`/`blockquote`/`pre`/`table` 静默丢弃分支增加 `tracing::trace!(target: "epub.malformed")`。
- `rich_text.rs#traverse_dom`: 为未知块级标签的 `_ => {}` 增加 trace。
- `content_ir.rs#html_to_chapter_ir`: 解析失败时输出输入大小 + 120 字符预览。
- 追踪目标：`epub.malformed`（结构问题）、`epub.css.whitelist`（CSS 丢弃）。

## BlockPaginator 待清理项

### 双轨制简化（P1 — 计划 Phase 2 收尾）

- `visual_line_segments_for_slice` 同时运行 `layout_slice_text_lines`（精确断行）和 `greedy_split_text_lines`（估算）。
- Phase 2 的 `line_break_indices` 路径已绕过此函数。
- `greedy_split_text_lines` 已标记 `#[deprecated(since = "0.9.0")]`，Phase 2 收尾时移除该函数及 `visual_line_segments_for_slice` 的双轨逻辑。
- `visual_line_segments_for_slice` 后续简化为仅调用 `layout_slice_text_lines`。

### 图片 Chunk 保护增强（P3 — 已实施 ✅）

- `paginate_chapter_ir_chunked` 在 GUARD 逻辑后增加了 `MAX_CHUNK_SIZE_HARD=300` 硬性上限。
- 触及上限时输出 `tracing::warn!("[ChunkGuard]")` 用于排查恶意 EPUB。
- CHUNK_BLOCK_COUNT=200、GUARD=5、上限=300，形成了三级防护链。
- 后续修改 GUARD 值时无需担心膨胀失控。

## 已修复项（2026-07-07 代码审查）

### `char_index_at_byte` 线性扫描 → 增量游标

- 函数 `char_index_at_byte` 在断行循环中每行调 2×，对长段落为 O(N×L)。
- 已替换为 `para_indices` 增量游标（O(N) 每段落），原函数已删除。

### `config_hash` 一致性

- `paginate_chapter_ir_chunked` 外层曾直接取 hash，未先 `validate_and_fix`，与内层 path 不一致。
- 已修复：外层也先 `validate_and_fix()` 再 `config_hash()`。

---

## Required Patterns

<!-- Patterns that must always be used -->

(To be filled by the team)

---

## Testing Requirements

<!-- What level of testing is expected -->

(To be filled by the team)

---

## Code Review Checklist

<!-- What reviewers should check -->

(To be filled by the team)

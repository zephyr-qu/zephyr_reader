# Phase 3 退出验收清单

> **状态**：✅ **已退出**（2026-06-24，合入 `master` @ `faa1653`）  
> **来源**：ROADMAP Phase 3 + [PHASE2_EXIT.md](./PHASE2_EXIT.md) Phase 3 backlog  
> **实施分支**：`feat/phase3-partial-block`（自 `master` @ `09e4032`）→ 已归档  
> **关联**：[ROADMAP.md](./ROADMAP.md)、[ADR-003](./adr/003-block-pagination-ir.md)、[ADR-008](./adr/008-ir-image-plain-placeholder.md)

---

## 北极星

| 项 | 要求 |
|----|------|
| **M3.3** | partial 首屏 plain；`expandToFullChapter` 后含图章稳定切 `ContentBlocks` |
| **体验** | 块分页段间距对齐、图片预取、scroll 含图进度映射、大章 IR、跨 session sled 缓存 |
| **ADR-001** | charOffset / plain 真理不变 |
| **不做** | scroll rich 大章分块、PDF 主链、WebView |

---

## P3 backlog

| # | 项 | 状态 | 验收 |
|---|-----|------|------|
| P3-1 | **M3.3** partial → full 切 block | ✅ | `b37d281`；`test_image_chapter_partial_plain_upgrades_to_blocks` |
| P3-2 | **段间距 Rust ↔ Flutter 对齐** | ✅ | `BlockPageContent` + `is_block_end`；Rust/Dart 测试 |
| P3-3 | **图片预取深化** | ✅ | `EpubBlockImageCache` 分级 + 并行 `_prefetchPageBundle` |
| P3-4 | **滚动进度模型** | ✅ | `ScrollLayoutParams` + `itemExtents`；mapper/composer 测试 |
| P3-5 | **大章 chunked IR** | ✅ | spine 分块 + HTML 块边界切片；`content_ir` 单元测试 |
| P3-6 | **sled 分页索引** | ✅ | `block_layout_cache` tree；`epub_block_layout_cache_roundtrip` |

---

## 退出前全绿

- [x] P3-1～P3-6 代码 + 对应 Rust/Dart 测试
- [x] Phase 2 回归：`pagination_session_test`（19）、`epub_reading_chain_test` block cache
- [x] Bugbot 三项 scroll metrics 对齐（`f097190`）
- [x] 合入 `master`（fast-forward `09e4032..faa1653`）

---

## 已知非阻塞遗留（Should / 后续按需）

| 项 | 说明 |
|----|------|
| scroll 大章 rich | 仍 >100KB / >500KB 降级 plain；block/IR 路径已 chunked（P3-5） |
| pageTurn prev 章卷曲 | prev staging 骨架未完整（见 `issue/PLAN_EXECUTION_DEVIATIONS.md`） |
| 极端 fast-flip 图片 | P3-3 基础版；多 `maxWidth` 仍可能 miss |
| 排版细项 | ~~首行缩进 / 部分 CSS → `RichParagraph`~~ ✅ G1+G2 已修复：block `font-size` 贯穿 `RichParagraph` → `TextBlockStyle`(IR) → Flutter 渲染（2026-06-26） |

下一优先级见 [PHASE4_SCOPE.md](./PHASE4_SCOPE.md)（Phase 4 引擎完善）；本章非阻塞遗留部分纳入 P4-1 / P4-3。

---

## Phase 3 完成后

✅ 已合入 `master`。阅读核心 MVP（EPUB/TXT · scroll + pagination · 块分页看图 · staging · sled 缓存）闭环。

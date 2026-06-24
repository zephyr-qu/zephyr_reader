# Phase 2 退出验收清单

> **来源**：ROADMAP Phase 2 + [ADR-003](./adr/003-block-pagination-ir.md)（2026-06-18 已接受）  
> **实施分支**：`feat/phase2-ir`（自 `master` @ `2eebb52`）  
> **关联**：[TARGET_ARCHITECTURE.md](./TARGET_ARCHITECTURE.md)、[DOMAIN_MODEL.md](./DOMAIN_MODEL.md)、[ADR-001](./adr/001-reading-position-truth.md)、[ADR-006](./adr/006-rust-flutter-division.md)、[ADR-007](./adr/007-plaintext-segmentation-stability.md)

---

## 北极星

| 项 | 要求 |
|----|------|
| **ADR-003** | EPUB/TXT → `ContentBlock[]` → `BlockPaginator`；内联图；放不下 → 独占页 |
| **ROADMAP 退出** | **S2**：pagination 下插图 EPUB 可见图；**S3**：书签退出后再开准确恢复 |
| **ADR-001** | `plainText + charOffset` 仍为进度真理；IR 是渲染输入 |
| **ADR-007** | Phase 2 前不改 plain 分段规则；段落间距优先由 IR 表达 |
| **ADR-006** | Rust 算 + 缓存；Flutter 渲染 + staging；与 `PageStreamer` **可并存过渡** |

**不做**：float 绕排、多栏、复杂表格、WebView 分页、在 `PageStreamer` 上堆图片补丁（ADR-003）。

---

## 数据流（目标）

```
解析 → Vec<ContentBlock>（章 IR）
         ↓
BlockPaginator(IR, TypesetConfig) → BlockPageDescriptor[]（块范围 + plain + image_layout）
         ↓
Flutter 按页拉块 → Text + Image（asset 本地路径）
```

---

## 里程碑任务

### M0 — 契约冻结（~3–5 天）

| # | 任务 | 层 | 状态 | 验收 |
|---|------|-----|------|------|
| 0.1 | 定 `ContentBlock` Rust enum（MVP：`Text` + `Image`） | Rust | ✅ | `rust/src/domain/types/content_ir.rs` |
| 0.2 | 定块级 `BlockPageDescriptor`（块 id 范围 + `image_layout`） | Rust | ✅ | `rust/src/domain/types/block_pagination.rs` |
| 0.3 | FRB 导出 + Dart 类型 | FRB/Dart | ✅ | `api/phase2_ir.rs` 锚点 + `lib/src/rust/domain/types/{content_ir,block_pagination}.dart` |
| 0.4 | **ADR-008**：IR ↔ plain 映射（图 = `\uFFFC`） | 文档 | ✅ | [008-ir-image-plain-placeholder.md](./adr/008-ir-image-plain-placeholder.md) |

### M1 — IR 生成（~1–2 周）

| # | 任务 | 层 | 状态 | 验收 |
|---|------|-----|------|------|
| 1.1 | EPUB HTML → IR | Rust | ✅ | `parser/epub/content_ir.rs`；`img` → `asset_id`；DOM 顺序 + ADR-008 plain |
| 1.2 | TXT → IR | Rust | ✅ | `parser/txt/content_ir.rs`；空行分段 → `Text` 块；plain = 章内原文 |
| 1.3 | IR → `plainText` 投影 | Rust | ✅ | `domain/types/plain_projection.rs`；校验 + charOffset/TTS/搜索辅助 |
| 1.4 | 图片 asset 注册表 | Rust | ✅ | `parser/epub/asset_registry.rs`；`asset_id` → manifest id + 包内路径 |
| 1.5 | 单元测试 | Rust | ✅ | `content_ir` 5 项：文+图、heading、offset 单调、ADR-008 不变量 |

### M2 — BlockPaginator MVP（~2–3 周）

| # | 任务 | 层 | 状态 | 验收 |
|---|------|-----|------|------|
| 2.1 | `BlockPaginator` 状态机 | Rust | ✅ | `text/block_paginator.rs`；`remaining_height` 逐块消费 |
| 2.2 | Text 块断行 | Rust | ✅ | 复用 `compute_line_breaks_from_indices` + `TypesetConfig` |
| 2.3 | Image 块布局 | Rust | ✅ | 够高 → contain；否则独占页 |
| 2.4 | 产出 descriptors | Rust | ✅ | 块范围 + plain char 范围 + `image_layouts` |
| 2.5 | 单元测试 | Rust | ✅ | 纯文 / 小图 inline / 大图 full-page |

### M3 — 接入分页 Session（~1–2 周）

| # | 任务 | 层 | 状态 | 验收 |
|---|------|-----|------|------|
| 3.1 | Session 双路径（`PageStreamer` vs `BlockPaginator`） | Rust | ✅ | `ir.image_block_count() > 0` 全章走 block |
| 3.2 | `get_page_blocks`（或扩展 `get_page_content`） | Rust/FRB | ✅ | `get_session_page_blocks` |
| 3.3 | partial 首屏 + `expandToFullChapter` | Rust | ⬜ | partial 仍 plain；expand 全章可切 block |
| 3.4 | `charOffset` → `pageIndex` | Rust/Dart | ✅ | `session_char_offset_to_page_index` |
| 3.5 | 集成测试 | Rust | ✅ | `epub_block_session_with_image` |

### M4 — Flutter 渲染 + 图片管道（~1–2 周）

| # | 任务 | 层 | 状态 | 验收 |
|---|------|-----|------|------|
| 4.1 | 页 Widget 块列表渲染 | Dart | ✅ | `buildBlockPageContent` + `PaginatedModeRenderer` 分支 |
| 4.2 | `get_processed_image(asset_id, width)` | Rust/FRB | ✅ | `get_processed_epub_image` → JPEG 本地路径 |
| 4.3 | 图片懒加载 + 占位 | Dart | ✅ | `EpubBlockImage` 占位 → async decode |
| 4.4 | pagination 路径 `epubRichSkipped` 降级 | Dart | ✅ | `contentBlocks` 时 suppress toast |
| 4.5 | Widget 测试 | Dart | ✅ | mock 块 → 断言 `Icons.image_outlined` |

### M5 — Staging + 场景验收（~1 周）

| # | 任务 | 层 | 状态 | 验收 |
|---|------|-----|------|------|
| 5.1 | staging 缓存 block descriptors | Rust/Dart | ✅ | `NextChapterStaging` + `get_page_blocks` + block 预渲染 |
| 5.2 | `stagingPromote*` 回归 | Dart | ✅ | intent resolver + staging block widget 测试 |
| 5.3 | **S2** 插图 EPUB | 手工+测试 | ⬜ | pagination + `PaginationSkin.curl` 均可见图 |
| 5.4 | **S3** 书签恢复 | 手工+测试 | ⬜ | 杀进程后再开 charOffset 准确 |
| 5.5 | 黄金样章扩展 | Rust | ✅ | `epub_golden_image_chapter_adr007_m55`（活着含图章） |

---

## 依赖顺序

```mermaid
flowchart LR
  M0[M0 契约] --> M1[M1 IR]
  M1 --> M2[M2 BlockPaginator]
  M2 --> M3[M3 Session]
  M3 --> M4[M4 渲染]
  M3 --> M5[M5 Staging]
  M4 --> M5
```

---

## 建议周计划（4–8 周）

| 周 | 聚焦 |
|----|------|
| 1 | M0 + M1.1 EPUB IR + plain 投影 |
| 2 | M1.2 TXT IR + M2.1–2.2 文本块分页 |
| 3 | M2.3–2.5 图片规则 + M3.1–3.2 session 接入 |
| 4 | M4 渲染 + 图片管道 |
| 5 | M5 staging + S2/S3 |
| 6–8 | 缓冲：sled 缓存、大章、scroll/IR 统一（Should，非 MVP） |

---

## Phase 1 交接（保留 vs 替换）

| Phase 1 已有 | Phase 2 用法 |
|--------------|--------------|
| 5 intent + orchestrator | **保留**；分页输入改 IR |
| `PaginationSkin` / `PageTurnShell` | **保留**；页内容从 plain 串 → 块列表 |
| staging forward/backward | **保留**；缓存 block descriptors |
| 全文 plain 后再索引 | **保留**（ADR-001） |
| `PageStreamer` | **过渡**；有图 EPUB 走 `BlockPaginator` |

---

## 待拍板（M0 前）

~~**图在 `plainText` 里如何表示？**~~ → **已接受 [ADR-008](./adr/008-ir-image-plain-placeholder.md)**：每 `Image` 块 1 个 `\uFFFC`；TTS 读 IR `alt`；搜索忽略占位符。

---

## 退出前必须全绿

- [ ] **M0–M2** Rust：`ContentBlock` + `BlockPaginator` 单元/集成测试通过
- [ ] **M3–M4** 分页 session 走 IR；Flutter pagination 可渲染内联图与独占页
- [ ] **M5 / S2** 插图 EPUB 在 pagination（slide + curl）下可见图
- [ ] **M5 / S3** 书签 charOffset 杀进程后恢复准确
- [ ] **staging** `stagingPromote*` + 虚拟页 widget 测试不退化
- [ ] **`dart analyze`** reader 无 error；`cargo clippy -- -D warnings`（改动模块）
- [ ] **ADR-007** 黄金样章扩展（含图章）或等价 fixture 文档

---

## Phase 2 完成后

进入 [Phase 3](./ROADMAP.md)（预取强化、图片管道深化、大章 chunked IR）；**不**在 Phase 2 做 PDF 主链 / WebView。

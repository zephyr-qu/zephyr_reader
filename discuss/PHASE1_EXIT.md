# Phase 1 退出验收清单

> **来源**：ROADMAP Phase 1 + [xinxi-round4.md](./xinxi-round4.md)（2026-06-18 确认）  
> **基线提交**：`feat/simplify` @ `527354d`

---

## ROADMAP 任务

| # | 任务 | 状态 | 验收依据 |
|---|------|------|----------|
| 1.1 | 合并 load / firstSpine / plain 并行 | ✅ 已做 | Dart 去掉 `loadChapterFirstSpine`；`chapterPlainFuture` 与校准并行（非旧版 contentFuture 早索引）；finalize 写 full plain |
| 1.2 | 全文 plain 后再 TTS / 搜索 | ✅ 已做 | `_postLoadTasks` 在 finalize 之后 |
| 1.3 | 分页 gate EPUB rich | ✅ 已做 | `_needsRichContent` 仅 scroll/bilingual |
| 1.4 | Intent 文档化 + 路径收敛 | ✅ | [INTENTS.md](./INTENTS.md)；5 intent；resolver + `_runCalibratedPartialPaginate` |
| 1.5 | pageTurn 皮肤（代码 + 枚举） | ✅ | [ADR-002](./adr/002-pageturn-is-pagination-skin.md)；`PaginationSkin`；`PageTurnShell`；`PaginatedModeRenderer` 统一 curl / slide |
| 1.6 | 分页 EPUB 插图 toast | ✅ 可选保留 | `ReaderNotice.epubRichSkipped`（分页不触发 rich） |

**附加（simplify）**：主链移除 PDF/MD；删除 `paginateApproximate`。

---

## 诚实债务清理（Phase 1 后补，@ `527354d`）

> 「文档说完成 ≠ 零冗余」— 下列项在 Phase 1 结论不变前提下已落地。

| 项 | 处理 |
|----|------|
| `loadChapterFirstSpine` Dart 死 API | 从 `ChapterContentRepository` / `ReaderRepositoryInterface` / `RustReaderRepository` 删除；Rust `get_chapter_first_spine_only` 保留（测试 / 底层） |
| `contentFuture` 命名 | → `chapterPlainFuture`（语义：全文加载与首屏分页并行，非禁止并发） |
| `buildSinglePageContent` 重复 | `_buildPageContent` 委托 `buildSinglePageContent`；生产路径去重 |
| `ReadingMode.pageTurn` | 枚举删除 → `PaginationSkin` + `reading_mode_utils.dart`；设置 UI 四选项保留 |
| Rust PDF 注释残留 | `storage/models.rs`、`cover.rs`、`error.rs`、`orchestrator.rs` 注释更新 |

---

## R4 冻结决策

| 题 | 决策 | 文档 |
|----|------|------|
| R4-1 plain 分段 | 维持单 `\n`；Phase 2 前不改 | [ADR-007](./adr/007-plaintext-segmentation-stability.md) |
| R4-2 验收 | Rust fixture 测试 + 1 本 EPUB 样章 | ADR-007 |
| R4-3 pageTurn | `PageTurnShell` + `PaginationSkin.curl`；staging 虚拟页零改动 | ADR-002 + 1.5 |
| R4-4 设置重载 | pagination（slide / curl）共用 `configReload` | [INTENTS.md](./INTENTS.md) |
| R4-5 intent | 保留 5 个 + 文档；staging 分 forward/backward | [INTENTS.md](./INTENTS.md) |
| R4-6 Rust 取消 | Phase 1 不做；Dart `_generation` 足够 | — |
| R4-7 首屏交互 | 允许当前页 `pageContent` 选择；进度 finalize 后持久化 | ADR-001 |
| R4-8 加分项 | 不做 ContentBlock 预定义；不做分页埋点枚举 | — |

---

## 退出前必须全绿

- [x] **1.5** `PageTurnShell` 落地；`PaginationSkin` 枚举迁移；staging 虚拟页经 `PaginatedModeRenderer` 共用 builder
- [x] **诚实债务** §上表五项（@ `527354d`）
- [x] **ADR-007** Rust `html_to_plain_text` 单元测试（16 项，`cargo test --lib parser::epub::provider::tests`）
- [x] **ADR-007** 1 本复杂 EPUB 样章：`活着.epub` ch.0 + [007-epub-golden-verification.md](./adr/007-epub-golden-verification.md)
- [x] **staging 换章**（G2-b）：intent `stagingPromote*` + `reader_content_test` / `PageTurnShell` 虚拟页 widget 覆盖
- [x] **`dart analyze`** reader 模块无 error；`chapter_manager_test` / `reader_content_test` / `paginated_renderer_test` 通过

---

## Phase 1 完成后

进入 [Phase 2](./ROADMAP.md)（IR + `BlockPaginator`）；**不**在 Phase 1 引入半套 IR。

**合流提醒**：`feat/simplify` 自 `fix` @ `7648036` 分叉，尚未合入 `fix` / `master`（见分支图）。

---

## 建议实现顺序（剩余）

**Phase 1 可关闭** → 合入 `fix` → 进入 [Phase 2](./ROADMAP.md)（IR + `BlockPaginator`）。

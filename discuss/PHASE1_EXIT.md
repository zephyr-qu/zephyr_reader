# Phase 1 退出验收清单

> **来源**：ROADMAP Phase 1 + [xinxi-round4.md](./xinxi-round4.md)（2026-06-18 确认）  
> **基线提交**：`feat/simplify` @ `05ecabf`

---

## ROADMAP 任务

| # | 任务 | 状态 | 验收依据 |
|---|------|------|----------|
| 1.1 | 合并 load / firstSpine / contentFuture | ✅ 已做 | 去掉 `loadChapterFirstSpine`；无 parallel 早索引；finalize 写 full plain |
| 1.2 | 全文 plain 后再 TTS / 搜索 | ✅ 已做 | `_postLoadTasks` 在 finalize 之后 |
| 1.3 | 分页 gate EPUB rich | ✅ 已做 | `_needsRichContent` 仅 scroll/bilingual |
| 1.4 | Intent 文档化 + 路径收敛 | ✅ | [INTENTS.md](./INTENTS.md)；5 intent；resolver + `_runCalibratedPartialPaginate` |
| 1.5 | pageTurn 皮肤（代码） | ✅ | `PageTurnShell`；`PaginatedModeRenderer` 统一 pageTurn / pagination |
| 1.6 | 分页 EPUB 插图 toast | ✅ 可选保留 | `ReaderNotice.epubRichSkipped`（分页不触发 rich） |

**附加（simplify）**：主链移除 PDF/MD；删除 `paginateApproximate`。

---

## R4 冻结决策

| 题 | 决策 | 文档 |
|----|------|------|
| R4-1 plain 分段 | 维持单 `\n`；Phase 2 前不改 | [ADR-007](./adr/007-plaintext-segmentation-stability.md) |
| R4-2 验收 | Rust fixture 测试 + 1 本 EPUB 样章 | ADR-007 |
| R4-3 pageTurn | `PageTurnShell` 解耦；staging 虚拟页零改动 | ADR-002 + 1.5 |
| R4-4 设置重载 | pagination / pageTurn 共用 `configReload` | [INTENTS.md](./INTENTS.md) |
| R4-5 intent | 保留 5 个 + 文档；staging 分 forward/backward | [INTENTS.md](./INTENTS.md) |
| R4-6 Rust 取消 | Phase 1 不做；Dart `_generation` 足够 | — |
| R4-7 首屏交互 | 允许当前页 `pageContent` 选择；进度 finalize 后持久化 | ADR-001 |
| R4-8 加分项 | 不做 ContentBlock 预定义；不做分页埋点枚举 | — |

---

## 退出前必须全绿

- [x] **1.5** `PageTurnShell` 落地，staging 虚拟页经 `PaginatedModeRenderer` 共用 builder
- [x] **ADR-007** Rust `html_to_plain_text` 单元测试（16 项，`cargo test --lib parser::epub::provider::tests`）
- [x] **ADR-007** 1 本复杂 EPUB 样章：`活着.epub` ch.0 + [007-epub-golden-verification.md](./adr/007-epub-golden-verification.md)
- [x] **staging 换章**（G2-b）：intent `stagingPromote*` + `reader_content_test` / `PageTurnShell` 虚拟页 widget 覆盖
- [x] **`dart analyze`** reader 模块无 error（2026-06-18）；widget 测试需本机 Flutter/Dart SDK 对齐

---

## Phase 1 完成后

进入 [Phase 2](./ROADMAP.md)（IR + `BlockPaginator`）；**不**在 Phase 1 引入半套 IR。

---

## 建议实现顺序（剩余）

**Phase 1 可关闭** → 进入 [Phase 2](./ROADMAP.md)（IR + `BlockPaginator`）。

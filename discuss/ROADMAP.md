# 阅读核心路线图（与边界 v1.1 绑定）

> **当前阶段 = Phase 1**（R4 已确认，见 [xinxi-round4.md](./xinxi-round4.md)）

---

## Phase 0 — 冻结边界与架构 ✅ 已完成

- [x] `READING_BOUNDARIES.md` v1.1
- [x] ADR-001 ~ 006
- [x] `DOMAIN_MODEL.md`、`TARGET_ARCHITECTURE.md`、`DECISIONS.md`
- [x] `xinxi-round3.md`：R3-1、R3-2 确认

**验收一句话**：进度存 charOffset；正文以 plain 为锚；分页目标吃 IR；staging 只负责换章快。

---

## Phase 1 — 瘦身现有链（进行中）

**目标**：减冗余、单 plain 真理；**不**做块分页；**不**砍 staging。

| # | 任务 | 状态 | 验收 |
|---|------|------|------|
| 1.1 | 合并 `loadChapterContent` / firstSpine / contentFuture | ✅ | [PHASE1_EXIT.md](./PHASE1_EXIT.md) |
| 1.2 | 全文 plain ready 后再 TTS / 搜索索引 | ✅ | finalize 后 `_postLoadTasks` |
| 1.3 | 分页路径 gate EPUB rich | ✅ | `_needsRichContent` |
| 1.4 | Orchestrator intent 文档化 | ✅ | [INTENTS.md](./INTENTS.md)（代码保留 5 intent） |
| 1.5 | pageTurn 皮肤（代码） | ⬜ | `PageTurnShell`；ADR-002 + R4-3 |
| 1.6 | 分页 EPUB toast（可选） | ✅ | `epubRichSkipped` |

**R4 追加**：主链 EPUB+TXT（PDF/MD 已剥离）；[ADR-007](./adr/007-plaintext-segmentation-stability.md) plain 稳定；首屏可用 `pageContent` 交互（R4-7）。

**退出标准**：[PHASE1_EXIT.md](./PHASE1_EXIT.md) 全绿；staging 换章仍丝滑。

**剩余顺序**：plain 测试 → PageTurnShell → EPUB 样章核对。

---

## Phase 2 — IR + 块分页 MVP（~4–8 周，ADR-003）

EPUB 分页内联图 + 大图独占页；`BlockPaginator`；charOffset 兼容 ADR-001。

**退出标准**：S2 插图 EPUB 在 pagination 下可见图；S3 书签恢复。

---

## Phase 3 — 体验与缓存（有余力）

预取强化、图片管道、大章 chunked IR。

---

## 不做

PDF 主链、WebView、账号同步、双语主链重构。

# 阅读核心路线图（与边界 v1.1 绑定）

> **当前阶段 = Phase 1**（Phase 0 已于 2026-06-18 闭环）

---

## Phase 0 — 冻结边界与架构 ✅ 已完成

- [x] `READING_BOUNDARIES.md` v1.1
- [x] ADR-001 ~ 006
- [x] `DOMAIN_MODEL.md`、`TARGET_ARCHITECTURE.md`、`DECISIONS.md`
- [x] `xinxi-round3.md`：R3-1、R3-2 确认

**验收一句话**：进度存 charOffset；正文以 plain 为锚；分页目标吃 IR；staging 只负责换章快。

---

## Phase 1 — 瘦身现有链（当前，~2 周）

**目标**：减冗余、单 plain 真理；**不**做块分页；**不**砍 staging。

| # | 任务 | 验收 |
|---|------|------|
| 1.1 | 合并 `loadChapterContent` / firstSpine / contentFuture 语义 | 换模式不三套并行读章 |
| 1.2 | 全文 plain ready 后再 TTS / 搜索索引 | 无 partial 朗读 |
| 1.3 | 分页路径 gate EPUB rich | 分页不拉 `getEpubChapterRichContent` |
| 1.4 | Orchestrator intent 收敛并文档化 | 新 intent 须 ADR |
| 1.5 | pageTurn 合并 pagination 皮肤（代码） | ADR-002 落地 |
| 1.6 | 块分页未就绪前保留分页 EPUB toast（可选） | 用户知情 |

**退出标准**：Phase 1 验收表全绿；staging 换章仍丝滑。

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

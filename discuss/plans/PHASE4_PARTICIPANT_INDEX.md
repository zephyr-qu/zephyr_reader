# Phase 4 — 可并行参与任务索引

> **主线程（Agent）**：P4-1 Scroll → Chunked IR · P4-2 IR 块 CSS · P4-4 Metrics 回传  
> **参与线程（你）**：下列低耦合、边界清晰、可独立 PR 的任务  
> **真理源**：[PHASE4_SCOPE.md](../PHASE4_SCOPE.md) · [READING_BOUNDARIES.md](../READING_BOUNDARIES.md) v1.2

---

## 怎么选任务

| 适合你先做 | 原因 |
|------------|------|
| 不动 Rust IR / FRB | 减少与主线程冲突 |
| 有明确「完成/未完成」验收 | 不依赖 P4-1 落地 |
| 1 个 PR 可合 | 便于 review |

| 建议等主线程 | 原因 |
|--------------|------|
| P4-2 块 CSS 实现 | 依赖 `ContentBlock` 字段扩展（主线程改 Rust） |
| Scroll 渲染改 IR | 即 P4-1 本体 |

---

## 任务清单（由易到难）

| # | 任务 | 计划文档 | 估时 | 冲突风险 |
|---|------|----------|------|----------|
| **T1** | 跨章 `[Timing]` 诊断日志 | [plan-p4-cross-chapter-timing.md](../../doc/plan-p4-cross-chapter-timing.md) | 0.5d | 低 |
| **T2** | 文档债务清理（PDF/过时索引） | [plan-p4-doc-debt-cleanup.md](../../doc/plan-p4-doc-debt-cleanup.md) | 0.5d | ✅ 已完成 |
| **T3** | 过时差距分析文档修订 | [plan-p4-gap-analysis-refresh.md](../../doc/plan-p4-gap-analysis-refresh.md) | 0.5d | 无 |
| **T4** | Staging 零可见 loading（ADR-012） | [plan-p4-3-staging-zero-loading.md](../../doc/plan-p4-3-staging-zero-loading.md) | 1–2d | 中（`paginated_renderer`） |
| **T5** | `PaginatedModeRenderer` staging 单测补强 | [plan-p4-staging-widget-tests.md](../../doc/plan-p4-staging-widget-tests.md) | 1d | ✅ 已完成 |
| **T6** | `PLAN_EXECUTION_DEVIATIONS` 状态同步 | [plan-p4-deviations-refresh.md](../../doc/plan-p4-deviations-refresh.md) | 0.5d | 无 |

**推荐起步顺序**：T2 → T1 → T5 → T4（T4 与主线程可能碰同一文件，先沟通或等 T5 测好再改 UI）

---

## PR 约定

- 分支名：`feat/p4-t{N}-简短描述`（例 `feat/p4-t1-timing-logs`）
- 每个 PR 只做一个 T 任务
- 合并前：`dart analyze --fatal-infos`（改 Dart）或仅文档则无命令
- 在 PR 描述里链到对应 plan MD

---

## 主线程进度（Agent 维护）

| 项 | 状态 | 说明 |
|----|------|------|
| P4-1 Scroll → IR | 🚧 进行中 | 见 [plan-p4-1-scroll-ir-unification.md](../../doc/plan-p4-1-scroll-ir-unification.md) |
| P4-2 IR 块 CSS | ⬜ 排队 | 依赖 P4-1 块加载路径 |
| P4-4 Metrics 回传 | ⬜ 排队 | 独立 Rust+FRB，主线程第二阶段 |
| P4-5 双语 feature 模块 | ⬜ 排队 | 可与 T4 并行，但改动面大 |

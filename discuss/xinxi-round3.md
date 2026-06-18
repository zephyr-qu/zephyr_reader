# 第三轮 — 只剩 2 题（ADR-001 讲解后确认）

> 读完 [adr/001-reading-position-truth.md](./adr/001-reading-position-truth.md) 的「通俗解释」再勾。

***

## R3-1 — 采纳 ADR-001？

- [x] **是**：进度/书签/笔记只用 `chapterIndex` + `charOffset`（plainText 内）
- [ ] **否**：我认为应该 \_\_\_\_\_\_\_\_\_\_

***

## R3-2 — Rust / Flutter 分工（G7）

读完 [TARGET\_ARCHITECTURE.md](./TARGET_ARCHITECTURE.md) §1：

- [x] **采纳**：Rust = IR + 块分页 + 缓存；Flutter = 渲染 + staging 触发（appendix01 路线）
- [ ] **暂缓**：维持现状分工，Phase 2 再议
- [ ] **其他**：\_\_\_\_\_\_\_\_\_\_

***

*✅ 已确认（2026-06-18）→ 边界 v1.1 闭环，Phase 0 结束。进入 [Phase 1](./ROADMAP.md)。*

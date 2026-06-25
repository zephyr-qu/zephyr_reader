# 第五轮 — Phase 4 引擎完善（grilling 归档）

> **日期**：2026-06-25  
> **产出**：[PHASE4_SCOPE.md](./PHASE4_SCOPE.md) · ADR-009～013 · READING_BOUNDARIES v1.2

---

## D1 — 四周主线

- [x] **B** 核心引擎完善（非 Should 产品功能、非 Won't 扩 scope）

---

## D2 — PDF

- [x] **A** 贯彻 Won't；现有阶段完全不考虑 PDF 阅读；更新 README 等删除相关条目

---

## D3 — 同步

- [x] **A** Won't 不变；WebDAV 视为备份/手动工具，非产品级多端同步承诺

---

## D4 — 章内搜索

- [ ] **A** 阅读器内浮层  
- [ ] **B** 章内 + next/prev  
- [x] **C** 不做；全书搜索已覆盖章内需求

---

## D5 — Scroll 大章富文本

- [ ] **A** 接受 plain 降级  
- [x] **B** Scroll 也走 Chunked IR（消除双真理源）  
- [ ] **C** 自动切 pagination

**理由（摘要）**：Pagination 已证 IR 可行；全应用单一内容表示；Rust 图片/样式/懒加载只写一次。

---

## D6 — 排版 CSS 范围

- [ ] **A** 仅 scroll + bilingual  
- [x] **B** A + 块分页 Text 块同样投射  
- [ ] **C** 不做

**理由（摘要）**：消除 scroll ↔ pagination 模式割裂；为双语分页铺路；Rust 生成 ContentBlock 时附带样式成本低。

---

## D7 — 双语架构（关闭 G4-c）

- [ ] **A** in-tree 可选（现状）  
- [x] **B** 独立 feature 模块，主链零依赖  
- [ ] **C** 隐藏/冷冻

---

## D8 — 跨章验收

- [ ] **A** 功能有即可  
- [ ] **B** 真机 <50ms  
- [x] **C** prev/next staging **不允许** loading spinner

---

## D9 — 引擎精度

| 项 | 决策 |
|----|------|
| Lazy 标点挤压 | 接受 by design |
| CharWidthTable 漂移 | Flutter Metrics 回传（初筛 Rust + 校准 Flutter） |
| Rust 任务取消 | 仍不做 |

---

## D10 — 文档真理源

- [x] **A** READING_BOUNDARIES + ADR；README / DOMAIN_MODEL / glossary 一次性对齐  
- [ ] **B** 以 README 为准  
- [ ] **C** 分叉维护

---

## D11 — 「版式像原书」

- [x] **窄义**：font-family、text-indent、段间距、行高、基础强调、图片位  
- [ ] **广义**（多栏/float/复杂表格 — 维持 Won't）

# ADR-003：分页必须支持 EPUB 内联图 — 统一 IR + 块分页

- **状态**：已接受（G1-b，2026-06-18）
- **日期**：2026-06-18

## 决策

1. EPUB/TXT 在 Rust 侧归一为 **ContentBlock 流（IR）**，再交给块分页引擎。
2. 图片块规则（与你在 round2 写的「主流行为」一致）：
   - 内联图按流插入；
   - 剩余页高足够 → 缩放 contain 插入；
   - 否则 → **独占一页**（全屏图）。
3. 不支持：float、多栏、复杂表格（已在 Won't）。
4. 工期预期：**4–8 周**；在 [TARGET_ARCHITECTURE.md](../TARGET_ARCHITECTURE.md) 分阶段交付，**不**与「文档冻结周」并行大改。

## 理由

- 问卷：分页看图 = Must；收集的主流行为为内联 + 跨页缩小/独占。
- 现有 plain `PageStreamer` 无法表达图片块，继续 patch 只会更臃肿。
- appendix01/02 的 IR 路线与 FRB 职责划分一致。

## 后果

- **接受**：Phase 文档周几乎不改实现代码；下一实施阶段以 IR 为主战场。
- **拒绝**：在现有 PageStreamer 上 `warmPageCache` 式补丁当长期方案。
- **暂缓**：块分页完成前，可保留 scroll 看图 + 分页 toast 作**临时**行为（实现若仍存在）。

## 关联

- appendix01、appendix02
- [ROADMAP.md](../ROADMAP.md) Phase 2

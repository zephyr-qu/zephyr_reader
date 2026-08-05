# ADR-004：跨章换章保持零感知 loading — 保留 staging

- **状态**：已接受（G2-b，2026-06-18）
- **日期**：2026-06-18

## 决策

1. 分页 / pageTurn 模式下，**保留**相邻章 staging 预取（next 首页、prev 末页）。
2. 换章体验目标：用户感知为「连续翻页」，而非等待整章 load 完成。
3. 「架构简化」指：**删减重复加载、合并 intent**，不是删除 staging。

## 理由

- 第二轮明确：换章不应明显 loading，这是阅读器基本体验。
- appendix03：离线阅读器应用 **预取** 换 CPU，性价比高于砍 staging 后暴露 loading。

## 后果

- Orchestrator 可简化 intent 数量，但 **staging promote 能力保留或等价替代**（预取 + 快速 promote）。
- 文档/实现须写清：staging 是**性能层**，不是第二套章节真理（内容仍以 IR/plain 为准）。

## 关联

- [READING_BOUNDARIES.md](../READING_BOUNDARIES.md)
- ADR-001（进度仍用 charOffset，不用 staging 页码持久化）

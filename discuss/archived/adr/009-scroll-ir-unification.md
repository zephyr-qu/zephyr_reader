# ADR-009：Scroll 模式统一走 Chunked IR

- **状态**：已接受（D5，2026-06-25）
- **日期**：2026-06-25

## 决策

1. **Scroll 与 pagination 共用同一 IR 源**：章节加载产出 `Vec<ContentBlock>`（含 chunked 大章路径，P3-5）；scroll **不再**维护独立的 plain/rich 双渲染管线作为主路径。
2. Scroll 视口进度：由 IR 块 `char_offset` 映射到 `ReadingPosition`（ADR-001 不变；`plainText` 仍为持久化锚点）。
3. 过渡期允许保留 `RichParagraph` 回退路径，但 **Phase 4 退出时必须移除** scroll 对大章 `epubRichSkipped` plain 降级的依赖。

## 理由

- Phase 2 后 pagination 已证 IR 可行；scroll 仍走 plain/rich 造成**双真理源**与重复的图片/样式逻辑。
- 离线场景下 Rust 层统一懒加载、样式解析，Flutter 只负责按块渲染。
- 用户决策：消除模式割裂，长期代码复用 > 短期迁移成本。

## 后果

- **接受**：`ScrollBoundaryCoordinator` / `ScrollChapterSegment` 演进为 IR 块序列或 IR 投影段。
- **拒绝**：scroll 永久依赖 `html5ever → RichParagraph` 与大章 plain 降级。
- **不变**：TTS / 全书搜索 / 书签仍锚 `plainText`（I1、I2）。

## 关联

- [ADR-003](./003-block-pagination-ir.md)、[PHASE4_SCOPE.md](../PHASE4_SCOPE.md) P4-1
- [DOMAIN_MODEL.md](../DOMAIN_MODEL.md) I6

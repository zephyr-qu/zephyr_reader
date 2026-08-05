# ADR-007：plainText 分段规则冻结与 charOffset 稳定性

- **状态**：**已接受**（2026-06-18，R4-1 / R4-2 确认）
- **日期**：2026-06-18
- **背景**：appendix04 风险 A；ADR-001 要求进度锚在 `plainText`。

## 决策

1. **Phase 1 ~ Phase 2 前**：EPUB→plain 维持现有 `html_to_plain_text` 规则——块级标签产 **单 `\n`**，再经 `clean_whitespace` 整理；**不**改为 `\n\n` 或按标签分级间距。
2. **charOffset 绝对稳定**：坐标单位固定为 UTF-16 code unit（[ADR-017](./017-reading-offset-utf16-contract.md)）；不得在无版本迁移的情况下静默改变 plain 编码规则；已存书签/进度/笔记偏移必须可复现。
3. **验收**：Rust 单元测试（HTML fixture）+ 至少 1 本结构复杂 EPUB 黄金样章人工核对（R4-2 A+B）。记录见 [007-epub-golden-verification.md](./007-epub-golden-verification.md)。
4. **Phase 2 预留**：视觉段落间距改由 **ContentBlock / IR** 表达；是否调整 plain 与 IR 的映射在 Phase 2 单独立项，须新 ADR + 迁移策略。

## 理由

- 改 `\n\n` 会偏移既有 `charOffset`，违背 ADR-001 用户预期。
- 单 `\n` 已覆盖块级边界；过早在 plain 层追求「排版观感」会污染进度真理源。
- 单元测试 + 真实 EPUB 样章是性价比最高的回归门禁。

## 后果

- 分页模式下段落间距主要靠排版引擎，不靠 plain 双换行。
- 若未来必须改编码：须 `plainTextVersion` 或重导书籍，并在 [glossary.md](../glossary.md) 注明。

## 关联

- [ADR-001](./001-reading-position-truth.md)
- [ADR-003](./003-block-pagination-ir.md)
- 实现：`rust/src/parser/epub/provider.rs` → `html_to_plain_text`

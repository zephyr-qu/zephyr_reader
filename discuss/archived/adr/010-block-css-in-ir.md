# ADR-010：IR Text 块携带基础排版 CSS

- **状态**：已接受（D6 + D11 窄义，2026-06-25）
- **日期**：2026-06-25

## 决策

1. `ContentBlock::Text` 携带**基础块级样式**（至少）：`text_indent`、`margin_top/bottom`（或等价 padding）、`font_family` 提示、行内强调（已有 span 层）。
2. **Scroll 与 pagination（块分页）必须从同一 IR 字段投射**，用户切换模式时段落缩进/段距不得消失。
3. **「版式像原书」采用窄义**（D11）：
   - **包括**：字体族、段首缩进、段间距、行高、加粗/斜体/下划线/颜色、图片在流中的位置。
   - **不包括**（维持 Won't）：多栏、float 绕排、复杂表格、绝对定位、背景纹理。

## 理由

- 分页已吃 IR；若 scroll 有样式而 pagination Text 块无样式，模式切换体验割裂。
- 双语（ADR-011）在分页下依赖块级样式，否则对照排版不可用。
- Rust 解析 HTML 时已部分读取 CSS；写入 IR 字段成本低于 Dart 侧补丁。

## 后果

- **接受**：扩展 `ContentBlock` / FRB 类型；Flutter `buildBlockPageContent` 与 scroll 块渲染共用样式映射。
- **拒绝**：scroll 走 `RichParagraph` CSS、pagination 走无样式 plain 的长期双轨。
- **范围外**：完整 CSS 引擎、用户自定义 CSS 文件。

## 关联

- [ADR-003](./003-block-pagination-ir.md)、[issue/FINE_TYPESETTING_GAP.md](../../issue/FINE_TYPESETTING_GAP.md)
- [PHASE4_SCOPE.md](../PHASE4_SCOPE.md) P4-2

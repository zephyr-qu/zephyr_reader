# 排版差距分析 — 双语小说阅读器

> 审查日期: 2026-06-26
> 产品目标：中英双语**小说**离线阅读。不追求多看级通用 EPUB 精排。
> 当前小说场景覆盖约 **75%**（基础样式 + 纯文本分页 + 滚动/双语富文本）；剩余可做工约 **1–2d**。

## 当前已有（小说场景够用）

| 能力 | 状态 | 链路 |
|------|------|------|
| 粗体/斜体/下划线 | ✅ | `html5ever` → `RichTextConverter` |
| 标题 | ✅ | `heading_level` |
| 行内颜色/字号 | ✅ | 内联 CSS |
| 文本对齐 | ✅ | `text_align` |
| 段落/列表（纯文本） | ✅ | DOM 遍历 → 纯文本流出 |
| 分页排版（TXT/EPUB 正文） | ✅ | `PageStreamer` + `PaginationSession` |
| 滚动模式富文本 | ✅ | EPUB/MD → `ScrollModeRenderer` |
| 双语对齐 / 对照高亮 | ✅ | `align_bilingual_content` + Translation VM |

---

## 值得做的差距（按优先级）

### P1 — 段落排版 CSS 投射到 Dart（~1–2d）

Rust 侧 CSS 解析已完整（`rust/src/text/rich_text.rs`），以下属性已解析到 `RichParagraph` 字段：

| `RichParagraph` 字段 | 来源 CSS | Dart 使用状态 |
|----------------------|----------|--------------|
| `text_indent_em` | `text-indent` | ❌ `RichTextConverter.paragraphBlockStyle` 未处理 |
| `margin_top_em` / `margin_bottom_em` | `margin-top` / `margin-bottom` | ❌ 同上 |
| `font_family` | `font-family` | ❌ 同上 |
| `line_height` | `line-height` | ✅ 已在 `paragraphBlockStyle` 使用 |

**瓶颈在 Dart 侧**：当前 `toTextSpan` 将所有段落压平到一个 `TextSpan` 树。实现块级属性（text-indent、margin）需要将输出从单一 `TextSpan` 改为 `WidgetSpan` 或外层 `Column` + `Padding` 包裹的结构。

改动面：

- `lib/features/reader/data/rich_text_converter.dart` — `paragraphBlockStyle` 投射 `font_family` / `text_indent_em`；`toTextSpan` 输出改为 `List<InlineSpan>` 或段落级 widget 列表
- 消费方（`ScrollModeRenderer`）适配新输出格式；双语模式走独立链路，不受影响

**不涉及** `PageStreamer` 改造，仅滚动/双语渲染链路。

### P2 — 双语模式与富文本一致性（~0.5d，按需）

双语渲染器（`BilingualModeRenderer`）使用 `BilingualAlignment` 纯文本段落，不走 `RichParagraph` / `RichTextConverter`。当前双语模式与滚动富文本模式的样式由各自独立链路控制：

- 滚动模式：`RichParagraph` → `RichTextConverter.toTextSpan`
- 双语模式：`BilingualAlignment`（plain text segments）→ `HighlightPainter.paintPlain`

P1 对 `RichTextConverter` 的改动不会自动惠及双语模式。如需双语段落样式与滚动模式一致，需额外实现双语侧的段落样式投射。

---

## 实施路径

```
Phase 1（1–2d）— 段落 CSS 投射到 Dart
  lib/.../rich_text_converter.dart
    - paragraphBlockStyle: 加 font_family / text_indent_em
    - toTextSpan: 输出段落级 List<InlineSpan> 或 widget 列表
  验收：带 text-indent 的 EPUB 段落首行缩进正确；段间距可见

Phase 2（按需，~0.5d）— 双语模式段落样式
  BilingualModeRenderer 接入段落样式投射（独立于 RichTextConverter）
  验收：bilingual 段落 text-indent / 段间距与 scroll 一致
```
**架构影响：低。** `toTextSpan` 返回类型可能从 `(TextSpan, String)` 变为 `(List<InlineSpan>, String)` 或段落级 widget 列表。不改动 `PageStreamer`。

---

## 总结

| 指标 | 数值 |
|------|------|
| 小说场景当前覆盖 | ~75% |
| 目标覆盖 | ~85%（P1 段落 CSS 完成后） |
| 建议工作量 | **1–2d** |
| 架构影响 | **低**（Dart 转换器输出结构调整） |

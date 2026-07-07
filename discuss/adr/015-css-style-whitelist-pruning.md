# ADR-015: CSS 样式白名单精简与 IR 结构优化

**状态**: Accepted
**日期**: 2026-07-07
**作者**: zs / Zephyr

## 1. 背景与问题

- **样式冲突**：EPUB 内嵌的 `line-height` 和 `font-family` 经常与用户的全局设置（字号、行间距、主题色）冲突，导致深色模式下颜色刺眼、行间距不符合用户习惯。`line-height` 冲突已造成 P0 级分页溢出 Bug。
- **IR 冗余**：`RichTextSpanData` 和 `TextBlockStyle` 中包含大量在移动端阅读场景中极少使用或无法保证一致性的字段（`color`、`text-decoration`、`font-family`），增加 FFI 序列化开销和内存占用。
- **算法复杂性**：Rust 分页引擎在处理 `line-height` 时需要复杂的回退逻辑（`block_paginator.rs:546-553`），且容易因 EPUB 作者的随意设置导致分页计算与实际渲染不一致。

## 2. 决策

### 2.1 解析层滤波（Phase 1）— 仅改 `rich_text.rs`

在 `ComputedStyle::apply_declaration` 中，**丢弃**以下属性的解析（移至 `_ => {}` 分支，增加 `tracing::trace!` 记录）：

| 丢弃属性 | 理由 |
| ---------- | ------ |
| `font-family` | 统一由 Flutter 渲染层根据用户全局设置处理。当前 line-width-calib 管道已通过 `TextPainter` 实测比例隐式编码字体 advance。 |
| `line-height` | 默认丢弃，与用户 `lineSpacing` 冲突会导致分页溢出。将来可通过 `ReaderConfig.ignoreEpubLineHeight`（默认 `true`）打开逃逸通道。 |
| `color` | 深色模式下硬编码颜色刺眼。统一由 Flutter 渲染层根据主题色处理。 |
| `text-decoration` | 链接下划线由 `<a>` 语义标签单独处理（`RichTextSpan::Link`），无需 CSS 驱动。 |

**保留**以下结构性属性：

| 保留属性 | 单位 | 理由 |
| ---------- | ------ | ------ |
| `font-size` | px | 核心参数，影响行高和分页边界 |
| `text-align` | — | 核心参数，段落水平布局 |
| `text-indent` | **em** | 核心参数，首行缩进（em 确保字号缩放自动适配，见 §3） |
| `margin-top` / `margin-bottom` | **em** | 核心参数，段落间距（同上） |
| `font-weight` | 阈值 ≥700 | 粗体是唯一的行内强调手段 |
| `font-style` | italic/normal | 斜体 |

### 2.2 领域模型精简（Phase 2）— 需 FRB regenerate

- **`SpanStyle` 枚举**：移除 `BoldItalic`、`Underline`、`Strikethrough`、`Code`。仅保留 `Plain`、`Bold`、`Italic`。（`Link` 不在此枚举，已在 `RichTextSpan::Link` 独立处理。）
- **`RichTextSpanData`**：移除 `font_size`、`color` 字段。`text` 保留。
- **`RichTextSpan`**：`Styled(SpanStyle, RichTextSpanData)` 和 `Link { data, url }` 结构不变。
- **`TextBlockStyle`**：移除 `font_family`、`line_height` 字段。

### 2.3 单位原则（重要）

所有间距类属性（`text-indent`、`margin-top`、`margin-bottom`）**必须保持 em 单位**，不可改为 px。原因：

- 用户调整字体大小滑块时，em 值等比缩放间距，无需重新解析 EPUB。
- Rust 侧在 `block_paginator.rs` 运行时展开为 px（`style.margin_top_em.unwrap_or(0.0) * font_size`）。
- 若存储 px，字号改变后段间距错位，产生回归 Bug。

## 3. 后果

### 正面

- 彻底消除因 EPUB `line-height` 导致的分页溢出 P0 Bug。
- IR 体积减小约 30%（Phase 2），FFI 传输效率提升。
- Rust 分页逻辑更纯粹，不再受复杂 CSS 干扰。
- 深色模式下颜色可控，主题切换无需重新解析。

### 负面

- 极少数依赖特定字体或颜色的学术/艺术类 EPUB 可能丢失部分视觉细节。可通过后续的"原始 HTML 查看器"或"纯文本模式"作为备选方案弥补。
- `<u>`、`<s>`、`<del>`、`<code>` 标签的视觉区分在 Phase 2 后会降级（仍保留文本内容）。

## 4. 实施计划

| Phase | 文件 | 改动 | 依赖 |
| ------- | ------ | ------ | ------ |
| P1 | `rust/src/text/rich_text.rs` | `apply_declaration` 中丢弃 4 属性 + trace 日志 | 无 |
| P1 | `rust/src/text/rich_text.rs` | 更新单元测试 | 同上 |
| P2 | `rust/src/domain/types/rich_text.rs` | 移除 `SpanStyle` 4 变体 | ADR-015 定案 |
| P2 | `rust/src/domain/types/rich_text.rs` | 移除 `RichTextSpanData.color/font_size` | 同上 |
| P2 | `rust/src/domain/types/content_ir.rs` | 移除 `TextBlockStyle.font_family/line_height` | 同上 |
| P2 | — | `flutter_rust_bridge_codegen generate` | FRB 工具链 |
| P2 | `lib/…` | Dart 侧同步删除对应字段 | FRB 生成完毕 |

## 5. 相关链接

- [ADR-010: IR Text 块基础 CSS](./010-ir-text-block-css.md) — 当前 CSS 映射的原始决策
- [PRD: 分页估算不准确导致内容溢出可滑动](/fix-page-estimation-overflow/prd.md) — `line-height` 冲突的 P0 Bug 分析
- [Phase 6 行宽校准 implement.md](/fix-page-estimation-overflow/implement.md) — line-width-calib 管道依赖

## 6. 参与人员

- **提议者**: zs
- **审阅者**: zs
- **决策者**: zs

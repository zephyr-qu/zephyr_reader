# ADR-015: CSS 样式白名单精简与 IR 结构优化

**状态**: Accepted (Implementation Complete)
**日期**: 2026-07-07 (Last updated: 2026-07-16)
**作者**: zs / Zephyr

## 1. 背景与问题

- **样式冲突**：EPUB 内嵌的 `line-height` 和 `font-family` 经常与用户的全局设置（字号、行间距、主题色）冲突，导致深色模式下颜色刺眼、行间距不符合用户习惯。`line-height` 冲突已造成 P0 级分页溢出 Bug。
- **IR 冗余**：`RichTextSpanData` 和 `TextBlockStyle` 中包含大量在移动端阅读场景中极少使用或无法保证一致性的字段（`color`、`text-decoration`、`font-family`），增加 FFI 序列化开销和内存占用。
- **算法复杂性**：Rust 分页引擎在处理 `line-height` 时需要复杂的回退逻辑，且容易因 EPUB 作者的随意设置导致分页计算与实际渲染不一致。

## 2. 决策

### 2.1 解析层滤波（Phase 1）— 改 `rich_style.rs`

在 `ComputedStyle::apply_declaration` 中，**丢弃**以下属性的解析（移至 `_ => {}` 分支，增加 `tracing::trace!` 记录）：

| 丢弃属性 | 理由 |
| ---------- | ------ |
| `font-family` | 统一由 Flutter 渲染层根据用户全局设置处理。
| `line-height` | 与用户 `lineSpacing` 冲突会导致分页溢出。将来可通过 `ReaderConfig.ignoreEpubLineHeight`（默认 `true`）打开逃逸通道。
| `color` | 深色模式下硬编码颜色刺眼。统一由 Flutter 渲染层根据主题色处理。
| `text-decoration` | 链接下划线由 `<a>` 语义标签独立处理，无需 CSS 驱动。

**保留**以下结构性属性：

| 保留属性 | 单位 | 理由 |
| ---------- | ------ | ------ |
| `font-size` | px | 核心参数，影响行高和分页边界 |
| `text-align` | — | 核心参数，段落水平布局 |
| `text-indent` | **em** | 核心参数，首行缩进（em 确保字号缩放自动适配，见 §3） |
| `margin-top` / `margin-bottom` | **em** | 核心参数，段落间距（同上） |
| `font-weight` | 阈值 ≥700 | 粗体是唯一的行内强调手段 |
| `font-style` | italic/normal | 斜体 |

### 2.2 领域模型精简（Phase 2）— 已超额完成

原始 ADR 的设计：
- **`SpanStyle` 枚举**：移除 `BoldItalic`、`Underline`、`Strikethrough`、`Code`。仅保留 `Plain`、`Bold`、`Italic`。
- **`RichTextSpanData`**：移除 `font_size`、`color` 字段。`text` 保留。
- **`RichTextSpan`**：`Styled(SpanStyle, RichTextSpanData)` 和 `Link { data, url }` 结构不变。
- **`TextBlockStyle`**：移除 `font_family`、`line_height` 字段。

实际实施后（pipeline 重构期间）进一步精简：

| 旧类型 | 新类型 | 说明 |
| --------- | ------- | ------ |
| `SpanStyle` 枚举含 Link | `ReaderInlineStyle { Plain, Bold, Italic }` | Link 不再作为枚举变体 |
| `RichTextSpanData { text, font_size, color }` | 并入 `ReaderInlineRun { text, style, url }` | 仅 3 字段 |
| `RichTextSpan::Link { data, url }` | `ReaderInlineRun.url: Option<String>` | 平铺化，非空即链接 |
| `TextBlockStyle { font_family, line_height, ... }` | `BlockStyle` 仅含布局字段 | 无渲染样式字段 |

结论：当前架构比 ADR-015 原文更激进地精简了 IR 类型。

### 2.3 单位原则（重要）

所有间距类属性（`text-indent`、`margin-top`、`margin-bottom`）**必须保持 em 单位**，不可改为 px。原因：

- 用户调整字体大小滑块时，em 值等比缩放间距，无需重新解析 EPUB。
- Rust 侧存储 em 系数 → Flutter 侧在渲染时乘以 `config.fontSize` 展开 px。
  - Rust 侧：`BlockStyle.textIndentEm`, `BlockStyle.marginTopEm`, `BlockStyle.marginBottomEm`
  - Flutter 侧：`IrReaderIrBlock.resolveFirstLineIndentPx()` 中 `em * config.fontSize`
  - Flutter 侧：`IrReaderIrBlock.resolveBlockPadding()` 中 `(marginTopEm ?? 0) * effectiveFontSize()`
- 若存储 px，字号改变后段间距错位，产生回归 Bug。
- **实施核查**：原文提及的 `block_paginator.rs`（Rust 侧）已被 Flutter 侧分页引擎替代。`block_paginator.rs:546-553` 的 `line-height` 回退逻辑已随 Rust 分页引擎一同移除。em→px 转换完全发生在 Flutter 渲染层（`ir_text_block_style.dart`），零残留。

## 3. 后果

### 正面

- 彻底消除因 EPUB `line-height` 导致的分页溢出 P0 Bug。
- IR 体积减小约 30%（Phase 2），FFI 传输效率提升。
- Rust 解析逻辑更纯粹，不再受复杂 CSS 干扰。
- 深色模式下颜色可控，主题切换无需重新解析。

### 负面

- 极少数依赖特定字体或颜色的学术/艺术类 EPUB 可能丢失部分视觉细节。可通过后续的"原始 HTML 查看器"或"纯文本模式"作为备选方案弥补。
- `<u>`、`<s>`、`<del>`、`<code>` 标签的视觉区分当前已降级（仍保留文本内容）。N4 阶段可在 Flutter 渲染层添加补偿样式（如浅灰背景映射 `<code>`、半透明下划线映射 `<u>`），但不可使用颜色变化以免与主题冲突。

## 4. 实施计划（已完成）

| Phase | 文件 | 改动 | 状态 |
| ------- | ------ | ------ | ------ |
| P1 | `rust/src/parser/epub/rich_style.rs` | `apply_declaration` 中丢弃 4 属性 + trace 日志 | ✅ |
| P1 | `rust/tests/text_rich_test.rs` | 更新单元测试 | ✅ |
| P2 | `rust/src/pipeline/types.rs` | 移除旧 SpanStyle/RichTextSpan → ReaderInlineStyle/ReaderInlineRun | ✅ 超额完成 |
| P2 | `rust/src/pipeline/types.rs` | BlockStyle 无 font_family/line_height 字段 | ✅ |
| P2 | `rust/src/parser/epub/rich_paragraph.rs` | ParagraphStyle 使用 em 字段 | ✅ |
| P2 | — | `flutter_rust_bridge_codegen generate` | ✅ |
| P2 | `lib/...` | Dart 侧同步 | ✅ |

## 5. 与主流阅读器对比

本 ADR 的策略与行业主流完全一致：

| 阅读器 | font-family | line-height | color | 一致策略 |
| -------- | ----------- | ----------- | ----- | --------- |
| **Readium CSS** | `--RS__baseFontFamily` 覆盖 | `--RS__baseLineHeight` 覆盖 | `--RS__textColor` 覆盖 | CSS 变量机制，作者样式靠边站 |
| **Apple Books** | 用户字体覆盖作者声明 | 用户行距覆盖 EPUB 设置 | 深色/棕褐色主题覆盖 | `specified-fonts` 可保字体，但用户一动手即覆盖 |
| **Kindle** | 正文强制系统字体，仅标题可自定义 | 强制忽略 | 深色模式覆盖 | Enhanced Typesetting 明确丢弃 font-family/line-height |
| **Google Play Books** | 用户设置优先 | 忽略作者 line-height | 主题覆盖 | 同模式 |
| **本方案 (ADR-015)** | 解析层丢弃 | 解析层丢弃 | 解析层丢弃 | 保留 7 个结构性属性，与主流对齐 |

结论：ADR-015 的去中心化（丢弃 meta 属性、保留结构性属性）不是脱离业界，而是对业界最佳实践的"工程化落地"。

## 6. 相关链接

- [ADR-010: IR Text 块基础 CSS](./010-ir-text-block-css.md) — 当前 CSS 映射的原始决策
- [Readium CSS Defaults](https://readium.org/css/docs/CSS08-defaults.html) — Readium 用户设置 CSS 变量机制
- [Readium EPUB Compatibility](https://github.com/readium/readium-css/blob/master/docs/CSS21-epub_compat.md) — 主流阅读器 CSS 兼容性实践
- [Apple Books Asset Guide](https://help.apple.com/itc/booksassetguide/) — Apple 字体/颜色覆盖策略
- [Kindle Enhanced Typesetting](https://kdp.amazon.com/en_US/help/topic/GB5GDY7WAJDN9GFK) — Kindle CSS 白名单

## 7. 参与人员

- **提议者**: zs
- **审阅者**: zs
- **决策者**: zs

---

## 附录 A：实施核查（2026-07-16）

### A.1 解析层滤波（Phase 1）— ✅ 已落地

文件: `rust/src/parser/epub/rich_style.rs`

- `ComputedStyle::apply_declaration` 仅处理 7 个白名单属性
- 其余属性进入 `_ => { tracing::trace!(...) }` 丢弃分支
- 白名单目前通过 match 分支隐式维护，建议 N2 阶段改为宏或常量集合显式声明

### A.2 领域模型精简（Phase 2）— ✅ 超额完成

| 检查项 | 实际文件 | 状态 |
| -------- | --------- | ------ |
| SpanStyle 仅含 Plain/Bold/Italic | `rust/src/pipeline/types.rs` `ReaderInlineStyle` | ✅ |
| RichTextSpanData 无 font_size/color | `ReaderInlineRun` 仅 text/style/url | ✅ |
| Link 非独立枚举 | `url: Option<String>` 字段 | ✅ |
| BlockStyle 无 font_family/line_height | `rust/src/pipeline/types.rs` `BlockStyle` | ✅ |

### A.3 em→px 转换链路 — ✅ 符合最优策略

| 阶段 | 行为 | 文件 |
| ------ | ------ | ------ |
| Rust 解析 | 按 em 存储间距值 | `rich_style.rs` → `rich_paragraph.rs` → `pipeline/types.rs` |
| Rust FRB | 序列化为 FFI 类型 | `BlockStyle` 经 FRB 至 Dart |
| Flutter 渲染 | 渲染时 `em * config.fontSize` 求 px | `ir_text_block_style.dart` |

Rust 侧 `block_paginator.rs` 已不存在，无残留的 Rust-em→px 转换。

### A.4 N2 优化建议

1. **白名单声明宏** — 将 7 个白名单属性从散落的 match 分支提炼为 `css_whitelist!` 宏，集中声明 + 处理一体，零运行时开销。
2. **验证 block_paginator 无残留** — 已确认 Rust 侧无 `block_paginator.rs`，无需处理。

### A.5 N4 边界优化建议

1. **丢弃样式的补偿渲染** — `<code>` 映射为浅灰背景，`<u>` 映射为半透明下划线。Flutter 侧 `RichTextConverter` 中实现，不涉及 Rust。
2. 不可使用颜色变化（保持与主题色一致性）。

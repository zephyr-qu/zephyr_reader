# 排版差距分析 — 双语小说阅读器

> 审查日期: 2026-06-26
> 更新日期: 2026-07-03 — P1 已通过 IR block 路径完整实现
> 产品目标：中英双语**小说**离线阅读。不追求多看级通用 EPUB 精排。

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
| **首行缩进 (text-indent)** | ✅ | `IrTextBlockStyle.resolveFirstLineIndentPx` → `WidgetSpan+SizedBox` |
| **段间距 (margin-top/bottom)** | ✅ | `IrTextBlockStyle.resolveBlockPadding` / `resolveBottomSpacing` |
| **段落字体 (font-family)** | ✅ | `IrTextBlockStyle.mapToTextStyle(fontFamily)` |
| **行高 (line-height)** | ✅ | `IrTextBlockStyle.mapToTextStyle(height)` |

---

## ✅ P1 已完成 — 段落排版 CSS 投射到 Dart

> 2026-07-03 确认：P1 所列 gap 已通过 Phase 4 IR block 渲染路径（`IrTextBlockStyle`）全部实现。
> scroll + pagination 两条主链路均使用 `IrTextBlockStyle` 消费 `TextBlockStyle` 字段。
> `RichTextConverter` 的 CJK 全角空格方案仅是 fallback 路径（Phase 4 后不应触发）。

| CSS 属性 | `TextBlockStyle` 字段 | Dart 实现方式 | 状态 |
|----------|------------------------|---------------|------|
| `text-indent` | `textIndentEm` | `WidgetSpan` + `SizedBox(width: em × fontSize)` | ✅ |
| `margin-top/bottom` | `marginTopEm`/`marginBottomEm` | `EdgeInsets.only(top/bottom: em × fontSize)` | ✅ |
| `font-family` | `fontFamily` | `TextStyle(fontFamily)` + `StrutStyle` | ✅ |
| `line-height` | `lineHeight` | `TextStyle(height)` | ✅ |
| `font-size` | `fontSize` | `TextStyle(fontSize)` | ✅ |
| `text-align` | `textAlign` | `TextAlign` 映射 | ✅ |

---

### ✅ P2 已完成 — 双语模式段落样式投射

> 2026-07-03 实现：双语渲染器接入用户全局配置（`firstLineIndent` / `paragraphSpacing` / `textAlign`），
> 与单语 scroll 模式无 CSS 段行为一致。

`AlignedSegment` 只含纯文本（`chinese`/`english`），不含 CSS 样式信息。
双语段无法像 IR block 路径那样消费 `TextBlockStyle`，因此投射策略为：

| 样式 | 双语实现方式 | 状态 |
|------|-------------|------|
| `text-indent` | `config.firstLineIndent` → `WidgetSpan` + `SizedBox(width: 2em × fontSize)` | ✅ |
| 段间距 | `config.paragraphSpacing` 替代硬编码 `20px` | ✅ |
| `text-align` | `config.textAlign` 传入 `SelectableText.rich` | ✅ |
| 行高行为 | `ReaderRenderConfig.textHeightBehavior` | ✅ |

改动文件：`bilingual_renderer.dart`

---

## 总结

| 指标 | 数值 |
|------|------|
| 小说场景当前覆盖 | ~90%（P1 + P2 段落样式已完成） |
| P1 状态 | ✅ 已完成（通过 IR block 路径） |
| P2 状态 | ✅ 已完成（用户全局配置投射） |

# 排版差距分析 — 双语小说阅读器

> 产品目标：中英双语**小说**离线阅读。不追求多看级通用 EPUB 精排。
> 当前小说场景覆盖约 **70%**（基础样式 + 纯文本分页 + 滚动/双语富文本）；剩余可做工约 **1–2d**。

## 当前已有（小说场景够用）

| 能力 | 状态 | 链路 |
|------|------|------|
| 粗体/斜体/下划线 | ✅ | html5ever → `RichTextConverter` |
| 标题 | ✅ | `heading_level` |
| 行内颜色/字号 | ✅ | 内联 CSS |
| 文本对齐 | ✅ | `text_align` |
| 段落/列表（纯文本） | ✅ | DOM 遍历 → 纯文本流出 |
| 分页排版（TXT/EPUB 正文） | ✅ | `PageStreamer` + `PaginationSession` |
| 滚动模式富文本 | ✅ | EPUB/MD → `ScrollModeRenderer` |
| 双语对齐 / 对照高亮 | ✅ | `align_bilingual_content` + Translation VM |

---

## 值得做的差距（按优先级）

### P1 — 段落排版 CSS（~1–2d）

小说最常见：首行缩进、段间距。Rust 已解析部分 CSS，但未完整投射到 `RichParagraph` / Dart。

| CSS 属性 | 用途（小说） | 改动面 |
|----------|-------------|--------|
| `text-indent` | 中文段落首行缩进 | `ComputedStyle` → `RichParagraph` → `RichTextConverter` |
| `margin` / `padding`（块级） | 段间距、引用块留白 | 同上 |
| `font-family` | 英文/中文字体族映射到系统字体 | Rust 已解析，需写入 span 并映射 `TextStyle.fontFamily` |

**不涉及** `PageStreamer` 改造，仅滚动模式 + 双语渲染链路。

### P2 — 双语模式与富文本一致性（~0.5d，按需）

确认双语模式下 EPUB 段落样式与滚动模式一致（`text-indent`、对齐），避免「分页用 Rust 真理、双语用 stripped plain text」的视觉割裂。若双语已走 `currentRichParagraphs`，随 P1 自动受益。

---

## 明确不做（已从路线图删除）

以下能力对标通用 EPUB 阅读器 / 学术书，**与双语小说目标无关**，不立项：

| 能力 | 删除原因 |
|------|----------|
| 分页模式图片 + float 环绕 | 小说以纯文本为主；需重构 `PageStreamer`，ROI 低 |
| 表格 | 教材/技术书场景，非小说 |
| Ruby 注音 | 日语/注音教材，非中英小说 |
| 交互式脚注 | 学术 EPUB；小说极少依赖 |
| MathML / SVG 公式 | 学术/理工 EPUB |
| 竖排 `writing-mode` | 古典竖排书籍，非目标用户 |
| EPUB 嵌入字体二进制 | 授权与校准成本高；系统字体 + 用户设置足够 |
| `page-break-*` 分页控制 | 依赖结构感知分页，小说 EPUB 很少需要 |
| `list-style-type` 精细列表 | 小说内列表极少，现有 `•` 前缀可接受 |
| 完整多看精排对标（15–25d） | 投入接近独立排版引擎，与产品主线（双语 + 离线 + 分页性能）冲突 |

---

## 实施路径

```
Phase 1（1–2d）— 段落 CSS 补全
  rust/src/text/rich_text.rs     ComputedStyle + RichParagraph 字段
  lib/.../rich_text_converter.dart  TextStyle / Padding 投射
  验收：带 text-indent 的 EPUB 段落首行缩进正确；段间距可见

Phase 2（按需）— 双语模式渲染走同一 RichParagraph 样式
  验收：bilingual 与 scroll 段落样式一致
```

**架构影响：无。** 不改动 `PageStreamer`、不分页单元泛型化。

---

## 总结

| 指标 | 数值 |
|------|------|
| 小说场景当前覆盖 | ~70% |
| 目标覆盖 | ~85%（P1 段落 CSS 完成后） |
| 建议工作量 | **1–2d** |
| 架构影响 | **低**（富文本解析 + Dart 转换器） |

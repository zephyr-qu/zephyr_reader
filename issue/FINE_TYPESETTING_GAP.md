# 精排版差距分析 — 多看阅读对标

> 当前覆盖约 30% 的精排能力，完整差距约 15-25d。

## 当前已有

| 能力 | 当前状态 | 链路 |
|------|----------|------|
| 粗体/斜体 | ✅ `RichTextSpan::Bold/Italic` | html5ever → FRB → `RichTextConverter` |
| 标题识别 | ✅ `heading_level` + `is_heading` | html5ever DOM 遍历 |
| 行内颜色/字号 | ✅ `span.color` + `span.font_size` | 内联 CSS 提取 |
| 文本对齐 | ✅ `text_align` → `TextAlign` | CSS 解析 |
| CSS class 选择器 | ✅ 简单 `style_map` 映射 | 正则 CSS 解析 |
| 代码块 | ✅ `RichTextSpan::Code` | html5ever |
| 图片（滚动模式） | ✅ `image_data` + `Image.memory` | html5ever → FRB → 滚动渲染器 |

---

## 差距

### 1. 分页模式无图片

当前 `paginate_chapter` 使用 `provider.read_text_range()`（纯文本），图片信息不存在于分页引擎中。分页模式只能显示纯文字，图片仅在滚动模式可见。

```
多看: 分页模式下图片占位 + 文字环绕 + 分页避让
当前: 分页模式纯文字，图片仅滚动模式可见

估算: 2-3d（影响 PageStreamer 核心抽象）
```

### 2. 表格

当前 `traverse_dom` 处理 `<table>`/`<tr>`/`<td>` 时只拼接内部文本，丢失所有表格结构。

```
多看: 表格有网格线、列宽分配、表头样式
当前: 表格内容以纯文本流出，无结构

估算: 2-3d（Rust 解析 TableRow/TableCell + Dart Table widget）
```

### 3. Ruby 注音与注释

Ruby 文本（汉字上方标注拼音/假名）和弹出式脚注是中文/日文 EPUB 的标配，当前无支持。

```
多看:
  ruby: 汉字上方悬浮拼音
  脚注: 上标数字 → 点击弹出底部 sheet
当前: 无 ruby 解析，无 footnote 弹出

估算: 3-4d（含 Rust 解析 + Dart 交互）
```

### 4. 缺失 CSS 属性

当前 CSS 解析只处理：`font-size`、`color`、`line-height`、`text-align`、`font-weight`（粗体检测）、`font-style`（斜体检测）。

精排会用到的缺失属性：

| CSS 属性 | 用途 | 难度 |
|----------|------|------|
| `margin`/`padding` | 段落间距、缩进 | 低 |
| `text-indent` | 首行缩进 | 低 |
| `font-family` | 嵌入字体切换 | 低 |
| `page-break-before/after` | 分页控制 | 中 |
| `float` | 图片文字环绕 | 中 |
| `width`/`height` | 图片尺寸控制 | 低 |
| `background-color` | 高亮/代码块背景 | 低 |
| `list-style-type` | 有序/无序列表 | 中 |
| `writing-mode` | 竖排文字 | 高 |

```
估算: 1-2d（逐个属性在 ComputedStyle 中添加 + RichTextSpan 携带新字段）
```

### 5. 公式与 SVG

多看支持 MathML 公式和 SVG 矢量图。当前无任何支持。

```
缺口: Flutter 侧 math 公式渲染无成熟方案（需 flutter_math 或自定义 TeX 引擎）
估算: 3-5d（MathML→Flutter widget 转换 + 依赖评估）
```

---

## 差距总览

| 维度 | 多看 | 当前 | 估算 | 优先级 |
|------|------|------|------|--------|
| 基础样式（B/I/H/颜色） | ✅ | ✅ | — | — |
| 图片（滚动模式） | ✅ | ✅ | — | — |
| 图片（分页模式） | ✅ | ❌ | 2-3d | **P2** |
| 表格 | ✅ | ❌ | 2-3d | P3 |
| Ruby 注音 | ✅ | ❌ | 1-2d | P3 |
| 交互式脚注 | ✅ | ❌ | 1-2d | P3 |
| 缺失 CSS 属性 | ✅ | ❌ | 1-2d | **P2** |
| 嵌入字体 | ✅ | ❌ | 0.5d | **P2** |
| 分页控制 | ✅ | ❌ | 1d | P3 |
| 公式 (MathML) | ⚠️ | ❌ | 3-5d | P4 |
| 竖排文字 | ⚠️ | ❌ | >5d | P4 |
| **总计** | | | **~15-25d** | |

---

## 第一优先路径

按收益/成本排序：

### 第一波（~3.5d，覆盖 80% 用户感知差距）

1. **分页模式支持图片**（2-3d）
   - `PageStreamer` 需要感知段落中的非文本单元
   - `PageDescriptor` 需要携带图片引用信息
   - Dart 分页渲染器需要支持图片占位

2. **缺失 CSS 属性**（1-2d）
   - `margin/padding/text-indent` → `RichParagraph` 字段
   - `font-family` → Dart `TextStyle.fontFamily`
   - `background-color` → 代码块/高亮背景

3. **嵌入字体**（0.5d）
   - `font-family` 属性投射到 Dart 的 `FontResolver`

### 第二波（~3d）

4. **表格**（2-3d）
   - Rust: `RichTextSpan` 新增 `Table` 变体
   - Dart: `Table`/`TableRow` widget 适配

### 第三波（~5d）

5. Ruby 注音 + 脚注 + 公式 — 按实际用户反馈决定

---

## 架构影响

精排的核心架构挑战：`PageStreamer` 的输入需要从纯文本改为带结构的富文本。

```rust
// 当前：纯文本输入
fn paginate_chapter(…) -> PaginateResult {
    let content = provider.read_text_range(start, end)?;
    let streamer = PageStreamer::new(content, config);
    // …
}

// 需要：分页层能感知段落/图片/表格边界
enum PaginateUnit {
    Text(String),
    Image(Vec<u8>),
    Table(TableData),
    // 分页时按单元切分，而非按字符偏移
}
```

这是架构级改动——不是简单加字段，而是改变分页引擎的基本抽象单元。也是估算天数较多的根本原因。

---

## 总结

| 指标 | 数值 |
|------|------|
| 当前覆盖 | ~30%（基础样式 + 纯文本分页 + 滚动模式图片）|
| 多看精排覆盖率目标 | ~80%（分页图片 + CSS 补充 + 字体 + 表格）|
| 第一优先工作量 | ~3.5d（分页图片 + CSS 补充 + 字体）|
| 总计差距 | ~15-25d（完整精排）|
| 架构影响 | 中型。`PageStreamer` 需泛型化以支持非文本分页单元 |

# Zephyr Reader Rust 引擎架构

> 版本：3.1 | 最后更新：2026-07-07

---

## 0. 核心概念澄清：Rust 的角色变化

本项目的架构经历了 P6–P9 大规模重构（Phase 7 清理后），**Rust 分页引擎已全部删除**，分页完全迁移至 Flutter 侧。

当前 Rust 引擎的角色是**内容服务器**而非分页引擎：

```
阶段 1: Flutter 排版（Typesetting）
  用 TextPainter 做真实的文字布局。
  输出：字宽、行高、行宽比 → CalibrationData（仅 scroll 模式可选使用）

阶段 2: Flutter 分页（Pagination）
  用 FlutterPaginationSession 在 Flutter 侧完成全部装箱。
  Rust 不再参与任何分页计算。
  输出：PackedPage[]

阶段 3: Flutter 渲染（Rendering）
  用 PackedPage 的页码范围内的文本裁剪，交给 SelectableText 渲染到屏幕。

Rust 只做：
  ├─ 解析 TXT/EPUB → ChapterContentIr（ContentBlock IR）
  ├─ 缓存 IR 到 sled（scroll_ir_cache）
  ├─ 存储/查询书籍元数据、书签、笔记、进度（SQLite）
  ├─ 全文搜索（FTS5 + jieba-rs）
  ├─ 词典查询（mdict 引擎）
  └─ 双语对齐
```

| | 谁做 | 做什么 | 产出 |
|---|------|--------|------|
| **内容准备** | Rust | 解析、IR 构建、缓存 | `ChapterContentIr` |
| **排版** | Flutter `TextPainter` | 字宽度量、行高测量 | `CalibrationData`（可选） |
| **分页** | Flutter `FlutterPaginationSession` | 用布局参数估算页边界 | `PackedPage[]` |
| **渲染** | Flutter `SelectableText` | 在页码范围内渲染文字 | 屏幕像素 |

> **历史遗留**：`domain/types/pagination.rs` 仅保留 `SearchResult`、`IndexStats`（搜索引擎用）；`PageContent`、`ChapterPaginationMode` 已删除。`text/line_breaking.rs`、`text/char_width.rs` 仅保留测试（消费方 `block_paginator.rs` 已删）。

---

## 1. 总览

### 1.1 模块架构

```
┌──────────────────────────────────────────────────────────────────┐
│                    Flutter 排版层（Typesetting）                   │
│  TextPainter 真实排版  │  measureLayoutFingerprint()              │
│  → 字宽 + 行高 + 行宽比  = CalibrationData（ground truth）        │
│  LayoutCalibrationStore (SharedPreferences cache)               │
│  resolveLayoutCalibration() — 强制测完再分页                     │
└────────────────────────────┬─────────────────────────────────────┘
                             │ FRB (TypesetCalibration)
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Rust 分页层（Pagination）                       │
│  数学估算器：用 Flutter 实测字宽/行高/行宽比                       │
│  计算每页能装多少字、页边界在哪。不渲染文字，不调字体引擎。            │
│                                                                  │
│  full_line_width = page_w × ratio        (ratio 来自 Flutter)    │
│  line_height = measured_h × (block_font / base_font)             │
│  → PageDescriptor { startOffset, endOffset }                     │
│                                                                  │
│  + parser + storage + search + dictionary (完整 Rust 引擎)         │
└────────────────────────────┬─────────────────────────────────────┘
                             │ FRB (PageDescriptors)
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Flutter 渲染层（Rendering）                     │
│  按 PageDescriptor 范围取文本 → SelectableText.rich 渲染到屏幕       │
│  PaginatedPageViewport (SizedBox + ClipRect) — 约束视口            │
│  [LineBreak] overflow_dp ≤ 0.5 — CI 门禁                          │
└──────────────────────────────────────────────────────────────────┘
```

### 1.2 核心设计原则

| # | 原则 | 实现 |
|---|------|------|
| 1 | **Flutter 是 ground truth** | 所有排版参数由 Flutter TextPainter 实测，Rust 不猜任何魔数 |
| 2 | **测完再分页** | `resolveLayoutCalibration()` 先于 `paginate_chapter()`，首屏就对 |
| 3 | **配置变更自动重测** | `config_hash` 变化 → cache miss → 重测 → 重分页 |
| 4 | **块级字号按比例** | `effective_line_height = measured_base × (block_font / base_font)` |
| 5 | **标量校准优先** | 断行位置差异通过 overflow 指标验收；行边界传递为长期可选项 |
| 6 | **所有 panic 禁止跨越 FFI** | 所有导出函数返回 `Result<T, AppError>` |
| 7 | **零拷贝优先** | `Uint8List`/`String` 映射，避免 struct 序列化冗余 |
| 8 | **双引擎存储** | SQLite（结构化数据）+ sled（KV 缓存） |
| 9 | **统一 IR 路径** | TXT/EPUB → `ChapterContentIr` → `BlockPaginator`，无双引擎 |

### 1.3 排版参数来源对照

| 参数 | 来源 | 传递方式 |
|------|------|----------|
| 6 组字宽 (cjk/ascii/...) | Flutter `TextPainter` 测量 | `TypesetCalibration` (FRB) |
| `effectiveLineWidthRatio` | Flutter 排版 200 个"中"反推 | 同上 |
| `measuredLineHeightPx` | Flutter `TextPainter` + `StrutStyle` 实测 | 同上 |
| `pageWidth` / `pageHeight` | `buildTypesetConfig` (已扣 vPad + 水平 padding) | `TypesetConfig` (FRB) |
| `letterSpacing` | 用户设置 | 同上 |
| `lineSpacing` / `paragraphSpacing` | 用户设置 | 同上 |
| 首行缩进 / 标点挤压 / 中西文间距 | 用户设置 | 同上 |

---

## 2. Flutter 排版层 — 详细解析

> 输入：`TypesetMeasureParams`（页面尺寸 + 排版设置）
> 输出：`CalibrationData` → `TypesetCalibration`（FRB 传给 Rust）
> 关键文件：`typeset_calibrator.dart` (~790 行)

### 2.1 测量流程

```
TypesetMeasureParams {
  width, height, pagePadding, contentVerticalPadding,
  fontSize, lineHeight, letterSpacing,
  fontFamily, devicePixelRatio,
  baselineAlign, firstLineIndentChars
}
      │
      ▼
_measureStyles()  ──── 用 ReaderRenderConfig 的同一套栈
  ├─ buildTextStyle()   → TextStyle(fontSize, fontFamily, letterSpacing, height)
  └─ buildStrutStyle()  → StrutStyle(forceStrutHeight, leading: 0)
      │
      ▼
measureLayoutFingerprint()  ──── 4 个测量子步骤
  │
  ├─ _measureAvgCharWidth() × 6
  │   测量 6 组 Unicode: cjk / ascii / digit / punct / latinExt / other
  │   每组 3-5 个代表字符，TextPainter.layout(maxWidth: infinity)
  │   返回: tp.width / text.length  ← 平均单字宽度 (dp)
  │
  ├─ measureEffectiveLineWidthRatio()
  │   排版 200 个"中"在 availableWidthDp 宽度下
  │   读第一行 lineMetrics.width，除以单字宽得 charsPerLine
  │   返回: (charsPerLine × singleWidth) / availableWidthDp
  │   例: 320 / 328 = 0.976
  │
  ├─ measureLineHeightDp()
  │   TextPainter.layout("中", maxWidth: infinity)
  │   读 lineMetrics[0].height
  │   forceStrutHeight 保证与渲染行高一致
  │
  └─ → CalibrationData {
       cjkWidth, asciiWidth, digitWidth,
       punctWidth, latinExtWidth, otherWidth,
       effectiveLineWidthRatio,  // ← 消灭 0.97 魔数
       lineHeightDp, dpr         // ← 消灭 fontSize×lineHeight 理论值
     }
```

### 2.2 数据转换：`CalibrationData` → `TypesetCalibration`

```dart
calibrationToRust(data) → TypesetCalibration {
  dpr:                    data.dpr,
  cjk_width:              data.cjkWidth * dpr,       // dp → px
  ascii_width:            data.asciiWidth * dpr,
  digit_width:            data.digitWidth * dpr,
  punct_width:            data.punctWidth * dpr,
  latin_ext_width:        data.latinExtWidth * dpr,
  other_width:            data.otherWidth * dpr,
  effective_line_width_ratio:  data.effectiveLineWidthRatio,  // 直传，无量纲
  measured_line_height_px:     data.lineHeightDp * dpr,        // dp → px
}
```

### 2.3 缓存策略

```
LayoutCalibrationStore (SharedPreferences)
  键 = "layout_calib_v1_{Object.hash(10个测量参数)}"

  触发重测 = 任意参数变化 → hash 变 → cache miss
  参数包括: width, height, pagePadding, contentVerticalPadding,
           fontSize, lineHeight, letterSpacing, fontFamily,
           devicePixelRatio, baselineAlign, firstLineIndentChars

  resolveLayoutCalibration(params, prefs)
    ├─ [LayoutCalib] cache hit  → return cached  (0ms)
    └─ miss → measureLayoutFingerprint → save → return
```

**同设备、同设置第二次打开 = 0ms 跳过测量。**

### 2.4 配置构建：`buildTypesetConfig()`

```dart
buildTypesetConfig(width, height, fontSize, lineHeight, calibration, ...)
  │
  ├─ contentHeight = height - 2×contentVerticalPadding - pageHeightLineBuffer
  │   例: 840 - 40 - 0 = 800dp  ← 扣除正文上下内边距
  │
  ├─ pageHeightPx = (contentHeight × dpr).round()
  │   例: 800 × 2.6 = 2100px
  │
  ├─ pageWidthPx = ((width - 2×padding) × dpr).round()
  │   例: (390 - 32) × 2.6 = 975px
  │
  └─ → TypesetConfig {
       pageWidth: 975, pageHeight: 2100,
       fontSize: 48, lineSpacing: 1.8,
       calibration: TypesetCalibration { ... }
     }
```

### 2.5 时序保证

```
chapter_load_orchestrator.dart:
  resolveLayoutCalibration(params, prefs)  ← 必须先完成
       ↓
  buildTypesetConfig(calibration)           ← 注入实测指纹
       ↓
  paginate_chapter(config)                  ← Rust 只消费，不猜测
```

**首屏渲染必须等测量完成。** 先 paginate 再测量的 Bug B 已修复。

---

## 3. Rust 分页层 — 详细解析

> 输入：`TypesetConfig`（含 `TypesetCalibration`） + `ChapterContentIr`
> 输出：`PageDescriptor[]`（每页的字符范围）
> 关键文件：`block_paginator.rs` (~1300 行), `line_breaking.rs` (~260 行), `char_width.rs` (~120 行)

### 3.1 数据流概览

```
TypesetConfig ──→ BlockLayoutMetrics::from_config()
  │                ├─ full_line_width_px = page_width × effective_line_width_ratio
  │                ├─ line_height_px      = measured || (font_size × line_spacing)
  │                └─ width_table         = CharWidthTable::from_calibration()
  │
  ▼
ChapterContentIr ──→ BlockPaginator::new(metrics)
  │                   remaining_height = page_height_px
  │
  ▼
for block in ir.blocks:
  ├─ ContentBlock::Text → paginate_text_block()
  │    ├─ _break_paragraph()    → compute_line_breaks_variable_width()
  │    │   逐字累加 char_width (CharWidthTable) + letter_spacing_px
  │    │   标点挤压 ×0.65  |  中西文间距 +auto_space_px
  │    │   避尾标点（开括号推下一行） |  避头标点（闭标点回拉）
  │    │
  │    ├─ ensure_vertical_space(effective_line_height)
  │    │   remaining_height < required → flush_page() → new page
  │    │
  │    └─ remaining_height -= effective_line_height
  │
  └─ ContentBlock::Image → paginate_image_block()
       ├─ 小图 (height ≤ remaining) → InlineContain
       └─ 大图 → flush → FullPage (独占页)
```

### 3.2 核心算法：逐行消费

```rust
// block_paginator.rs — paginate_text_block 核心循环
for visual_line in visual_segments {
    let required_height = effective_line_height + bottom_spacing;
    ensure_vertical_space(required_height); // 不够就换页
    self.remaining_height -= effective_line_height;
}
```

```rust
// 块级字号行高缩放（每条块独立）
let effective_font_size = block.style.font_size.unwrap_or(metrics.font_size_px);
let effective_line_height = block.style.line_height
    .map(|lh| lh * effective_font_size)          // 块有显式 line_height
    .unwrap_or_else(|| {
        let ratio = effective_font_size / metrics.font_size_px.max(1.0);
        metrics.line_height_px * ratio           // 按比例从基准缩放
    });
```

### 3.3 断行算法：Rust vs Flutter

| 维度 | Rust `compute_line_breaks_variable_width` | Flutter `TextPainter` |
|------|------------------------------------------|----------------------|
| 算法 | 贪心逐字累加宽度 | ICU 断行引擎 |
| 字宽来源 | `CharWidthTable`（Flutter 实测校准） | 字体引擎 raster |
| 标点挤压 | 连续 CJK 标点后一个 ×0.65 | 字体 metrics 决定 |
| 中西文间距 | 固定 `auto_space_px` | 排版引擎动态 |
| 换行决策 | 超宽即断 | 语言规则 + 宽度 |
| 行尾规则 | 避尾开括号 / 避头闭标点 | ICU LineBreaker |

**差异控制**：通过 `[LineBreak] overflow_dp ≤ 0.5` CI 门禁验收。当前实测 `overflow = 0.0` 在所有场景稳定。

### 3.4 分页结果产出

```rust
BlockPaginator::finish() → BlockPaginateResult {
    descriptors: [
        PageDescriptor { startOffset: 0,    endOffset: 436 },
        PageDescriptor { startOffset: 436,  endOffset: 909 },
        PageDescriptor { startOffset: 909,  endOffset: 1370 },
        ...
    ],
    config_hash: 0xABCD1234,  // 排版指纹，配置变则 miss
    is_partial: false,        // 是否仅首屏 2000 字
}
```

### 3.5 大章分片（>200 blocks）

```
if blocks.len() > CHUNK_BLOCK_COUNT (200):
  按 200-block 切片
  ├─ 每个切片独立 paginate_chapter_ir()
  ├─ chunk 边界保护：切割点前 5 block 内有图片 → 扩展切片
  └─ merge: 调整 page_index 连续
```

---

## 4. Rust 引擎子系统

> 分页层是 Rust 侧的核心，此外还有解析、存储、搜索等子系统。

### 4.1 模块分层

```
┌───────────────────────────────────────────────────────────┐
│                    api/  FFI API 层 (77 函数)             │
│  core │ cover │ bilingual │ search │ epub │ phase2_ir │
└────────────────────┬──────────────────────────────────────┘
         ┌───────────┼─────────────────┐
         ▼           ▼                 ▼
  ┌──────────┐ ┌──────────┐ ┌───────────┐
  │ parser/  │ │ reading/ │ │ storage/  │
  │ TXT/EPUB │ │ session  │ │ SQLite +  │
  │ Registry │ │ 缓存 LRU │ │ sled KV   │
  │ Provider │ │ staging  │ │ 13 Repo   │
  └──────────┘ └────┬─────┘ └───────────┘
                     │
                     ▼
              ┌──────────┐  ┌───────────┐  ┌──────────┐
              │  text/   │  │  domain/  │  │ search/  │
              │ 分页引擎  │  │ 类型定义  │  │ FTS5+jb  │
              └──────────┘  └───────────┘  └──────────┘
```

### 4.2 解析器层

| 格式 | 解析器 | Provider | IR 转换 |
|------|--------|----------|---------|
| TXT | `TxtParser` | `TxtContentProvider` (mmap) | `txt_to_chapter_ir()` 按空行分段 |
| EPUB | `EpubParser` | `EpubContentProvider` (惰性) | `get_chapter_content_ir()` HTML→块 |

`BookParser` trait：`parse()` / `extract_metadata()` / `extract_chapter()`。
`ChapterContentProvider` trait：`read_text_range()` / `content_length()` / `format()`。

### 4.3 领域类型

| 类型 | 位置 | 说明 |
|------|------|------|
| `TypesetCalibration` | `typeset.rs` | 9 字段 `f32`，`#[frb(non_opaque)]`，`Copy` |
| `TypesetConfig` | `typeset.rs` | 14 字段，手动 `Hash`（含 calibration 全部子字段） |
| `BlockPageDescriptor` | `block_pagination.rs` | block 范围 + plain 范围 + image_layouts |
| `ChapterContentIr` | `content_ir.rs` | `blocks: Vec<ContentBlock>` + `plain_text: String` |
| `ContentBlock` | `content_ir.rs` | Text / Image 两变体 |
| `AppError` | `error.rs` | 18 变体，每个有稳定 `code()` |

### 4.4 存储层

```
SQLite (sqlx, WAL, 4 连接)           sled KV
├── books / chapters / bookmarks      └── layout_cache tree
├── notes / reading_progress              ├── v2:{book}:{ch}:{hash}
├── reading_sessions / stats              ├── v2:chunk:{book}:{ch}:{idx}:{hash}
├── categories / dictionaries             └── v2:scroll_ir:{book}:{ch}
└── search_index (FTS5 虚拟表)
```

**PaginationStore**（LRU，容量 16）：内存级分页引擎缓存，键 `(book_id, chapter_index, config_hash)`。

### 4.5 搜索与词典

- **搜索**：SQLite FTS5 + jieba-rs 分词。`MATCH` 查询，BM25 排序，500 字符窗口索引。
- **词典**：`rust_mdict` 解析 MDX/MDD，精确匹配 + 编辑距离 2 模糊建议，音频 MDD 提取。

---

## 5. Flutter 渲染层 — 详细解析

> 输入：`PageDescriptor[]` + 章节文本
> 输出：屏幕像素
> 关键文件：`paginated_renderer.dart` (~580 行), `block_page_content.dart` (~520 行)

### 5.1 页面组装

```
PageDescriptor { startOffset: 436, endOffset: 909 }
      │
      ▼
buildSinglePageContent(pageIndex, startOffset, dataSource, config, highlights)
  │
  ├─ plain text 模式:
  │   dataSource.pageContent(pageIndex) → 范围文本
  │   HighlightPainter.paintPlain() → TextSpan (高亮渲染)
  │   → SelectableText.rich(paintedSpan, strutStyle, textAlign)
  │
  └─ contentBlocks 模式:
      dataSource.pageBlocks(pageIndex) → [PageBlockSlice]
      for block in blocks:
        ├─ TextBlockSlice → IrTextBlockStyle + SelectableText.rich
        └─ ImageBlockSlice → EpubBlockImage (Inline/FullPage)
      → Column(children, mainAxisSize: MainAxisSize.min)
```

### 5.2 视口约束

```dart
Padding(symmetric(horizontal: pageMargin, vertical: vPad))
  child: PaginatedPageViewport(maxHeight: bodyHeight)
    child: SizedBox(height: bodyHeight)
      child: ClipRect                // 裁剪溢出
        child: Align(topCenter)      // 顶部对齐
          child: content              // SelectableText / Column

bodyHeight = constraints.maxHeight - 2 × pageContentVerticalPadding(20dp)
           = 800dp (与 Rust pageHeightPx / dpr 一致)
```

**`SizedBox` 不裁剪**，`ClipRect` 才是裁剪层。双重保障：SizedBox 约束子 Widget 高度 + ClipRect 裁掉超出部分。

### 3.1 Flutter 分页（替代 Rust `block_paginator.rs`）

```
ChapterContentIr ──→ FlutterPaginationSession
  ├─ 用 TextPainter 实测字宽/行高/行宽比
  ├─ 用 Flutter 行断点（ICU 引擎）替代 Rust 贪心断行
  └─ 输出 PackedPage[]（纯 Dart 类型）

缓存：
  ├─ LayoutCalibrationStore（SharedPreferences）— 排版指纹缓存
  └─ line_breaks_store（Rust 侧 HashMap）— 行断点索引缓存
```

### 5.5 自动化测试

| Layer | 文件 | 数量 | 验证内容 |
|-------|------|------|---------|
| A | `layout_calibration_store_test.dart` | 5 | 缓存 roundtrip / key / corrupt / defaults |
| A | `typeset_calibrator_test.dart` 扩展 | 4 | cache hit / line_height / ratio / drift |
| B | `block_paginator.rs` mod tests | 4 | Rust ratio / line_height / page_count / fallback |
| C | `layout_fingerprint_alignment_test.dart` | 4 | CI 核心：TextPainter vs Rust ≤1 行 |
| D | `block_page_overflow_test.dart` | 2 | Widget 视口几何不溢出 |

---

## 4. 清理记录

### 4.1 Phase 7 完成项

| # | 内容 | 状态 |
|---|------|------|
| 1 | `calibrateSafely()` 死代码 | ✅ 已删除 |
| 2 | `kRustLineWidthSafetyRatio` 别名 | ✅ 已统一到 `kDefaultEffectiveLineWidthRatio` |
| 3 | `kRustCharWidthScale` (恒为 1.0) | ✅ 已内联 |
| 4 | Rust `layout_slice_text_segments` (仅测试) | ✅ `#[cfg(test)]` |
| 5 | Rust `compute_line_breaks_from_indices` (仅测试) | ✅ `#[cfg(test)]` |
| 6 | `estimateRustLinesForText` 诊断偏差 2-4 行 | 🟡 待收敛 |
| 7 | `DEFAULT_IMAGE_HEIGHT_RATIO = 0.55` | 🟡 待评估 |
| 8 | Rust 贪心 → Flutter TextPainter 行边界传递 | 🟢 长期路线 |

---

## 5. 关键常量

| 常量 | 值 | 位置 |
|------|-----|------|
| `DEFAULT_EFFECTIVE_LINE_WIDTH_RATIO` | 0.97 | `block_paginator.rs` (仅 fallback) |
| `FLUTTER_BREAK_CHAR_WIDTH_SCALE` | 1.0 | `block_paginator.rs` |
| `GREEDY_LINE_WIDTH_RATIO` | 1.0 | `block_paginator.rs` |
| `DEFAULT_IMAGE_HEIGHT_RATIO` | 0.55 | `block_paginator.rs` |
| `CHUNK_BLOCK_COUNT` | 200 | `block_paginator.rs` |
| `PAGINATION_ENGINE_CACHE_CAPACITY` | 16 | `pagination_store.rs` |
| `pageContentVerticalPadding` | 20.0 dp | `reader_render_config.dart` |
| `kDefaultEffectiveLineWidthRatio` | 0.97 | `typeset_calibrator.dart` |
| `LAYOUT_ALGORITHM_VERSION` | 7 | `typeset.rs` |

**已删除的魔数**：`SAFETY_MARGIN_PX`、`LINE_WIDTH_SAFETY_RATIO`（替换为校准值）。

---

## 6. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-05-25 | 初始文档 |
| 2.0 | 2026-07-06 | PageStreamer 删除；新增 reading/ 等模块 |
| **3.0** | **2026-07-07** | **四层架构重写；排版校准层 + 渲染诊断层；魔数清零；技术债清单** |

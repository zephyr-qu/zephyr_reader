# Zephyr Reader 阅读引擎架构

> 版本：4.0 | 最后更新：2026-07-08

---

## 0. 核心概念澄清：排版 vs 分页

本项目的两阶段流水线中，"排版"和"分页"是两个完全不同的概念：

```
阶段 1: Flutter 排版（Typesetting）
  用 TextPainter 做真实的文字布局。
  输出：字宽、行高、行宽比 → CalibrationData

阶段 2: Rust 分页（Pagination）
  用阶段 1 的实测值做数学计算。
  Rust 从不渲染文字、从未调用字体引擎。
  它只是用「每行能放几个字、每页能放几行」
  来标定每页的字符范围（startOffset, endOffset）。
  输出：PageDescriptor[]

阶段 3: Flutter 渲染（Rendering）
  用阶段 2 的页码范围裁剪文本，交给 SelectableText 渲染到屏幕。
```

| | 谁做 | 做什么 | 产出 |
|---|------|--------|------|
| **排版** | Flutter `TextPainter` | 字宽度量、行高测量、标量校准 | `CalibrationData` |
| **分页** | Rust `BlockPaginator` | 用校准值估算每页边界 | `PageDescriptor[]` |
| **渲染** | Flutter `SelectableText` | 在页码范围内渲染文字到屏幕 | 像素 |

Rust 分页引擎的本质是一个**确定性数学估算器**：它拿到 Flutter 实测的几何参数后，不再猜任何魔数，纯粹做「字宽 × 字数 = 行宽」「行高 × 行数 = 页高」的算术，输出页边界。这与 Flutter 的 `TextPainter` 排版是两个独立的过程。

---

## 1. 总览

### 1.1 三层职责

```
┌──────────────────────────────────────────────────────────────────────┐
│                  Flutter 排版层（Typesetting）                        │
│  TextPainter 真实排版  │  measureLayoutFingerprint()                 │
│  → 字宽 + 行高 + 行宽比  = CalibrationData（ground truth）          │
│  LayoutCalibrationStore (SharedPreferences cache)                   │
│  resolveLayoutCalibration() — 强制测完再分页                         │
│  computeLineBreakIndices() — 实测行断点（Phase 6）                   │
└────────────────────────────┬─────────────────────────────────────────┘
                             │ FRB (TypesetCalibration)
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│             Rust 阅读编排层（reading/ — 10 模块）                    │
│  ReadingOrchestrator (全局单例)                                      │
│    ├─ PaginationSession 生命周期                                     │
│    ├─ PaginationStore (LRU, cap=16) — 内存级分页引擎缓存             │
│    ├─ layout_cache (sled KV) — 持久化分页缓存                        │
│    ├─ provider_cache (LRU) — 章节内容 Provider 缓存                  │
│    ├─ line_breaks_store — Flutter 实测行断点缓存（Phase 6）          │
│    └─ block_state — BlockPaginationState + partial→full expand       │
└────────────────────────────┬─────────────────────────────────────────┘
                             │ paginate_chapter()
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│              Rust 分页层（Pagination — text/）                        │
│  数学估算器：用 Flutter 实测字宽/行高/行宽比                         │
│  计算每页能装多少字、页边界在哪。不渲染文字，不调字体引擎。           │
│                                                                      │
│  full_line_width = page_w × ratio        (ratio 来自 Flutter)       │
│  line_height = measured_h × (block_font / base_font)                │
│                                                                      │
│  行断点管线：                                                         │
│    paginate_from_line_breaks() — ICU 精确行断点优先（Phase 6）        │
│    compute_line_breaks_variable_width() — 贪心断行作为 fallback       │
│                                                                      │
│  → BlockPaginateResult { PageDescriptor[] }                         │
│                                                                      │
│  + parser/ + storage/ + search/ + dictionary/ (完整 Rust 引擎)        │
└────────────────────────────┬─────────────────────────────────────────┘
                             │ FRB (PageDescriptors)
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    Flutter 渲染层（Rendering）                        │
│  按 PageDescriptor 范围取文本 → SelectableText.rich 渲染到屏幕        │
│  PaginatedPageViewport (SizedBox + ClipRect) — 约束视口，不可滑动    │
│  [LineBreak] overflow_dp ≤ 0.5 — CI 门禁                             │
│  _ContentMeasurer (PostFrameCallback) — 渲染后诊断                   │
└──────────────────────────────────────────────────────────────────────┘
```

### 1.2 核心设计原则

| # | 原则 | 实现 |
|---|------|------|
| 1 | **Flutter 是 ground truth** | 所有排版参数由 Flutter TextPainter 实测，Rust 不猜任何魔数 |
| 2 | **测完再分页** | `resolveLayoutCalibration()` 先于 `paginate_chapter()`，首屏就对 |
| 3 | **配置变更自动重测** | `config_hash` 变化 → cache miss → 重测 → 重分页 |
| 4 | **块级字号按比例** | `effective_line_height = measured_base × (block_font / base_font)` |
| 5 | **标量校准优先，行断点精确化演进** | Phase 6 接入 Flutter 实测行断点（ICU 引擎），贪心算法降级为 fallback |
| 6 | **所有 panic 禁止跨越 FFI** | 所有导出函数返回 `Result<T, AppError>` |
| 7 | **零拷贝优先** | `Uint8List`/`String` 映射，避免 struct 序列化冗余 |
| 8 | **双引擎存储** | SQLite（结构化数据）+ sled（KV 缓存） |
| 9 | **统一 IR 路径** | TXT/EPUB → `ChapterContentIr` → `BlockPaginator`，无双引擎 |
| 10 | **阅读编排分离** | `reading/` 模块封装全局单例、缓存、session 生命周期；`api/` 为薄 FFI 适配层 |
| 11 | **staging miss → hold frame** | 跨章翻页无 spinner，用 hold frame 兜底（ADR-012） |

### 1.3 排版参数来源对照

| 参数 | 来源 | 传递方式 |
|------|------|----------|
| 6 组字宽 (cjk/ascii/...) | Flutter `TextPainter` 测量 | `TypesetCalibration` (FRB) |
| `effectiveLineWidthRatio` | Flutter 排版 200 个"中"反推 | 同上 |
| `measuredLineHeightPx` | Flutter `TextPainter` + `StrutStyle` 实测 | 同上 |
| `pageWidth` / `pageHeight` | `buildTypesetConfig`（已扣 vPad + 水平 padding） | `TypesetConfig` (FRB) |
| `letterSpacing` | 用户设置 | 同上 |
| `lineSpacing` / `paragraphSpacing` | 用户设置 | 同上 |
| 首行缩进 / 标点挤压 / 中西文间距 | 用户设置 | 同上 |
| `line_break_indices` (Phase 6) | Flutter `TextPainter._breakText` ICU 引擎 | `ChapterContentIr.lineBreakIndices` |

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

### 2.2 Phase 6 新增：`computeLineBreakIndices()`

```
_loadAndMeasureContent()  ──── 分页前额外步骤
  │
  ├─ TextPainler.layout(maxWidth: availableWidthDp)
  │   用实际行宽排版全量内容（plain text）
  │
  ├─ tp._breakText 或 lineMetrics 逐行提取
  │   读每行的 endOffset（字符索引）
  │
  ├─ 转换为 `Vec<u32>` 行断点索引数组
  │   [endOfLine0, endOfLine1, ..., plainTextLen]
  │
  └─ → storeLineBreaks(bookId, chapterIndex, configHash, indices)
       │
       ▼
       Rust paginate_from_line_breaks(indices, metrics, config_hash)
         └─ 直接用 ICU 行断点分页，跳过贪心算法
            Flutter 精确行断点 ≥ Rust 贪心行断点的分页精度
```

### 2.3 数据转换：`CalibrationData` → `TypesetCalibration`

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

### 2.4 缓存策略

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

### 2.5 配置构建：`buildTypesetConfig()`

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

### 2.6 时序保证

```
chapter_load_orchestrator.dart:
  resolveLayoutCalibration(params, prefs)  ← 必须先完成
       ↓
  computeLineBreakIndices() (Phase 6)     ← 分页前预测量行断点
       ↓
  storeLineBreaks()                       ← 写入 Rust 侧缓存
       ↓
  buildTypesetConfig(calibration)         ← 注入实测指纹
       ↓
  paginate_chapter(config)                ← Rust 消费 calibration + line_breaks
```

**首屏渲染必须等测量完成。** 先 paginate 再测量的 Bug B 已修复。Phase 6 增加了"分页前预测量行断点"步骤。

---

## 3. Rust 分页层 — 详细解析

> 输入：`TypesetConfig`（含 `TypesetCalibration`） + `ChapterContentIr`（可能携带 `line_break_indices`）
> 输出：`BlockPageDescriptor[]`（每页的 block 范围 + plain_char 范围）
> 关键文件：`block_paginator.rs` (~1620 行), `line_breaking.rs` (~250 行), `char_width.rs` (~130 行)

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
if ir.has_line_break_indices():
  └─ paginate_from_line_breaks(indices)    ← Phase 6：ICU 精确行断点
      直接用 Flutter 实测的行断点索引分页，不重新断行
else:
  └─ for block in ir.blocks:
       ├─ ContentBlock::Text → paginate_text_block()
       │    ├─ _break_paragraph() → compute_line_breaks_variable_width()
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

### 3.3 Phase 6：混合式行断点管线

```
Rust 分页引擎现在支持两条路径：

路径 A（Phase 6 新流程）—— Flutter ICU 精确行断点优先：
  paginate_from_line_breaks(indices, plain_text, metrics, config_hash)
    ├─ 验证 indices[last] == plain_text.len()
    ├─ 用 indices 替代 compute_line_breaks_variable_width()
    ├─ 直接用 Flutter TextPainter 的 ICU 断行结果映射
    └─ 精度 = ground truth（消除所有断行差异）

路径 B（传统路径）—— Rust 贪心断行：
  compute_line_breaks_variable_width(para, max_width, width_table, ...)
    ├─ 贪心逐字累加，精度依赖 calibration 准确度
    ├─ 标点挤压 / 避头避尾 / 中西文间距
    └─ overflow_dp ≤ 0.5 CI 门禁

选择逻辑（reading/pagination.rs:inject_line_breaks）：
  ├─ 有 line_break_indices 且有效 → 路径 A
  └─ 无 / 无效 → 路径 B（fallback）
```

### 3.4 断行算法：Rust vs Flutter

| 维度 | Rust `compute_line_breaks_variable_width` | Flutter `TextPainter` |
|------|------------------------------------------|----------------------|
| 算法 | 贪心逐字累加宽度 | ICU 断行引擎 |
| 字宽来源 | `CharWidthTable`（Flutter 实测校准） | 字体引擎 raster |
| 标点挤压 | 连续 CJK 标点后一个 ×0.65 | 字体 metrics 决定 |
| 中西文间距 | 固定 `auto_space_px` | 排版引擎动态 |
| 换行决策 | 超宽即断 | 语言规则 + 宽度 |
| 行尾规则 | 避尾开括号 / 避头闭标点 | ICU LineBreaker |

**差异控制**：Phase 6 引入路径 A 后，Rust 贪心行断点的使用场景缩减为首次分页（无 line_break_indices 时）。路径 A 的 overflow = 0.0。

### 3.5 分页结果产出

```rust
BlockPaginator::finish() → BlockPaginateResult {
    descriptors: [
        BlockPageDescriptor {
            page_index: 0,
            first_block_index: 0, last_block_index: 4,
            plain: { start: 0, len: 436 },
            is_last_page: false,
            image_layouts: [],
        },
        ...],
    config_hash: 0xABCD1234,  // 排版指纹，配置变则 miss
    is_partial: false,        // 是否仅首屏 2000 字
}
```

### 3.6 大章分片（>200 blocks）

```
if blocks.len() > CHUNK_BLOCK_COUNT (200):
  按 200-block 切片
  ├─ 每个切片独立 paginate_chapter_ir()
  ├─ chunk 边界保护：切割点前 5 block 内有图片 → 扩展切片
  └─ merge: 调整 page_index 连续
```

---

## 4. Rust 引擎子系统

> 分页层是 Rust 侧的核心，此外还有解析、存储、编排、搜索、词典等子系统。
> 共计 **97 个 `.rs` 源文件** + **25 个测试文件**，分层详见下文。

### 4.1 模块分层

```
┌───────────────────────────────────────────────────────────────┐
│                api/  FFI API 层（10 模块，77+ 函数）          │
│  core │ cover │ bilingual │ search │ epub │ phase2_ir        │
│  backup │ dictionary │ vocab_marker │ data/ (10 repo API)    │
└────────────────────┬──────────────────────────────────────────┘
                     │
         ┌───────────┼───────────┬──────────────┐
         ▼           ▼           ▼              ▼
  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────────┐
  │ parser/  │ │ reading/ │ │ storage/ │ │ dictionary/ │
  │ TXT/EPUB │ │ 编排层   │ │ SQLite + │ │ mdict 引擎  │
  │ Registry │ │ 全局单例 │ │ sled KV  │ │ 模糊匹配    │
  │ Provider │ │ LRU 缓存 │ │ 13 Repo  │ │ 音频提取    │
  └──────────┘ │ Session  │ └──────────┘ └─────────────┘
               │ Layout   │
               │ Cache     │
               └────┬──────┘
                     │
         ┌───────────┼───────────┬──────────────┐
         ▼           ▼           ▼              ▼
  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────────┐
  │  text/   │ │  domain/ │ │ search/  │ │ vocab_marker│
  │ 分页引擎  │ │ 类型定义 │ │ FTS5+jb  │ │ 词汇标记    │
  │ 断行算法  │ │ AppError │ │ BM25     │ │ 正则扫描    │
  │ 富文本    │ │ 验证     │ └──────────┘ └─────────────┘
  │ CSS      │ └──────────┘
  │ 双语对齐 │
  │ 章节检测 │
  │ 常量定义 │
  └──────────┘
```

### 4.2 `reading/` — 阅读编排层（10 模块，~2200 行）

阅读编排层是 Phase 5+6 的核心重构产出，将 `api/core.rs` 中的"阅读链"逻辑抽出为 crate-private 的内部模块。

| 文件 | 行数 | 职责 |
|------|------|------|
| `orchestrator.rs` | ~262 | `ReadingOrchestrator` 全局单例；对外暴露 22+ 方法（分页、session、章节读取、line_breaks 存取） |
| `session.rs` | ~341 | `PaginationSession` 生命周期管理；session_id 分配、创建、repaginate、dispose |
| `pagination.rs` | ~470 | 分页主逻辑：`paginate_chapter()`、`get_page_content()`、`get_page_blocks()`、`inject_line_breaks()` |
| `pagination_store.rs` | ~389 | `PaginationStore` LRU（cap=16）内存级分页引擎缓存；with_engine/with_popped 方法 |
| `block_state.rs` | ~482 | `BlockPaginationState`：分页结果的状态包装；`page_blocks()` / `page_plain_text()` / `expand_to_full()` |
| `layout_cache.rs` | ~137 | 持久化分页缓存（sled KV）：`try_get_block_cached()` / `try_save_block_cached()` |
| `provider_cache.rs` | ~93 | `PROVIDER_CACHE` LRU：章节内容 Provider 跨 chunk 复用 |
| `chapter_access.rs` | ~295 | 章节边界识别 + 格式检测 + `get_chapter()` / `get_chapter_partial()` / `get_chapter_first_spine_only()` |
| `chapter_ir.rs` | ~56 | `load_chapter_content_ir()`：从 Provider 读取并解析为 `ChapterContentIr` |
| `types.rs` | ~14 | `PaginationSessionHandle` FRB 暴露类型 |

**关键设计**：

- `ReadingOrchestrator`（全局 `LazyLock<Mutex<...>>` 单例）：所有阅读相关 FFI 函数经由此单例路由
- `PaginationStore`：`with_engine(key, f)` 模式借出 → 读取 → 归还（自动锁释放）；support `clone_for_adopt`（session 接管时跨 key 复制）
- `BlockPaginationState`：持分页后的 IR + 结果；`expand_to_full()` 方法在 partial→full 时重新分页
- `line_breaks_store`（`HashMap<(book_id, chapter, config_hash), Vec<u32>>`）：Phase 6 新增行断点缓存

### 4.3 `api/` — FFI API 层（10 模块）

| 模块 | 文件 | 内容 |
|------|------|------|
| `core` | `core.rs` | 核心 FFI：`parse_book`、`ChapterContent`、`test_connection` |
| `cover` | `cover.rs` | 封面提取 |
| `bilingual` | `bilingual.rs` | 双语对齐 FFI |
| `search` | `search.rs` | 全文搜索 FFI |
| `epub` | `epub.rs` | EPUB 特定 FFI（图片信息、图片格式） |
| `phase2_ir` | `phase2_ir.rs` | Phase 2 IR 相关 FFI |
| `backup` | `backup.rs` | 数据备份/恢复 |
| `dictionary` | `dictionary.rs` | 词典查询 FFI |
| `vocab_marker` | `vocab_marker.rs` | 词汇标记 FFI |
| `data/` | 10 文件 | 数据层 API：book / bookmark / category / chapter / init / note / progress / session / stats / vocabulary |

### 4.4 `text/` — 文本处理模块（9 模块，~3900 行）

| 文件 | 行数 | 职责 |
|------|------|------|
| `block_paginator.rs` | ~1620 | 核心分页引擎：`BlockPaginator`、`BlockLayoutMetrics`、`paginate_chapter_ir()`、`paginate_from_line_breaks()`、分片(chunk)逻辑、属性测试 |
| `line_breaking.rs` | ~250 | 断行算法：`compute_line_breaks_variable_width()`、`compute_line_breaks_from_indices()` |
| `char_width.rs` | ~132 | 字宽表：`CharWidthTable::from_calibration()`、`char_width(ch)`（6 组 Unicode 分类） |
| `bilingual.rs` | ~489 | 双语对齐引擎：`BilingualAligner` — 中文/英文分词、相似度计算（编辑距离 + 字符 n-gram）、段落级对齐、`align_bilingual_content()` |
| `chapter_detect.rs` | ~110 | 章节检测：`extract_chapters()` / `extract_chapters_with_pattern()` — 支持中英文正则匹配 |
| `constants.rs` | ~92 | 字符常量：`is_cjk_char()` / `is_cjk_punctuation()` / `is_start_avoid_punctuation()` / `is_end_avoid_punctuation()` |
| `css.rs` | ~304 | CSS 解析器：`parse_css()` / `resolve_font_size()` / `resolve_color()` — 用于 EPUB 富文本样式提取 |
| `rich_text.rs` | ~900 | HTML→富文本解析：`parse_html_to_rich_text()` — html5ever DOM 遍历 → `RichParagraph[]`，支持 CSS 样式继承、图片、嵌套标签 |
| `mod.rs` | 2 | 模块声明 + 公开 API：`paginate_chapter_ir`、`extract_chapters`、`align_bilingual_content`、`parse_html_to_rich_text` |

### 4.5 `parser/` — 解析器层

| 格式 | 解析器 | Provider | IR 转换 |
|------|--------|----------|---------|
| TXT | `TxtParser` | `TxtContentProvider` (mmap) | `txt_to_chapter_ir()` 按空行分段 |
| EPUB | `EpubParser` | `EpubContentProvider` (惰性) | `get_chapter_content_ir()` HTML→块 |

`BookParser` trait：`parse()` / `extract_metadata()` / `extract_chapter()`。
`ChapterContentProvider` trait：`read_text_range()` / `content_length()` / `format()`。

EPUB 子模块（8 文件）：`parse.rs` / `provider.rs` / `content_ir.rs` / `toc.rs` / `unzip.rs` / `asset_registry.rs` / `processed_image.rs` / `mod.rs`

TXT 子模块（5 文件）：`parse.rs` / `provider.rs` / `content_ir.rs` / `decode.rs` / `mod.rs`

### 4.6 `domain/` — 领域类型层

| 类型/文件 | 行数 | 说明 |
|-----------|------|------|
| `types/typeset.rs` | ~590 | `TypesetCalibration`（9 字段 `f32`，`#[frb(non_opaque)]`，`Copy`）、`TypesetConfig`（14 字段，手动 `Hash`，含 validation + fix_report + config_hash）、`TypesetConfigFixReport`、`LanguageType` 枚举 |
| `types/block_pagination.rs` | ~284 | `BlockPageDescriptor`（block 范围 + plain_char 范围 + image_layouts）、`BlockPaginateResult`（含 merge / page_index_at_char_offset / to_legacy） |
| `types/content_ir.rs` | ~259 | `ChapterContentIr`（blocks + plain_text + line_break_indices）、`ContentBlock`（Text / Image 两变体）、`TextBlock` / `ImageBlock`、`TextBlockStyle`、`BlockPlainRange` |
| `types/pagination.rs` | — | `PaginateResult` / `PageContent` / `PageBlockSlice`（旧版分页类型，Phase 2 兼容） |
| `types/rich_text.rs` | — | `RichParagraph` / `RichTextSpan` / `SpanStyle` |
| `types/plain_projection.rs` | — | `BlockJoinedPlainBuilder` / `PlainProjectionStyle` |
| `types/metadata.rs` | — | 元数据结构体 |
| `error.rs` | ~107 | `AppError`（18 变体，每个有稳定 `code()`，`#[frb]` + `thiserror`） |

### 4.7 `storage/` — 存储层

```
SQLite (sqlx, WAL, 4 连接)           sled KV
├── 13 个 Repository                 ├── layout_cache tree
│   ├── book_repo.rs                     ├── v2:{book}:{ch}:{hash}
│   ├── chapter_repo.rs                  ├── v2:chunk:{book}:{ch}:{idx}:{hash}
│   ├── bookmark_repo.rs                 └── v2:scroll_ir:{book}:{ch}
│   ├── note_repo.rs
│   ├── category_repo.rs          PaginationStore（LRU，容量 16）
│   ├── progress_repo.rs           内存级分页引擎缓存，键 (book_id, chapter_index, config_hash)
│   ├── session_repo.rs
│   ├── stats_repo.rs              BookIdCache（LRU，容量 16）
│   ├── vocab_repo.rs              路径 → book_id 映射加速
│   ├── dictionary_repo.rs
│   ├── layout_cache_repo.rs
│   └── ... (db.rs / models.rs / kv_store.rs)
└── search_index (FTS5 虚拟表)
```

### 4.8 `dictionary/` — 词典子系统

| 文件 | 行数 | 职责 |
|------|------|------|
| `mdict_engine.rs` | — | `MdictEngine`：MDX/MDD 解析，精确查找 + 编辑距离 2 模糊建议，音频提取 |
| `models.rs` | — | `DictEntry` / `DictSearchResult` 数据结构 |
| `mod.rs` | — | 模块声明 |

### 4.9 `vocab_marker/` — 词汇标记子系统

| 文件 | 行数 | 职责 |
|------|------|------|
| `mod.rs` | ~39 | `scan_for_vocabulary(text)`：正则扫描文本中的词汇表匹配 |
| `wordlists.rs` | — | 预编译词表 |

### 4.10 `utils/` — 工具模块

| 文件 | 行数 | 职责 |
|------|------|------|
| `mod.rs` | ~4 | 模块声明 |
| `security.rs` | — | `validate_file_path()`：路径穿越防护 |

### 4.11 `search/` — 全文搜索

- **引擎**：SQLite FTS5 + jieba-rs 中文分词
- **查询**：`MATCH` BM25 排序，500 字符窗口索引
- **范围**：章节级搜索（`search_engine.rs`）

---

## 5. Flutter 渲染层 — 详细解析

> 输入：`BlockPageDescriptor[]` + 章节文本
> 输出：屏幕像素
> 关键文件：`paginated_renderer.dart` (~580 行), `block_page_content.dart` (~520 行)

### 5.1 页面组装

```
BlockPageDescriptor { first_block_index: 0, last_block_index: 4, plain: {start:0, len:436} }
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
      child: ClipRect                // 裁剪溢出，不可滑动
        child: Align(topCenter)      // 顶部对齐
          child: content              // SelectableText / Column

bodyHeight = constraints.maxHeight - 2 × pageContentVerticalPadding(20dp)
           = 800dp (与 Rust pageHeightPx / dpr 一致)
```

**核心变化（Phase 6 fix-page-estimation-overflow）：**
- 移除了 DEBUG 遗留的 `SingleChildScrollView`
- `ClipRect` 是唯一裁剪层，内容溢出即截断
- `pageHeight` 传递时已扣除 2×vPad，保证 Rust 估算与 Dart 显示一致
- 双重保障：`SizedBox` 约束子 Widget 高度 + `ClipRect` 裁掉超出部分

### 5.3 诊断系统

```
buildBlockPageContent() → _measureSliceLayout() × N blocks
  ├─ 每个文本块独立测量: TextPainter + StrutStyle + maxWidth
  ├─ 累加: totalTpHeight = Σ(measured.height + blockPadding + paragraphSpacing)
  ├─ overflowDp = max(0, totalTpHeight - bodyHeight)
  └─ Logging.info([LineBreak] ... overflow=X.X)

_ContentMeasurer (PostFrameCallback)
  └─ Logging.info([ContentHeight] actualH=X.X)
```

| 日志关键字 | 含义 | 合格线 |
|-----------|------|--------|
| `[LineBreak] overflow` | TextPainter 总高度 - 视口高度 | ≤ 0.5 dp |
| `[LineWidth] ratio` | 渲染时用的行宽比 | 与测量一致 |
| `[ContentHeight] actualH` | RenderBox 实际高度 | ≤ bodyHeight |
| `[PageViewport] maxH/maxW` | 视口尺寸 | 验证约束生效 |

### 5.4 渲染器架构

```
PaginatedModeRenderer (StatelessWidget)
  ├─ PageView.builder / PageTurnShell
  │   itemBuilder → _buildPageContent(pageIndex)
  │       ├─ buildSinglePageContent()       ← 文本页
  │       └─ _buildCrossChapterPage()       ← 跨章虚拟页
  │           ├─ _buildStagingPageFromStaging()  ← block 预渲染
  │           └─ _buildHoldFrame()               ← staging miss 兜底
  │
  ├─ PageCurlWidget (仿真翻页)
  │   └─ pageBuilder → buildSinglePageContent()
  │
  └─ ADR-012: staging miss → hold frame（末页/首页），不 spinner
```

### 5.5 自动化测试

| Layer | 文件 | 数量 | 验证内容 |
|-------|------|------|---------|
| A | `layout_calibration_store_test.dart` | 5 | 缓存 roundtrip / key / corrupt / defaults |
| A | `typeset_calibrator_test.dart` 扩展 | 4 | cache hit / line_height / ratio / drift |
| B | `block_paginator.rs` mod tests | 33+ | ratio / line_height / page_count / fallback / chunked / 属性测试 |
| C | `layout_fingerprint_alignment_test.dart` | 4 | CI 核心：TextPainter vs Rust ≤1 行 |
| D | `block_page_overflow_test.dart` | 2 | Widget 视口几何不溢出 |
| E | `pagination_session_test.rs` / `reading_orchestrator_test.rs` | — | 集成测试：session 创建、repaginate、跨章 staging |
| F | Rust 整合测试 (25 文件) | — | `api_test.rs`、`unit_text_test.rs`、`epub_reading_chain_test.rs` 等 |

---

## 6. 清理技术债记录

| # | 内容 | 状态 |
|---|------|------|
| 1 | `calibrateSafely()` 死代码 | ✅ 已删除 |
| 2 | `kRustLineWidthSafetyRatio` 别名 | ✅ 已统一到 `kDefaultEffectiveLineWidthRatio` |
| 3 | `kRustCharWidthScale` (恒为 1.0) | ✅ 已内联 |
| 4 | Rust `layout_slice_text_segments` (仅测试) | ✅ `#[cfg(test)]` |
| 5 | Rust `compute_line_breaks_from_indices` (仅测试) | ✅ `#[cfg(test)]` |
| 6 | `estimateRustLinesForText` 诊断偏差 2-4 行 | 🟡 待收敛（Phase 6 路径 A 已消除偏差） |
| 7 | `DEFAULT_IMAGE_HEIGHT_RATIO = 0.55` | 🟡 待评估 |
| 8 | Rust 贪心 → Flutter TextPainter 行边界传递 | 🟢 Phase 6 已实现路径 A（ICU 行断点传递） |
| 9 | `SAFETY_MARGIN_PX` / `LINE_WIDTH_SAFETY_RATIO` 魔数 | ✅ 已删除（校准值替换） |
| 10 | `PaginatedPageViewport` 遗留 `SingleChildScrollView` | ✅ 已移除（`ClipRect` + `Align`） |
| 11 | `pageHeight` 未扣除 vPad 导致内容溢出 | ✅ 已修复（`buildTypesetConfig` 扣减 2×vPad） |

---

## 7. 关键常量

| 常量 | 值 | 位置 |
|------|-----|------|
| `DEFAULT_EFFECTIVE_LINE_WIDTH_RATIO` | 0.97 | `block_paginator.rs` (仅 fallback) |
| `FLUTTER_BREAK_CHAR_WIDTH_SCALE` | 1.0 | `block_paginator.rs` |
| `GREEDY_LINE_WIDTH_RATIO` | 1.0 | `block_paginator.rs` |
| `DEFAULT_IMAGE_HEIGHT_RATIO` | 0.55 | `block_paginator.rs` |
| `CHUNK_BLOCK_COUNT` | 200 | `block_paginator.rs` |
| `PAGINATION_ENGINE_CACHE_CAPACITY` | 16 | `pagination_store.rs` |
| `BOOK_ID_CACHE_CAPACITY` | 16 | `reading/mod.rs` |
| `pageContentVerticalPadding` | 20.0 dp | `reader_render_config.dart` |
| `kDefaultEffectiveLineWidthRatio` | 0.97 | `typeset_calibrator.dart` |
| `LAYOUT_ALGORITHM_VERSION` | 7 | `typeset.rs` |
| `Rust 源文件数` | 97 | `find rust/src -name '*.rs'` |
| `Rust 测试文件数` | 25 | `rust/tests/*.rs` |

**已删除的魔数**：`SAFETY_MARGIN_PX`、`LINE_WIDTH_SAFETY_RATIO`（替换为校准值）。
**Phase 6 新增**：`line_break_indices` 行断点管道（替换贪心断行为精确断行）。

---

## 8. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-05-25 | 初始文档 |
| 2.0 | 2026-07-06 | PageStreamer 删除；新增 reading/ 等模块 |
| 3.0 | 2026-07-07 | 四层架构重写；排版校准层 + 渲染诊断层；魔数清零；技术债清单 |
| **4.0** | **2026-07-08** | **全面更新：reading/10 模块编排层；Phase 6 混合式行断点管线 (`paginate_from_line_breaks`)；bilingual/css/rich_text 等 9 文本子模块；dictionary/mdict + vocab_marker + utils 新增子系统；97 源文件 + 25 测试文件全局统计；pageHeight vPad 修复记录；完善 1.2 原则 #10-#11** |

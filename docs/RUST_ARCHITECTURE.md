# Zephyr Reader 阅读引擎架构

> 版本：3.0 | 最后更新：2026-07-07

---

## 1. 总览

### 1.1 四层架构

```
┌──────────────────────────────────────────────────────────────────┐
│                     Flutter 排版校准层                             │
│  TypesetCalibrator  │  measureLayoutFingerprint()               │
│  TypesetMeasureParams  │  CalibrationData → TypesetCalibration  │
│  LayoutCalibrationStore (SharedPreferences cache)               │
│  resolveLayoutCalibration() — 强制测完再分页                     │
└────────────────────────────┬─────────────────────────────────────┘
                             │ FRB (TypesetCalibration)
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                      Rust 分页引擎层                              │
│  TypesetConfig → BlockLayoutMetrics → BlockPaginator            │
│  CharWidthTable (校准驱动)  │  compute_line_breaks (标量断行)     │
│  full_line_width = page_w × ratio  (无魔数)                     │
│  line_height = measured_line_height_px × (block_font/base_font) │
└────────────────────────────┬─────────────────────────────────────┘
                             │ FRB (PageDescriptors)
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Rust 阅读引擎 & 存储层                          │
│  api/ │ reading/ │ parser/ │ storage/ │ search/ │ dictionary/   │
│  77 个 #[frb] FFI 函数  │  SQLite + sled 双引擎                   │
└────────────────────────────┬─────────────────────────────────────┘
                             │ FRB (content + descriptors)
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Flutter 渲染 & 诊断层                           │
│  PaginatedModeRenderer → PaginatedPageViewport                  │
│  SelectableText.rich + StrutStyle + TextHeightBehavior          │
│  [LineBreak] overflow_dp ≤ 0.5  CI 门禁                         │
│  Layer A-D 自动化测试套件                                        │
└──────────────────────────────────────────────────────────────────┘
```

### 1.2 核心设计原则

| # | 原则 | 实现 |
|---|------|------|
| 1 | **Flutter 是 ground truth** | 所有排版参数由 Flutter TextPainter 实测，Rust 不猜任何魔数 |
| 2 | **测完再分页** | `resolveLayoutCalibration()` 先于 `paginate_chapter()`，首屏就对 |
| 3 | **配置变更自动重测** | `config_hash` 变化 → cache miss → 重测 → 重分页 |
| 4 | **块级字号按比例** | `effective_line_height = measured_base × (block_font / base_font)` |
| 5 | **标量校准优先** | 断行位置差异通过 overflow 指标验收，不启动「行边界传递」重构 |
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

## 2. Flutter 排版校准层

### 2.1 测量入口：`measureLayoutFingerprint()`

```
TypesetMeasureParams (width/height/fontSize/lineHeight/letterSpacing/fontFamily/dpr)
  → _measureStyles()          # buildTextStyle() + buildStrutStyle() 统一栈
  → _measureAvgCharWidth()    # TextPainter 测量 6 组 Unicode 区间
  → measureEffectiveLineWidthRatio()  # 排版 200 个"中"，反推有效行宽比
  → measureLineHeightDp()     # TextPainter + StrutStyle 实测单行高度
  → CalibrationData { ratio, lineHeightDp, 6 组字宽, dpr }
```

**关键**：`_measureAvgCharWidth` 使用 `TextPainter`（非旧版 `ParagraphBuilder`），与渲染同一套栈。

### 2.2 `CalibrationData` → `TypesetCalibration`

```dart
// Dart 侧
CalibrationData → calibrationToRust() → TypesetCalibration {
  cjkWidth: data.cjkWidth * dpr,        // dp → px
  effectiveLineWidthRatio: data.ratio,   // 直传
  measuredLineHeightPx: data.lineHeightDp * dpr,  // dp → px
}
```

### 2.3 本地缓存

```
LayoutCalibrationStore (SharedPreferences)
  key = "layout_calib_v1_{Object.hash(params...)}"
  │
  ├─ cache hit → 0ms，跳过测量
  └─ cache miss → measureLayoutFingerprint → save
```

**触发重测的条件**：任何 `TypesetMeasureParams` 字段变化（字体/字号/行距/页边距/DPR）→ hash 变化 → cache miss。

### 2.4 时序保证

```
resolveLayoutCalibration(params, prefs)
  ├─ [LayoutCalib] cache hit → return cached
  └─ miss → measureLayoutFingerprint → save → return
        ↓
buildTypesetConfig(calibration)  ← 带指纹
        ↓
paginate_chapter(config)          ← Rust 只消费
```

---

## 3. Rust 分页引擎层

### 3.1 数据流

```
TypesetConfig (FRB)
  ├─ page_width, page_height, font_size, line_spacing, letter_spacing
  ├─ paragraph_spacing, first_line_indent, auto_space_ratio
  ├─ punctuation_squeeze, font_family
  └─ calibration: TypesetCalibration
       ├─ cjk_width, ascii_width, digit_width, punct_width, latin_ext_width, other_width
       ├─ effective_line_width_ratio  ← 替换原 (w-2)×0.97 魔数
       └─ measured_line_height_px     ← 替换原 fontSize×lineSpacing 理论值

                ▼
BlockLayoutMetrics::from_config(&config)
  ├─ full_line_width_px = page_width_px × effective_line_width_ratio
  ├─ line_height_px     = measured_line_height_px || (font_size × line_spacing)
  └─ width_table        = CharWidthTable::from_calibration()
```

### 3.2 块级字号行高缩放

```rust
// paginate_text_block — 每个块独立处理
let effective_font_size = effective_font_size_px(&block.style, &self.metrics);
let effective_line_height = block.style.line_height
    .map(|lh| lh * effective_font_size)
    .unwrap_or_else(|| {
        let height_ratio = effective_font_size / self.metrics.font_size_px.max(1.0);
        (self.metrics.line_height_px * height_ratio).max(1.0)
    });
```

标题 (fs=24) 行高 = 84 × 24/18 = 112px，与 Flutter 渲染一致。
小字 (fs=12) 行高 = 84 × 12/18 = 56px。

### 3.3 断行策略

| 组件 | 路径 | 说明 |
|------|------|------|
| `compute_line_breaks_variable_width` | `line_breaking.rs` | **生产路径**：逐字累加宽度 + 避头尾标点 |
| `compute_line_breaks_from_indices` | 同上（`#[cfg(test)]`） | 测试用 |
| `greedy_split_text_lines` | `block_paginator.rs` | 贪心兜底（layout 偏宽时对齐） |

算法：逐字符查 `CharWidthTable` → 累加宽度 → 超宽断行 → 避尾推下一行 → 避头回拉一行。含标点挤压 (×0.65) + 中西文间距。

**与 Flutter ICU 的差异**：Rust 贪心 vs Flutter ICU 断行。通过 `[LineBreak] overflow_dp ≤ 0.5` CI 门禁控制。

---

## 4. Rust 阅读引擎 & 存储层

### 4.1 模块分层

```
┌───────────────────────────────────────────────────────────┐
│                    api/  FFI API 层                       │
│  core │ cover │ bilingual │ search │ epub │ phase2_ir │
│  data/ (11 子模块) │ backup │ dictionary │ vocab_marker │
└────────────────────┬──────────────────────────────────────┘
                     │ 调用
         ┌───────────┼─────────────────┐
         ▼           ▼                 ▼
┌────────────┐ ┌──────────┐ ┌───────────┐
│  parser/   │ │ reading/ │ │ storage/  │
│ 格式解析器  │ │ 阅读引擎  │ │ 数据库层  │
├────────────┤ ├──────────┤ ├───────────┤
│ TXT/EPUB   │ │ session  │ │ models.rs │
│ Registry   │ │ 缓存     │ │ KvStore   │
│ Provider   │ │ staging  │ │ DB 连接池  │
│ 封面提取   │ │ orchestr.│ └───────────┘
└────────────┘ └────┬─────┘
                     │
                     ▼
              ┌──────────┐
              │  text/   │
              │ 文本处理  │
              ├──────────┤
              │ line_break│
              │ block_pag │
              │ char_width│
              │ 双语对齐  │
              │ 富文本CSS │
              └──────────┘
                     ▲
                     │
┌────────────────────┴─────────────────┐
│  domain/ 领域层                      │
│  error │ typeset │ block_pagination  │
│  content_ir │ pagination │ metadata  │
└──────────────────────────────────────┘
```

### 4.2 模块职责速查

| 模块 | 功能 |
|------|------|
| `api/` | 77 个 `#[frb]` 函数，FFI 边界 |
| `api/data/` | 存储 CRUD 包装器，`async_storage!` 宏 |
| `domain/` | 领域类型 + 错误定义 |
| `parser/` | TXT/EPUB 格式解析 + Registry + Provider |
| `text/` | 断行 / 块分页 / 字符宽度 / 章节检测 / 双语 / 富文本CSS |
| `reading/` | 分页 session / 缓存 / orchestrator / 块状态 |
| `storage/` | SQLite + sled 双引擎 + 13 Repository |
| `search/` | FTS5 + jieba-rs |
| `dictionary/` | MDict 引擎 |
| `utils/` | 文件 I/O + 路径安全 |

### 4.3 分页缓存

| 缓存层 | 引擎 | Key 格式 |
|--------|------|----------|
| LRU in-memory | `PaginationStore` (容量 16) | `PaginationKey(book_id, chapter_index, config_hash)` |
| sled KV 全章 | `KvStore` layout_cache tree | `v2:{book_id}:{chapter_idx}:{config_hash:016x}` |
| sled KV chunk | 同上 | `v2:chunk:{book_id}:{chapter_idx}:{chunk}:{hash}` |
| SharedPreferences | `LayoutCalibrationStore` | `layout_calib_v1_{hash}` |

### 4.4 存储架构

```
StorageManager (全局 OnceCell)
├── SQLite pool (sqlx, WAL 模式, 4 连接)
│   └── 13 表 + FTS5 search_index 虚拟表
└── sled KV (data_dir/cache)
    └── layout_cache tree
```

---

## 5. Flutter 渲染 & 诊断层

### 5.1 渲染管线

```
PageDescriptor (FRB) → PaginatedModeRenderer
  │
  ├─ plain text 模式 → buildSinglePageContent()
  │     → SelectableText.rich + StrutStyle
  │
  └─ contentBlocks 模式 → buildBlockPageContent()
        ├─ 逐块渲染 Text / Image
        ├─ 块级字号/行高/s margins 独立计算
        └─ layoutCalibration 传入诊断层
              │
              ▼
        [LineBreak] TOTAL ... overflow=0.0 flutLines=22 rustEstLines=22
        [LineWidth] ... ratio=0.969
        [ContentHeight] ... actualH=670dp vp=800dp
```

### 5.2 视口约束

```dart
PaginatedPageViewport(maxHeight: bodyHeight, maxWidth: maxWidth)
  → SizedBox(height: bodyHeight, width: maxWidth)
    → ClipRect  // 防溢出裁剪
      → Align(topCenter)
        → child  // SelectableText.rich / Column(blocks)
```

`bodyHeight = constraints.maxHeight - 2 × pageContentVerticalPadding` (20dp × 2 = 40dp)，与 Rust 的 `pageHeightPx = (height - 40) × dpr` 精确对齐。

### 5.3 诊断系统

| 日志行 | 信号 | CI 阈值 |
|--------|------|---------|
| `[LineBreak] overflow_dp` | 渲染高度 - 视口高度 | ≤ 0.5 dp |
| `[LineWidth] ratio` | 实测行宽比 | ≠ 0.97（已校准） |
| `[ContentHeight] actualH` | 实际渲染高度 | ≤ vp + 0.5 dp |
| `[LayoutCalib] cache hit` | 缓存命中 | 二次启动有 hit |
| `[LineWidthCalib] ratio` | 校准测量值 | ∈ [0.85, 1.0] |

### 5.4 自动化测试

| Layer | 文件 | 用例数 | 门禁 |
|-------|------|--------|------|
| A | `layout_calibration_store_test.dart` + `typeset_calibrator_test.dart` | 9 | 缓存 / JSON / ratio |
| B | `block_paginator.rs` mod tests | 4 | Rust ratio / line_height / page count |
| C | `layout_fingerprint_alignment_test.dart` | 4 | TextPainter vs Rust ≤1 行 |
| D | `block_page_overflow_test.dart` | 2 | 视口几何 |

---

## 6. 清理技术债记录

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

## 7. 关键常量

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

## 8. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-05-25 | 初始文档 |
| 2.0 | 2026-07-06 | PageStreamer 删除；新增 reading/ 等模块 |
| **3.0** | **2026-07-07** | **四层架构重写；排版校准层 + 渲染诊断层；魔数清零；技术债清单** |

# Zephyr Reader Rust 引擎架构

> 版本：5.0 | 最后更新：2026-07-13

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
┌──────────────────────────────────────────────────────────────────────┐
│                           Rust 核心引擎                               │
│                                                                      │
│  api/  — FFI API 层（10 模块，薄适配层）                             │
│    ├─ reader.rs ..... 3 个 FRB 函数（get_chapter / store_line_breaks │
│    │                                  / get_chapter_content_ir）     │
│    ├─ import.rs ..... parse_book（路径验证 → 解析 → DB 写入）        │
│    ├─ bilingual .... 双语对齐（对齐、高亮对）                         │
│    ├─ cover ........ 封面提取                                        │
│    ├─ dictionary ... 词典查询（lookup_mdict / suggest_mdict）        │
│    ├─ epub ......... EPUB 图片/格式信息                               │
│    ├─ search ....... 全文搜索 FFI                                    │
│    ├─ vocab_marker . 词汇正则扫描                                    │
│    ├─ backup ....... 数据备份/恢复                                   │
│    └─ data/ ........ 10 个数据层 API（book/bookmark/category/...）   │
│                                                                      │
│  90 个 .rs 源文件 + 21 个测试文件，分层如下：                        │
└──────────────────────────────────────────────────────────────────────┘

┌───────────┐  ┌───────────┐  ┌───────────┐  ┌──────────────┐
│  parser/  │  │ reading/  │  │ storage/  │  │ dictionary/  │
│ TXT/EPUB  │  │ 编排层    │  │ SQLite +  │  │ mdict 引擎   │
│ Registry  │  │ 全局单例  │  │ sled KV   │  │ 模糊匹配     │
│ Provider  │  │ 缓存      │  │ 13 Repo   │  │ 音频提取     │
└───────────┘  │ 章节读取  │  └───────────┘  └──────────────┘
               │ IR 加载   │
               └───────────┘

┌────────────┐  ┌────────────┐  ┌──────────────┐  ┌──────────────┐
│  text/     │  │  domain/   │  │  search/     │  │ vocab_marker │
│ 双语对齐   │  │ 类型定义   │  │ FTS5+jieba  │  │ 词汇标记    │
│ 章节检测   │  │ AppError   │  │ BM25         │  │ 正则扫描    │
│ CSS 解析   │  │ 验证       │  └──────────────┘  └──────────────┘
│ 富文本     │  └────────────┘
│ (分页引擎  │
│  已删除)   │
└────────────┘
```

### 1.2 核心设计原则

| # | 原则 | 实现 |
|---|------|------|
| 1 | **Rust 只做内容服务** | 不再做任何分页/装箱计算；分页全在 Flutter 侧 |
| 2 | **sled + SQLite 双存储** | SQLite（结构化数据）+ sled（KV 缓存：scroll_ir_cache） |
| 3 | **所有 panic 禁止跨越 FFI** | 所有导出函数返回 `Result<T, AppError>` |
| 4 | **零拷贝优先** | `Uint8List`/`String` 映射，避免 struct 序列化冗余 |
| 5 | **统一 IR 路径** | TXT/EPUB → `ChapterContentIr` → Flutter 消费，无双引擎 |
| 6 | **阅读编排集中化** | `reading/` 模块封装全局单例、缓存、章节读取逻辑 |
| 7 | **持有帧替代 spinner** | 跨章翻页无 spinner，用 hold frame 兜底 |

### 1.3 排版参数来源对照

> 分页已迁移至 Flutter，Rust 不再消费排版参数。以下仅作历史参考。

| 参数 | 来源 | 状态 |
|------|------|------|
| 6 组字宽 (cjk/ascii/...) | Flutter `TextPainter` | Flutter 侧消费 |
| `effectiveLineWidthRatio` | Flutter 排版 | Flutter 侧消费 |
| `measuredLineHeightPx` | Flutter `TextPainter` 实测 | Flutter 侧消费 |
| `pageWidth` / `pageHeight` | `buildTypesetConfig` | Flutter 侧消费 |
| `letterSpacing` / `lineSpacing` | 用户设置 | Flutter 侧消费 |
| `line_break_indices` | Flutter `TextPainter._breakText` | Flutter 侧消费 |

---

## 2. Rust 引擎子系统

> Rust 侧不再承担分页计算。分页引擎（`block_paginator.rs` ~1620 行）已在 Phase 7 彻底删除。
> 以下为当前 Rust 引擎的全部模块。

### 2.1 `api/` — FFI API 层（10 模块）

| 模块 | 文件 | 说明 |
|------|------|------|
| `reader.rs` | 3 函数 | 当前仅 `get_chapter`、`store_line_breaks`、`get_chapter_content_ir` |
| `import.rs` | 1 函数 | `parse_book` — 路径验证 → 解析 → DB 写入 |
| `cover.rs` | 封面提取 FFI | |
| `bilingual.rs` | 双语对齐 FFI | `align_bilingual_content`、高亮对 CRUD |
| `search.rs` | 全文搜索 FFI | |
| `epub.rs` | EPUB 图片/格式信息 | |
| `dictionary.rs` | 词典查询 FFI | `lookup_mdict`、`suggest_mdict`、`segment_text`、`extract_audio` |
| `vocab_marker.rs` | 词汇标记 FFI | |
| `backup.rs` | 数据备份/恢复 | |
| `data/` | 10 文件 | 数据层 API: book / bookmark / category / chapter / init / note / progress / session / stats / vocabulary |

**关键变化**（vs v4.0）：
- `api/core.rs` → `api/reader.rs`，删除 70+ 旧分页相关 FFI 函数
- 新增 `api/import.rs`（core_api→import_api 迁移）
- `FirstSpineResult`、`compute_config_hash` 已从 FRB 及代码中删除
- `TypesetConfig` 类型保留、但不再被任何 Rust 生产代码消费

### 2.2 `reading/` — 阅读编排层（6 模块，~900 行）

Phase 5+6 的核心重构产出，Phase 7 清理后进一步精简。

| 文件 | 行数 | 职责 |
|------|------|------|
| `orchestrator.rs` | ~110 | `ReadingOrchestrator` 全局单例；提供 `get_chapter`、`get_chapter_content_ir`、`store_line_breaks` |
| `chapter_access.rs` | ~130 | 章节边界 + 格式识别 + `get_chapter()` 原始文本读取 |
| `chapter_ir.rs` | ~50 | `load_chapter_content_ir()` — IR 加载，sled 缓存优先 |
| `layout_cache.rs` | ~60 | sled `scroll_ir_cache` 读写（分页缓存已不存在） |
| `provider_cache.rs` | ~90 | `PROVIDER_CACHE` LRU（章节 provider 跨请求复用） |
| `mod.rs` | ~40 | 模块声明 + BOOK_ID_CACHE |

**已删除**（Phase 7）：`pagination_store.rs`(~389 行)、`block_state.rs`(~482 行)、`pagination.rs`(~470 行)、`types.rs`(~14 行)

### 2.3 `text/` — 文本处理模块（7 模块，~2100 行）

| 文件 | 行数 | 职责 | 状态 |
|------|------|------|------|
| `bilingual.rs` | ~482 | 双语对齐引擎：`BilingualAligner` — 中英文分词、相似度计算、段落级对齐 | 生产 |
| `chapter_detect.rs` | ~127 | 章节检测：`extract_chapters()` / `extract_chapters_with_pattern()` | 生产 |
| `css.rs` | ~303 | CSS 解析器：`parse_css()` / `resolve_font_size()` / `resolve_color()` | 生产 |
| `rich_text.rs` | ~899 | HTML→富文本解析：`parse_html_to_rich_text()` — html5ever DOM → `RichParagraph[]` | 生产 |
| `char_width.rs` | ~131 | `CharWidthTable` 字宽表（6 组 Unicode 分类）；仅 `#[cfg(test)]` 消费 | 🟡 死代码 |
| `constants.rs` | ~99 | 字符常量：`is_cjk_char()` / 标点判断；仅 `chapter_detect.rs` 生产消费 + `line_breaking.rs` 测试 | 生产 |
| `line_breaking.rs` | ~155 | 贪心断行算法；全文件 `#[cfg(test)]`（`block_paginator.rs` 已删） | 🟡 死代码 |
| `mod.rs` | 14 | 模块声明 + 公开 re-export | — |

**已删除**（Phase 7）：`block_paginator.rs`(~1620 行) —— Rust 分页引擎，全量 Flutter 迁移后删除。

### 2.4 `parser/` — 解析器层

| 格式 | 解析器 | Provider | IR 转换 |
|------|--------|----------|---------|
| TXT | `TxtParser` | `TxtContentProvider` (mmap) | `txt_to_chapter_ir()` 按空行分段 |
| EPUB | `EpubParser` | `EpubContentProvider` (惰性) | `get_chapter_content_ir()` HTML→块 |

EPUB 子模块（8 文件）：`parse.rs` / `provider.rs` / `content_ir.rs` / `toc.rs` / `unzip.rs` / `asset_registry.rs` / `processed_image.rs` / `mod.rs`

TXT 子模块（5 文件）：`parse.rs` / `provider.rs` / `content_ir.rs` / `decode.rs` / `mod.rs`

### 2.5 `domain/` — 领域类型层

| 类型/文件 | 行数 | 说明 |
|-----------|------|------|
| `types/typeset.rs` | ~588 | `TypesetCalibration`（9 字段 `f32`，`#[frb(non_opaque)]`）、`TypesetConfig`（14 字段，含 config_hash）、`LanguageType`、`LAYOUT_ALGORITHM_VERSION`（v14） |
| `types/content_ir.rs` | ~258 | `ChapterContentIr`、`ContentBlock`（Text / Image）、`TextBlockStyle` |
| `types/pagination.rs` | ~64 | `SearchResult`、`IndexStats`（搜索引擎用） |
| `types/plain_projection.rs` | ~294 | `BlockJoinedPlainBuilder`、`slice_by_char_range()` |
| `types/rich_text.rs` | ~185 | `RichParagraph`、`RichTextSpan`、`SpanStyle` |
| `types/metadata.rs` | ~52 | 元数据结构体 |
| `error.rs` | ~107 | `AppError`（18 变体，`#[frb]` + `thiserror`） |

### 2.6 `storage/` — 存储层

```
SQLite (sqlx, WAL, 4 连接)           sled KV
├── 13 个 Repository                 ├── scroll_ir_cache tree
│   ├── book_repo.rs                     ├── v2:{book}:{ch}:{hash}
│   ├── chapter_repo.rs                  └── v2:scroll_ir:{book}:{ch}
│   ├── bookmark_repo.rs
│   ├── note_repo.rs              BookIdCache（LRU，容量 16）
│   ├── category_repo.rs          路径 → book_id 映射
│   ├── progress_repo.rs
│   ├── session_repo.rs
│   ├── stats_repo.rs
│   ├── vocab_repo.rs
│   ├── dictionary_repo.rs
│   ├── layout_cache_repo.rs
│   └── ... (db.rs / models.rs / kv_store.rs)
└── search_index (FTS5 虚拟表)
```

### 2.7 `dictionary/` — 词典子系统

| 文件 | 行数 | 职责 |
|------|------|------|
| `mdict_engine.rs` | — | `MdictEngine`：MDX/MDD 解析，精确查找 + 编辑距离 2 模糊建议，音频提取 |
| `models.rs` | — | `DictEntry` / `DictSearchResult` 数据结构 |
| `mod.rs` | — | 模块声明 |

### 2.8 `search/` — 全文搜索

- **引擎**：SQLite FTS5 + jieba-rs 中文分词
- **查询**：`MATCH` BM25 排序，500 字符窗口索引
- **范围**：章节级搜索（`search_engine.rs`）

### 2.9 `vocab_marker/` — 词汇标记

- `scan_for_vocabulary(text)`：正则扫描文本中的词汇表匹配

### 2.10 `utils/` — 工具模块

- `validate_file_path()`：路径穿越防护

---

## 3. Flutter 分页 & 渲染层

> 分页引擎全部迁移至 Flutter 侧，本节只做概要说明，详见 Flutter 架构文档（`FLUTTER_ARCHITECTURE.md` v2+）。

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

### 3.2 渲染层变化

- `PaginatedPageViewport`：`ClipRect` + `Align`，内容溢出即截断
- `pageHeight` 传递时已扣除 2×vPad，保证 Flutter 显示与 Rust 估算一致
- 诊断：`_ContentMeasurer`（PostFrameCallback）记录内容高度

---

## 4. 清理记录

### 4.1 Phase 7 完成项

| # | 内容 | 状态 |
|---|------|------|
| 1 | `block_paginator.rs`（~1620 行） | ✅ 已删除（ce1eb15） |
| 2 | `api/core.rs` → `api/reader.rs` | ✅ 已重命名，删除 70+ 分页 FFI |
| 3 | `FirstSpineResult` FRB 类型 | ✅ 已删除 |
| 4 | `compute_config_hash` FRB 函数 | ✅ 已删除 |
| 5 | `reading/pagination_store.rs` (~389 行) | ✅ 已删除 |
| 6 | `reading/block_state.rs` (~482 行) | ✅ 已删除 |
| 7 | `reading/types.rs` (~14 行) | ✅ 已删除 |
| 8 | `reading/pagination.rs` (~470 行) | ✅ 已删除 |
| 9 | `api/import.rs` core_api→import_api 迁移 | ✅ 已完成 |
| 10 | `SpikeSession` → `FlutterPaginationSession` 命名清理 | ✅ 已完成 |
| 11 | ADR/Phase 注释清理（lib/features/reader/） | ✅ 已完成 |
| 12 | `#[allow(dead_code)]` 清理（Rust） | ✅ 仅 `storage/kv_store.rs:20` 保留（sled db 保活） |
| 13 | `PackedPage` ↔ `PageDescriptor` 合并 | ✅ Flutter 统一使用纯 Dart 类型 |

### 4.2 保留的死代码待清理

| # | 文件 | 说明 | 状态 |
|---|------|------|------|
| 1 | `text/char_width.rs` | 仅 `#[cfg(test)]` 消费，生产零引用 | 🟡 待清理 |
| 2 | `text/line_breaking.rs` | 全文件 `#[cfg(test)]`，消费者 `block_paginator.rs` 已删 | 🟡 待清理 |
| 3 | ~~`domain/types/pagination.rs` — `PageContent`、`ChapterPaginationMode`~~ | ✅ 已删除（保留 `SearchResult`、`IndexStats`） |
| 4 | ~~`domain/types/block_pagination.rs`~~ | ✅ 已删除（`BlockPageDescriptor` 等无生产者） |

---

## 5. 关键常量

| 常量 | 值 | 位置 |
|------|-----|------|
| `LAYOUT_ALGORITHM_VERSION` | 14 | `domain/types/typeset.rs` |
| `BOOK_ID_CACHE_CAPACITY` | 16 | `reading/mod.rs` |
| `MAX_FILE_SIZE` | 500 MB | `api/import.rs` |
| `Rust 源文件数` | 90 | `find rust/src -name '*.rs'`（不含 `frb_generated.rs`） |
| `Rust 测试文件数` | 21 | `rust/tests/*.rs` |

---

## 6. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0 | 2026-05-25 | 初始文档 |
| 2.0 | 2026-07-06 | PageStreamer 删除；新增 reading/ 等模块 |
| 3.0 | 2026-07-07 | 四层架构重写；排版校准层 + 渲染诊断层；魔数清零 |
| 4.0 | 2026-07-08 | 全面更新：reading/10 模块编排层；Phase 6 混合式行断点管线；bilingual/css/rich_text 子模块；97 源文件 + 25 测试文件 |
| **5.0** | **2026-07-13** | **Rust 分页引擎全删除（`block_paginator.rs`）；`api/core.rs`→`reader.rs`；reading/ 精简至 6 模块；遗留类型标注；文件数 90 源 + 21 测试** |

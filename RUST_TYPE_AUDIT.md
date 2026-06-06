# Rust 类型审计报告 — 状态追踪

> 审计范围：`rust/src/storage/models.rs`（FRB 导出结构体）、`rust/src/api/`（FRB 导出函数参数）、`rust/src/domain/types/`（分页/搜索类型）
>
> 审计原则：类型应匹配其语义范围，不浪费比特，跨 FFI 边界的类型映射应合理

---

## ✅ 已修复

### 分页参数 `usize` → `i32`（消除 Dart 侧 `BigInt`）

| 函数 | 原类型 | 现类型 |
|---|---|---|
| `list_recently_opened_books(limit)` | `usize` | `i32` |
| `list_sessions_by_book(limit)` | `usize` | `i32` |
| `list_sessions_by_recent(limit)` | `usize` | `i32` |
| `BookRepository::list_paginated(offset, limit)` | `i64` | `i32` |
| `NoteRepository::list_all_paginated(offset, limit)` | `i64` | `i32` |
| `SessionRepository.find_by_book(limit)` | `usize` | `i32` |
| `SessionRepository.find_by_recent(limit)` | `usize` | `i32` |
| `BookRepository::list_recent(limit)` | `usize` | `i32` |

Dart 侧 `BigInt.from(10)` → 直接 `10`。

### 最不一致字段

| 字段 | 原类型 | 现类型 | 理由 |
|---|---|---|---|
| `Vocab.chapter_index` | `Option<i64>` | `Option<i32>` | 全书其他模型全是 `i32` |
| `VocabStats.total_words / unstarted_count / learning_count / mastered_count / ignored_count` | `i64` | `i32` | 无人有 21 亿生词 |
| `SearchResult.chapter_index` | `String` | `i32` | 其他模型全是 `i32` |
| `SearchResult.position / char_offset` | `i64` | `i32` | 搜索位置不会超范围 |

### 字符偏移/长度字段

| 字段 | 原类型 | 现类型 | 涉及 struct |
|---|---|---|---|
| `char_offset`（6处） | `i64` | `i32` | Note, Bookmark, ReadingProgress, ReadingSession×2 |
| `length` | `i64` | `i32` | Note |
| `source/target_char_offset/length` | `i64` | `i32` | BilingualHighlightParams |
| `start_offset / end_offset` | `i64` | `i32` | PageContent |
| `offset / length` | `i64` | `i32` | PageOffset |

### 章节统计字段

| 字段 | 原类型 | 现类型 | 涉及 struct |
|---|---|---|---|
| `word_count` | `i64` | `i32` | Chapter |
| `start_index / end_index / content_length` | `i64` | `i32` | Chapter（含 `#[sqlx(default)]`） |

### 配套代码

- 所有 parser 中的 `as i64` → `as i32`（epub/toc、md/parse、pdf/parse、txt/parse）
- `chapter_detect.rs` 中的赋值表达式
- `text/pagination.rs` 中的 `start_offset / end_offset / offset / length` 构造
- `core.rs` 中的 offset cast 和返回值类型

---

## ⚠️ 已知遗留（未改）

### `Vocab.char_offset: Option<i64>` — 维持不变

`Option<i32>` 与 sqlx `FromRow` 解码 `Option<i64>` 的兼容性存在问题（sqlx 的 `try_from = "i64"` 不支持嵌套在 `Option` 内）。如要修改，需要手写 `FromRow` 实现或使用中间类型。收益低，搁置。

### `Dictionary.dict_type: String` → 枚举

词典类型（MDX/DSL/StarDict 等有限几种），适合枚举但改造成本一般，未动。

### `LayoutCache.created_at: i64` → `DateTime<Utc>`

使用 bincode 序列化，DateTime 也支持，但需验证兼容性，未动。

---

## 🟢 合理使用 `i64`（保留）

| 字段 | 理由 |
|---|---|
| `Book.file_size: i64` | 文件大小，大 EPUB 含媒体 >2GB |
| `Book.total_characters: i64` | 全书总字数，大型文集可能极大 |
| `Dictionary.word_count: i64` | 词典词条数，部分 >1000 万 |
| `ReadingProgress.reading_time_seconds: i64` | 终身累计 |
| `ReadingSession.duration_seconds: i64` | 保留 i64（虽 i32 也够） |
| `ReadingStats.*: i64` | 终身累计值 |
| `AggregatedStats.*: i64` | 终身累计值 |
| `GlobalStats.*: i64` | 终身累计值 |
| `count_books() -> i64` | 返回值，保留 |
| `file_mtime: Option<i64>` | 时间戳，保留 |

---

## 类型分布全景图（当前状态）

```
              i32（已修复）              i64（保留）                 待定
     ┌─────────────────────┐  ┌────────────────────┐  ┌────────────────────┐
     │ chapter_index (7×)   │  │ file_size           │  │ Vocab.char_offset  │
     │ page_index           │  │ total_characters    │  │ （Option, 搁置）    │
     │ chunk_index          │  │ reading_time_sec    │  │ dict_type→枚举     │
     │ total_pages          │  │ characters_read     │  │                    │
     │ chapter_count        │  │ duration_seconds    │  │                    │
     │ sort_order           │  │ AggregatedStats.*   │  │                    │
     │ level                │  │ GlobalStats.*       │  │                    │
     │ session_count        │  │ file_mtime          │  │                    │
     │ review_count         │  │ dict word_count     │  │                    │
     │ limit / offset       │  │                     │  │                    │
     │ char_offset (5×)     │  │                     │  │                    │
     │ length               │  │                     │  │                    │
     │ word_count           │  │                     │  │                    │
     │ start_index/end/cnt  │  │                     │  │                    │
     │ VocabStats (5 fields)│  │                     │  │                    │
     │ SearchResult pos/off │  │                     │  │                    │
     └─────────────────────┘  └────────────────────┘  └────────────────────┘
```

---

## 剩余可改项（收益低，建议搁置）

| 项目 | 难度 | 风险 |
|---|---|---|
| `Vocab.char_offset` Option<i64>→i32 | 中 | sqlx 兼容性 |
| `Dictionary.dict_type` String→enum | 中 | 需改 DB 映射 |
| `LayoutCache.created_at` i64→DateTime | 低 | 需验证 bincode |

# Rust FFI 信号审计：未使用 `asyncSignal` 的残余字段

> 生成日期：2026-06-06
> 最后更新：2026-06-06
> 目标：列出所有通过 FFI 加载数据但仍使用 `signal`（而非 `asyncSignal`）的字段，
> 供后续逐步迁移。

---

## ✅ 已完成迁移

| 文件 | 字段 | 优先级 |
|---|---|---|
| `backup_view_model.dart` | `currentStats` | P0 |
| `reader_view_model.dart` | `highlights` | P0 |
| `book_detail_view_model.dart` | `book`, `progress`, `noteStats`, `chapters`, `categories`, `sessions`, `vocabList` | P0 |
| `reading_stats_view_model.dart` | `globalStats`, `dailyRecords` | P0 |
| `cache_manage_view_model.dart` | `books`, `progressList` | P0 |
| `learning_notes_view_model.dart` | `noteList`, `bookTitles`, `noteTotalCount` | P1 |
| `bookshelf_view_model.dart` | `categories`, `readingProgress` | P2 |
| `search_view_model.dart` | `searchResults` | P2 |

---

## ⏳ 剩余字段

### 1. `storage_sync_view_model.dart` — 6 个 (P3)

| 字段 | 类型 | 数据来源 | 备注 |
|---|---|---|---|
| `cacheSize` | `signal<int>(0)` | `CacheUtils.getCacheSize()` | UNUSED（页面从不读取） |
| `dbSize` | `signal<int>(0)` | `CacheUtils.getCacheSize()` | UNUSED |
| `booksSize` | `signal<int>(0)` | `CacheUtils.getCacheSize()` | UNUSED |
| `totalUsed` | `signal<int>(0)` | `CacheUtils.getCacheSize()` | UNUSED |
| `totalAvailable` | `signal<int>(0)` | `CacheUtils.getCacheSize()` | UNUSED |
| `noteCount` | `signal<int>(0)` | `rust_stats.getGlobalReadingStats()` | UNUSED |

> 全部 UNUSED：页面从未读取展示，仅用于 `initialize()` 内部计算。
> 建议：删除而非迁移为 asyncSignal。

### 2. `reader_view_model.dart` — 1 个 (P3)

| 字段 | 类型 | 数据来源 | 备注 |
|---|---|---|---|
| `translationContent` | `signal<String>('')` | `bilingual_api` (FFI) | 双语翻译结果，每次请求时直接覆盖 |

> 辅助数据，每次翻译请求时覆盖写入，不存在 loading/error 展示需求。

---

## 剩余汇总

| 文件 | 待迁移数 | 优先级 | 建议 |
|---|---|---|---|
| `storage_sync_view_model.dart` | 6 | P3 (UNUSED) | 删除 |
| `reader_view_model.dart` (translationContent) | 1 | P3 | 可保留 signal |
| **合计** | **7** | | 均为 P3 低优 |

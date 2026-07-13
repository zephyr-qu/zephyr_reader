# Design — M2 API 路径统一

## Architecture Decision

**所有分页调用入口用 `book_id` 定位**，内部在需要文件操作时通过 DB 反查 `file_path`。

```
┌─────────────────────────────────────────────────────────────┐
│                    Dart 调用层                               │
│  createPaginationSession(bookId, chapterIndex, config)       │
│  createPaginationSessionAdopt(bookId, chapterIndex, config)  │
│  supportsChunkedPagination(bookId)                           │
│  NextChapterStaging(bookId, ...)                             │
└───────────────────────── FFI ───────────────────────────────┘
│                    Rust FFI 层 (api/core.rs)                 │
│  create_pagination_session(book_id, chapter_index, config)   │
│    → ReadingOrchestrator::create_pagination_session(…)       │
└───────────────────────── ↓ ─────────────────────────────────┘
│                    Orchestrator                              │
│  resolve book_id → file_path (via BookRepository + cache)    │
│  validate_file_path(file_path)                               │
│  delegate to session.rs / pagination.rs                      │
└─────────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### D1: `PaginationSessionEntry` 存什么？

**决策**: 新增 `book_id: String`，保留 `file_path: String`（内部实现细节）。

理由:
- 后续 dispose / lookup 不需要每次反查 DB
- `file_path` 仍用于分页和缓存 key 的内部计算
- `book_id` 是新的公共标识

```rust
pub(crate) struct PaginationSessionEntry {
    pub(crate) book_id: String,      // 新增
    pub(crate) file_path: String,    // 保留（内部使用）
    pub(crate) chapter_index: i32,
    pub(crate) config: TypesetConfig,
    pub(crate) engine: PaginationEngine,
}
```

### D2: `book_id → file_path` 解析放哪层？

**决策**: 在 Orchestrator 层完成解析，session.rs 不感知。

理由:
- 保持 session.rs 简单——只操作已解析的 `(file_path, chapter_index, config)`
- Orchestrator 已有 `BookRepository` 访问能力
- `create_pagination_session` FFI 入口在 orchestrator → 解析在这里最自然

### D3: `provider_cache.rs` CacheKey 变更策略

**决策**: `CacheKey = (String /*book_id*/, i32 /*chapter_index*/, BookFormat)`

当前: `(String /*file_path*/, i32, BookFormat)`
目标: `(String /*book_id*/, i32, BookFormat)`

影响:
- `get_or_create_provider` 内部需要 book_id → file_path 的反查（从 DB 或 BOOK_ID_CACHE）
- `PaginationKey`（在 pagination_store.rs 中）是否也需要变更？——暂不变，PaginationKey 用的是 `validated_path` + `config_hash`，属于块缓存层，不直接暴露给调用方

### D4: `supports_chunked_pagination` 是否保留？

**决策**: 改为接受 `book_id`。

理由: 当前 `supports_chunked_pagination(file_path)` 使用 `format_from_file_path` 推断格式，但格式可从 DB `BookRepository` 按 `book_id` 查询。保留此函数但改签名，减少 Dart 侧改动。

## Data Flow (before → after)

### Before (path-based)
```
Dart: filePath → FFI → Rust: validate_file_path → format_from_file_path → paginate_chapter
```

### After (handle-based)
```
Dart: bookId  → FFI → Rust: BookRepository.find_by_id(bookId) → file_path
                        → validate_file_path(file_path)
                        → paginate_chapter(file_path, …)
```

## Impact Summary

| 文件 | 变更 |
|------|------|
| `rust/src/api/core.rs` | `create_pagination_session` / `create_pagination_session_adopt` / `supports_chunked_pagination` 签名从 `file_path` → `book_id` |
| `rust/src/reading/orchestrator.rs` | 对应方法签名变更 + 新增 `resolve_book_id_to_path()` helper |
| `rust/src/reading/session.rs` | `PaginationSessionEntry` + `book_id` 字段；创建函数从接收 `book_id`（由 orchestrator 传入） |
| `rust/src/reading/provider_cache.rs` | `CacheKey` 从 `(path, format)` → `(book_id, format)`；`get_or_create_provider` 新增 book_id→path 解析 |
| `rust/src/reading/chapter_access.rs` | 移除分页路径中对 `format_from_file_path` 的使用 |
| `lib/src/rust/api/core.dart` (generated) | FRB 重新生成——`filePath` → `bookId` |
| Dart `NextChapterStaging` | `filePath` 参数 → `bookId` |
| Dart `rust_chapter_content_repository.dart` | 分页调用改为传 `bookId` |
| Dart `rust_pagination_session.dart` | 分页调用改为传 `bookId` |

## Rollback Points

1. Rust: `git stash` 所有改动 → cargo check → 恢复
2. FRB: 重新运行 codegen 即可回滚到当前签名
3. Dart: `dart analyze` 检查零报后可继续

## Not Changed

- `get_chapter` / `get_chapter_first_spine_only` / `get_chapter_partial` — 非分页路径，不在 ADR-014 范围
- `get_chapter_content_ir` — scroll 路径，不在范围
- `ChapterContentProvider` 内部实现
- `BookFormat` enum
- 存储层查询接口

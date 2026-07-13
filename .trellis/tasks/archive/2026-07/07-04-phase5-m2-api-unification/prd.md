# Phase 5 M2 — API 路径统一 (ADR-014)

## Goal

将分页 API 从 path-based (`file_path: String`) 统一为 handle-based (`book_id: String + chapter_index: i32`)，使所有分页调用通过数据库主键定位内容，消除 path-based 和 handle-based 两条路径并存的维护负担。

## Background

当前分页 API 存在两条原则分歧:

1. **path-based**: `create_pagination_session(file_path, chapter_index, config)` — 用文件路径定位
2. **handle-based**: session 创建后的后续操作 (`get_session_page_content(handle, …)`)

但即便是 session 创建的入口 API 也仍然传 `file_path`，而内部实现早已有 `book_id` 缓存 (`BOOK_ID_CACHE`)。ADR-014 拍板统一到 `book_id + chapter_index`。

## Confirmed Facts (from code inspection)

| 事实 | 证据 |
|------|------|
| `create_pagination_session` / `create_pagination_session_adopt` 均以 `file_path: String` 为第一参数 | `rust/src/api/core.rs:122-130`, `session.rs:113-140` |
| `PaginationSessionEntry` 存储 `file_path: String` 字段 | `session.rs:20` |
| `provider_cache.rs` CacheKey = `(String, i32, BookFormat)` 其中 String = file_path | `provider_cache.rs:33` |
| 内部已有 `BOOK_ID_CACHE` 做 path→book_id 映射 | `chapter_access.rs:48` |
| `supports_chunked_pagination` 用的是 `format_from_file_path(&file_path)` | `core.rs:215` |
| ChapterContentProvider 实现不参与变更（ADR-014 "不做的事"） | — |
| M2 前置子项 5-5 (删除 chapterHasImageBlocks) 已完成 ✅ | 提交 `f9f7716` |
| M2 前置子项 5-6 (删除 paginate_all_content) 已完成 ✅ | 提交 `f9f7716` |

## Requirements

### R1: Rust FFI 签名变更

- `create_pagination_session` 签名从 `(file_path, chapter_index, config, max_chars)` → `(book_id, chapter_index, config, max_chars)`
- `create_pagination_session_adopt` 同理
- `supports_chunked_pagination` 同理（或删除，因为已知 book 的 format 可从 DB 查出）
- 内部实现通过 DB 反查 `book_id → file_path`（复用已有的 `BookRepository` + `BOOK_ID_CACHE`）
- `PaginationSessionEntry` 内部新增 `book_id: String` 字段，`file_path` 保留为内部实现细节
- FRB 重新生成 Dart 绑定

### R2: NextChapterStaging 适配

- Dart 侧 `NextChapterStaging` 将 `filePath` 参数替换为 `bookId`
- staging 路径上的 `createPaginationSession`/`createPaginationSessionAdopt` 调用使用 `bookId` 替代 `filePath`

### R3: provider_cache.rs CacheKey 变更

- `CacheKey` 从 `(String /*file_path*/, i32, BookFormat)` 改为 `(String /*book_id*/, i32, BookFormat)`
- `get_or_create_provider` 内部通过 `book_id` 反查 `file_path` 再构建 provider
- 不改变 `ChapterContentProvider` 内部实现

### R4: chapter_access.rs 简化

- 移除 `format_from_file_path` 在分页 API 路径上的直接使用
- 从 `book_id` 解析 `BookFormat` 可通过 `BookRepository` 查询

### R5: FRB 重新生成

- 修改 Rust API 签名后运行 `flutter_rust_bridge_codegen generate`
- 确保 tests 24/24 仍通过

## Acceptance Criteria

- [ ] `create_pagination_session(file_path, …)` 不存在——签名变为 `(book_id, …)`
- [ ] `NextChapterStaging` 无 `file_path` 参数
- [ ] `provider_cache.rs` CacheKey 不含文件路径
- [ ] `chapter_access.rs` 分页路径无 `format_from_file_path` 调用
- [ ] `cargo clippy -- -D warnings` 零报
- [ ] `dart analyze --fatal-infos` 零报
- [ ] 已有单元测试全过（pagination_session_test, epub_reading_chain_test, 集成测试 24/24）
- [ ] path-based 路径不得新增调用点 (I9)

## Out of Scope

- 不改变 `ChapterContentProvider` 内部实现（仍 mmap/epub read）
- 不改变 `BookFormat` enum
- 不改变存储层查询接口 (`BookRepository`, `ChapterRepository`)
- 不改动非分页的 path-based API（`get_chapter`, `get_chapter_first_spine_only`, `get_chapter_partial` — 这些不在 ADR-014 范围）

## Open Questions

（无——所有技术问题已通过代码审查解答）

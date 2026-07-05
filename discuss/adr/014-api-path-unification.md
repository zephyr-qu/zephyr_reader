# ADR-014 — 分页 API 路径统一

> **状态**：已接受（Phase 5 执行）
> **背景**：[KNOWN_POSTPHASE4_BUGS.md](../../issue/KNOWN_POSTPHASE4_BUGS.md) P3-13

---

## 语境

当前分页 API 存在两条路径：

1. **path-based**：`paginate_chapter(file_path, ...)` — 用文件路径定位章节内容
2. **handle-based**：`create_pagination_session(book_id, chapter_index, ...)` — 用数据库 ID + session handle 管理

path-based 路径在 Phase 4 P0 后已被 `paginate_chapter_ir_chunked` 替代（走 IR + BlockPaginator），但 `chapter_access.rs` 和 `provider_cache.rs` 仍保留 path-based 的 provider 创建逻辑。

handle-based 路径是当前主链路（`PaginationSession` + `RustPaginationSession`），但 `NextChapterStaging` 仍直接构造 path-based 参数。

两条路径长期并存增加维护负担，且 path-based 无法利用数据库中的 `book_id` 唯一性约束去重。

## 决策

**统一为 handle-based**：

- 所有分页调用通过 `book_id` + `chapter_index` 定位内容
- `NextChapterStaging` 使用 `book_id` 替代 `file_path`
- `provider_cache.rs` 的 `CacheKey` 从 `(path, format)` 改为 `(book_id, format)`
- 移除 `format_from_file_path` 对分页 API 的直接使用

## 影响

- `chapter_access.rs` 简化：移除 `format_from_file_path` 对分页路径的使用
- `provider_cache.rs` CacheKey 变更
- `NextChapterStaging` 参数变更
- Dart `rust_chapter_content_repository.dart` 简化

## 不做的事

- 不改变 `ChapterContentProvider` 内部实现（仍 mmap/epub read）
- 不改变 `BookFormat` enum
- 不改变存储层查询接口

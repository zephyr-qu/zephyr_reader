# Implementation Plan — M2 API 路径统一

## Execution Order

### Step 1: 确认 Dart 侧调用点 ✅ DONE

所有 Dart 代码已确认。关键发现：**Dart 业务层已统一使用 `bookId`**，仅在调用 Rust FFI 前解析为 `book.filePath`。改动面集中：

| 文件 | 调用点 | 改动 |
|------|--------|------|
| `rust_pagination_session.dart:113` | `core_api.createPaginationSession(filePath: validatedPath)` | `filePath` → `bookId` |
| `rust_pagination_session.dart:189` | `core_api.createPaginationSessionAdopt(filePath: book.filePath)` | `filePath` → `bookId` |
| `rust_chapter_content_repository.dart:291` | `core_api.paginateChapter(filePath: book.filePath)` | `filePath` → `bookId` |
| `rust_chapter_content_repository.dart:302` | `core_api.getPageContent(filePath: filePath)` | `filePath` → `bookId` |
| `rust_chapter_content_repository.dart:308` | `core_api.getPageBlocks(filePath: filePath)` | `filePath` → `bookId` |
| `next_chapter_staging.dart:11` | `filePath` 字段 | 改为 `bookId` |

**影响范围明确**：3 个 Dart 文件 + Rust FFI 签名变更 → FRB 重新生成即可。

### Step 2: Rust 侧 — orchestrator 新增 resolve helper

- [ ] 在 `orchestrator.rs` 新增 `async fn resolve_book_path(book_id: &str) -> Result<String, AppError>`
  - 调用 `BookRepository::find_by_id` 查数据库
  - 返回 `book.file_path`
  - 缓存到 `BOOK_ID_CACHE`（复用已有缓存）

### Step 3: Rust 侧 — session.rs 内部适配

- [ ] `PaginationSessionEntry` 新增 `book_id: String` 字段
- [ ] `create_pagination_session` 改为接收 `book_id: String`（由 orchestrator 传入，已解析）
- [ ] `create_pagination_session_adopt` 同理
- [ ] `PaginationKey::new` 如果用到 file_path 需评估是否一并改

### Step 4: Rust 侧 — api/core.rs 签名变更

- [ ] `create_pagination_session(book_id, chapter_index, config, max_chars)` → orchestrator.resolve → session
- [ ] `create_pagination_session_adopt(book_id, chapter_index, config)` → orchestrator.resolve → session
- [ ] `supports_chunked_pagination(book_id)` → DB 查 format

### Step 5: Rust 侧 — provider_cache.rs CacheKey 变更

- [ ] `CacheKey` = `(String /*book_id*/, i32, BookFormat)`
- [ ] `get_or_create_provider` 通过 `book_id` 反查 `file_path`
- [ ] 更新所有调用方（`pagination.rs` 等）

### Step 6: Rust 侧 — chapter_access.rs 简化

- [ ] 移除分页 API 路径上的 `format_from_file_path` 调用
- [ ] 用 `BookRepository` 直接查 `BookFormat`

### Step 7: FRB 重新生成

- [ ] 运行 `flutter_rust_bridge_codegen generate`
- [ ] 确认 Dart 生成的 `createPaginationSession` 参数从 `filePath` 变为 `bookId`

### Step 8: Dart 侧适配

- [ ] `NextChapterStaging`: `filePath` → `bookId`
- [ ] `rust_chapter_content_repository.dart`: 分页调用传 `bookId`
- [ ] `rust_pagination_session.dart`: 分页调用传 `bookId`
- [ ] 其他所有调用点

### Step 9: 验证

- [ ] `cargo check` — 编译通过
- [ ] `cargo clippy -- -D warnings` — 零警告
- [ ] `dart analyze --fatal-infos` — 零报
- [ ] Rust 测试: `cargo test --lib`
- [ ] Dart 测试: `flutter test`
- [ ] 集成测试 24/24

### Step 10: 确认 I9 不变量

- [ ] 搜索 `git diff` 中是否新增 path-based 分页调用
- [ ] 确保 `create_pagination_session(file_path, …)` 调用 **不再存在**

## Validation Commands

```bash
# Rust check
cd rust && cargo check

# Rust clippy
cd rust && cargo clippy -- -D warnings

# Rust tests
cd rust && cargo test --lib

# Dart analyze
dart analyze --fatal-infos

# Dart tests
flutter test

# Regression check — 分页 session 测试
cargo test pagination_session_test
cargo test epub_reading_chain_test

# Search for remaining path-based calls (should return 0)
grep -r "create_pagination_session.*file_path" rust/src/
grep -r "createPaginationSession.*filePath" lib/
```

## Rollback

```bash
git stash          # Undo all Step 1-8 changes
cd rust && cargo check  # Verify clean
```

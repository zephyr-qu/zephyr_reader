# 回退指南：内部模型 → i64，API 层保留 i32

## 策略

```
┌──────────┐     i32     ┌──────────┐     i64     ┌─────────────┐
│  Dart    │────────────→│  API 层  │───as i64───→│  Internal    │
│          │←────────────│  (i32)   │←───────────│  (i64)       │
└──────────┘             └──────────┘             └─────────────┘
```

- API 层参数：已全部保持 `i32`，调用内部时已加 `as i64`（我修好了）
- 内部：按以下清单回退到 `i64`（你做）

**顺序**：按 1→7 逐个文件回退，最后 FRB generate。

---

## 1. `rust/src/storage/models.rs` — 字段类型

| 行号范围 | Struct | 当前 (i32) | 回退到 (i64) |
|---|---|---|---|
| 98 | `ReadingProgress.char_offset` | `i32` | `i64` |
| 113 | `ReadingProgress::new(char_offset)` | `i32` | `i64` |
| 146 | `Bookmark.char_offset` | `i32` | `i64` |
| 156 | `Bookmark::new(char_offset)` | `i32` | `i64` |
| 202-203 | `Note.char_offset, length` | `i32, i32` | `i64, i64` |
| 221-222 | `Note::highlight(char_offset, length)` | `i32, i32` | `i64, i64` |
| 251 | `Note::annotation(char_offset)` | `i32` | `i64` |
| 302-303 | `ReadingSession.start_char_offset, end_char_offset` | `i32, i32` | `i64, i64` |
| 315-316 | `ReadingSession::new(start, end)` | `i32, i32` | `i64, i64` |
| 530 | `Chapter.word_count` | `i32` | `i64` |
| 533-538 | `Chapter.start_index, end_index, content_length` | `i32` | `i64`（保留 `#[sqlx(default)]`） |
| 549 | `Chapter::new(word_count)` | `i32` | `i64` |
| 653 | `Vocab.chapter_index` | `Option<i32>` | `Option<i64>` |
| 680 | `Vocab::new(chapter_index)` | `Option<i32>` | `Option<i64>` |
| 707-711 | `VocabStats` 5 字段 | `i32 + #[sqlx(try_from = "i64")]` | `i64`（去掉 try_from 属性） |

## 2. `rust/src/storage/repos/*.rs` — 仓库函数参数

| 文件 | 函数 | 当前 | 回退到 |
|---|---|---|---|
| `book_repo.rs:196` | `list_recent(limit)` | `i32` | `i64` |
| `book_repo.rs:211-212` | `list_paginated(limit, offset)` | `i32, i32` | `i64, i64` |
| `note_repo.rs:260-261` | `list_all_paginated(limit, offset)` | `i32, i32` | `i64, i64`（去掉 `.bind(limit as i64)` 中的 `as i64`，因为原生就是 i64） |
| `session_repo.rs:42` | `find_by_book(limit)` | `i32` | `i64` |
| `session_repo.rs:82` | `find_by_recent(limit)` | `i32` | `i64` |

## 3. `rust/src/parser/*` — `as i32` 回退到 `as i64`

| 文件 | 行号 | 当前 | 回退到 |
|---|---|---|---|
| `epub/toc.rs` | 74,97,116,117 | `as i32` | `as i64` |
| `md/parse.rs` | 156,161 | `as i32` | `as i64` |
| `pdf/parse.rs` | 129,130,131 | `as i32` | `as i64` |
| `txt/parse.rs` | 186,187,195,196,197,216,217 | `as i32` | `as i64` |

## 4. `rust/src/text/*` — `as i32` 回退到 `as i64`

| 文件 | 行号 | 当前 | 回退到 |
|---|---|---|---|
| `chapter_detect.rs` | 53,54,65,66,67 | `as i32` | `as i64` |
| `pagination.rs` | 275,276,306,307,380,381,405,406 | `as i32` | `as i64` |

## 5. `rust/src/api/core.rs` — 返回值 + casts

| 行号 | 当前 | 回退到 |
|---|---|---|
| 585 | `-> Result<(i32, i32), AppError>` | `-> Result<(i64, i64), AppError>` |
| 627-628 | `acc_offset as i32` | `acc_offset as i64` |

## 6. `rust/src/search/engine.rs` — FTS5 索引

引擎存 `chapter_index` 为 TEXT。

| 行号 | 当前 | 回退到 |
|---|---|---|
| 47 | `chapter_index: i32` | `&str` |
| 91 | `CAST(chapter_index AS INTEGER) = ?` | `chapter_index = ?` |
| 105 | `chapter_index.to_string()` | `chapter_index`（去掉 .to_string()） |
| 138,167 | `CAST(chapter_index AS INTEGER) AS chapter_index` | `chapter_index` |
| 180 | `CAST(chapter_index AS INTEGER) = -1` | `chapter_index = '-1'` |

API 层 `index_chapter(chapter_index: i32)` 会传 `&chapter_index.to_string()` 给引擎——引擎回退后如编译报错，加回来即可。

## 7. FRB 重新生成

回退全部完成后：
```
flutter_rust_bridge_codegen generate
```

## 无需改动的文件（API 层已修好）

以下文件我已经加好了 `as i64` 转型，**你不需改动**：

| 文件 | 函数 | 说明 |
|---|---|---|
| `api/data/note.rs` | `create_highlight(chapter_index, char_offset, length)` | API 保持 i32 → 传 `as i64` |
| `api/data/note.rs` | `create_annotation(chapter_index, char_offset)` | 同上 |
| `api/data/note.rs` | `list_all_notes(limit, offset)` | API 保持 i32 → 传 `as i64` |
| `api/data/bookmark.rs` | `create_bookmark(chapter_index, char_offset)` | 同上 |
| `api/data/book.rs` | `list_recently_opened_books(limit)` | API 保持 i32 → 传 `as i64` |
| `api/data/book.rs` | `list_books_paginated(limit, offset)` | 同上 |
| `api/data/session.rs` | `create_session(start_char_offset, end_char_offset)` | 同上 |
| `api/data/session.rs` | `list_sessions_by_book(limit)` | 同上 |
| `api/data/session.rs` | `list_sessions_by_recent(limit)` | 同上 |
| `api/data/vocabulary.rs` | `create_vocabulary_word(chapter_index)` | `Option<i32>` → `.map(\|v\| v as i64)` |
| `api/bilingual.rs` | `BilingualHighlightParams` struct + `create_bilingual_highlight_pair` | struct 保持 i32，传 `as i64` 给 Note::highlight |

## 验证命令

```bash
cargo clippy -- -D warnings   # 应只看到预存的 collapsible_if 等
cargo test --lib --quiet      # 168 passed
dart analyze lib/             # zero errors
```

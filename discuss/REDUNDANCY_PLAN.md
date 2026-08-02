# R14 冗余清理计划（A/B/C/D 候选 + E 区决策）

> 状态：**E1/E5 已执行完成**（2026-08-02）。A/B/C/D 类为候选，记录待批准执行；E1 全文搜索、E5 生词本已按用户裁决删除并验证。
> 前置：R14 第一步已完成（死模块/TXT 链/生词写入/FRB 清理），门禁全绿。
> ✅ E1+E5 执行验证：cargo check 0 错误、clippy -D warnings 无告警、cargo test 100 passed / 7 ignored、dart analyze --fatal-infos No issues。
---

## A 类：零调用 FRB API（删 API → 级联删 domain → 删对应测试）

> **已按 E 区决策调整**：dictionary 5 项划出（用户决策保留，见 E 区）；search 6 项随"全文搜索删除"整体处理（见 E 区）。

| # | API | 级联 domain 删除 | 保留项 |
| --- | ----- | ----------------- | -------- |
| A1 | bookmark: `upsert_bookmark` `delete_bookmarks` `get_bookmark` `delete_bookmarks_by_book` `import_bookmarks` `count_bookmarks_by_book`（6） | `BookmarkRepository::find_by_id` / `delete_by_ids` / `delete_by_book` / `import_bookmarks` / `count_by_book` | `list_bookmarks_by_book` `create_bookmark` `delete_bookmark`（readium 在用） |
| A2 | category: `set_categories_for_books`（1） | service `set_by_book` → repo `assign_by_book` `remove_by_book` | 其余 5 个（分类管理 UI 在用） |
| A3 | cover: `extract_book_cover`（1） | 仅删 API 壳（`extract_and_save_cover` 复用 service fn） | `extract_and_save_cover` `supports_cover_extraction` |
| A4 | stats: `get_today_reading_stats` `get_reading_stats_by_range` `get_reading_stats_by_days` `update_daily_stats`（4） | `StatsRepository::find_by_today` / `find_by_range` / `find_by_days` / `update_by_daily` | `get_global_reading_stats` `get_reading_stats_by_days_with_fill`（UI 在用） |

小计：**12 个 API**。

测试联动：`api_stats_test.rs` 删对应 4 用例（保留 get_global / days_with_fill 用例）。

---

## B 类：domain 层纯死函数（11 个，无任何调用方）

```
book_repo:      list_progress, list_by_status, list_pinned, list_paginated,
                update_title, update_metadata                              (6)
category_repo:  assign_by_book, remove_by_book, list_books_by_category    (3)
chapter_repo:   find_by_index                                             (1)
progress_repo:  list_all_with_progress                                    (1)
```

均为早期 API 层的仓储实现，被 A 类删除后已无调用方（`list_bookshelf_books`/`get_book_detail`/`upsert_book` 不依赖它们）。

---

## C 类：死 Cargo 依赖（1 个）

- **`anyhow`** — 全仓库 0 引用（含 `frb_generated.rs` 与全部测试），直接可删。
- 其余依赖均验证有引用；`rs-mdict` 以 `rust_mdict` 名被 `domain/dictionary/engine.rs` 使用（保留）。

---

## D 类：测试文件/用例处置

| 文件 | 处置 |
| ------ | ------ |
| `rust/tests/poc_path_escape.rs`（326 行） | **删除**。I1 PoC 残留；其断言的安全缺陷（`validate_file_path` 无基目录校验）已按测试纪律记录，不靠 PoC 测试证明。 |
| `rust/tests/api_dictionary_test.rs` | 保留（词典功能整体保留，见 E 区） |
| `rust/tests/api_stats_test.rs` | 随 A4 删 4 用例，保留 get_global / days_with_fill 用例 |
| `rust/tests/search_test.rs` | 随"全文搜索删除"整体删除（见 E 区） |
| `rust/tests/vocabulary_test.rs` | 随"生词本删除"整体删除（见 E 区） |

---

## E 区：功能缺口 — 用户裁决（2026-08-02）

### E1. 全文搜索 → ✅ 删除（整个子系统）

**根因**：`index_chapter` 零调用 → FTS `search_index` 表从不填充 → `search()`/`search_all_books()` 永远返回空 → 全文搜索与书内搜索 UI 均为僵尸功能。

**Rust 侧**：

- `rust/src/api/search.rs`（9 个 API：`init_search_engine` `index_chapter` `search` `count_matches` `search_all_books` `clear_search_index` `delete_by_book` `get_index_stats` `segment_chinese_text`）— 整文件删除
- `rust/src/domain/search/`（`engine.rs` ~412 行 + `mod.rs`）— 整目录删除
- `rust/src/lib.rs` / `mod.rs` 中模块声明
- `Cargo.toml`：**`jieba-rs`**（仅 search engine 使用）→ 可删
- FTS5 `search_index` 虚拟表：新装不再创建；已有安装 DB 残留表无害（不迁移）

**Dart 侧**：

- `lib/features/search/` 整个目录（12 文件：search_page / book_search_page / search_view_model / book_search_view_model / search_results*/ search_history* / search_result_* / search_highlight）
- `lib/core/routing/app_router.dart`：`search` + `bookSearch` 路由（bookSearch 当前无 push 方，死路由随删）+ 对应 import/builder
- `lib/core/routing/route_constants.dart`：`search` / `bookSearch`
- `lib/di/service_locator.config.dart`：SearchViewModel 注册
- `lib/main.dart`：`initSearchEngine()` + `api/search.dart` import
- `lib/features/bookshelf/page/bookshelf_page.dart:121`：书架页搜索入口（`push(AppRoute.search.path)`）
- 删除后 FRB 重新生成，`lib/src/rust/api/search.dart` 及 `domain/search` 生成物自动消失

**测试**：`rust/tests/search_test.rs` → 删除。

**注意**：`search_books` / `search_bookshelf_books`（SQL LIKE 书名搜索，非 FTS）**保留**——书架的搜索按钮改为指向已有书名搜索或移除，由实现时按 UI 现状处理。

### E2. 阅读统计 → 保留（未接入，R13 接线）

现状：`update_daily_stats` 零调用 → `reading_stats` 表无写入方 → 统计页/主页读取空表。功能本身保留，待 R13（TTS/搜索/生词）阶段补埋点。Rust 侧只按 A4 删 4 个零调用 API，读接口保留。

### E3. 阅读进度 → 保留（未接入，R10 接线）

现状：`ProgressRepository::save` 零调用 → Rust 侧进度持久化未接线；阅读位置实际由 Dart 侧存 `SharedPreferences`（`readium_view_model.dart` `_savePositionNow`）。R10（目录与进度）接入。A/B 类不动 progress_repo（仅 `list_all_with_progress` 属 B 类死函数）。

### E4. 词典查询 → 保留（UI 入口未做，R13 补入口）

现状：`init_dictionary`/`close_dictionary` 被设置页调用；`lookup_mdict`/`suggest_mdict`/`extract_audio` 零调用（无查询 UI）。用户裁决：词典功能保留，R13 做查词 UI 入口。**因此 A 类中 dictionary 5 项划出，不再删除**；`DictSearchResult`、engine `lookup/suggest/extract_audio/has_resource` 全部保留。

### E5. 生词本 → ✅ 整个功能模块删除

**根因**：写入 API 已在 R14 第一步删除，现有数据只能删不能增；同 Readium 无选区事件根因链。

**Rust 侧**：

- `rust/src/api/vocab.rs`（6 个 API：`list_vocabulary_by_status` `search_vocabulary_words` `update_vocabulary_status` `delete_vocabulary` `get_vocabulary_stats` `list_word_lists`）— 整文件删除
- `rust/src/domain/vocab/`（`models.rs` `vocab_repo.rs` `mod.rs`）— 整目录删除
- `rust/src/domain/book/service.rs:34` — `VocabRepository::count_by_book` 调用 + `BookDetail.vocab_count` 字段 → 删除
- **`rust/src/domain/backup/`（⚠️ 必改）**：
  - `models.rs:28` — `BackupStats.vocabulary_words` 字段删除
  - `service.rs:123` — `COUNT(*) FROM vocabulary_words` 统计调用删除（否则表删除后备份报错）
  - `service.rs:364` — 测试中 `vocabulary_words: 50` 引用
- `rust/src/lib.rs` / `mod.rs` 模块声明
- DB `vocabulary_words` 表：新装不再创建；已有安装残留表无害（不迁移）

**Dart 侧**：

- `lib/features/vocabulary/` 整个目录（6 文件：vocabulary_page / vocabulary_view_model / vocab_list_item_tile / vocab_stats_row / vocab_status_chip / vocab_word_list_view）
- `lib/features/profile/page/profile/profile_menu_sections.dart:27` — "生词本"入口
- `lib/core/routing/app_router.dart` + `route_constants.dart` — `vocabulary` 路由
- `lib/features/statistics/`：`reading_stats_view_model.dart` 的 `vocabStats` signal + `getVocabularyStats()`；`statistics_page.dart` 的 `VocabStatsSection`；`widgets/vocab_stats_section.dart` + `vocab_stat_bar.dart` → 删除/移除
- `lib/features/data/page/restore_confirm_dialog.dart:61` — `manifest.stats.vocabularyWords` 引用（随 BackupStats 字段删除同步处理）
- `lib/l10n/` — vocab 相关键（`vocabularyCount` `selectionVocabulary` `addToVocabulary` `vocabulary` 等，含 searchGroupVocab 已随搜索删除）
- 随搜索删除的 `lib/features/search/` 内 vocab 分组（VocabSearchItem / VocabSearchCard）自动消失

**测试**：`rust/tests/vocabulary_test.rs` → 删除。

---

## 执行顺序建议

1. **E1 全文搜索删除**（最大影响面，独立成步）：Rust → FRB → Dart UI → 路由/DI → 测试 → 门禁
2. **E5 生词本删除**（含 backup 联动）：Rust（含 BackupStats）→ FRB → Dart UI → 路由/DI → 测试 → 门禁
3. **A+B+C 删除**（12 API + 11 仓储函数 + anyhow）：Rust → FRB → 测试删减 → 门禁
4. **D 测试清理**（poc_path_escape）：随上述步骤合并执行

每步门禁：`cargo check --all-targets` → `cargo clippy --all-targets -- -D warnings` → `cargo test` → `flutter_rust_bridge_codegen generate` → `dart analyze --fatal-infos`。

## parser/epub 保留结论（2026-08-02 用户确认）

经调用链扫描确认：`rust/src/parser/epub/`（1080 行，6 文件）**不是死代码，整体保留**。

### 活跃调用方

| 调用方 | 用途 | 链路 |
|--------|------|------|
| `domain/book/service.rs:165` | 导入书籍：解析 EPUB → 提取元数据(书名/作者/封面路径) + 章节列表 → 写入 books/book_metadata/chapters 表 | Dart `BookImportService.importBook()` → `book_api.importBook()` → 书架导入/文件夹扫描 |
| `domain/cover/engine.rs:69` | 封面提取：`EpubFile::open().read_cover()` → 存 covers 目录 | `extract_and_save_cover` → 书架封面展示 |

### 与 flureadium (Readium) 的分工

两者是**分工关系，非替代关系**：

- **flureadium** = 渲染引擎（打开/翻页/阅读器内 TOC/设置），Dart 原生视图，Rust 不参与。
- **自建 parser/epub** = 元数据入库（书架展示、封面、详情页目录）。Readium 渲染不写 SQLite，书架数据必须由 Rust 侧在导入时提取。

### 子模块职责

- `parse.rs` + `entry_extractor.rs` + `archive_reader.rs` → 导入解析（活）
- `archive_reader.rs`（EpubFile::read_cover）→ 封面提取（活）
- `toc.rs`（extract_chapters_from_epub）→ chapters 表 → 详情页目录跳章（活）
- `asset_registry.rs` → 上次清理已瘦身

### 潜在替代点（非本次清理范围）

若 R10（目录与进度）决定**全部改用 Readium 的 tableOfContents**（Dart 侧已有 `flattenToc`），Rust 侧 `toc.rs` 乃至 chapters 表可被替代——属 R10 架构决策，不在 R14 死代码清理范畴。

## 约束提醒

- GIT 铁律：不执行 git reset/checkout；用户未提交改动（api_test.rs、pubspec.yaml）不触碰。
- FRB 生成文件（frb_generated.rs / lib/src/rust/）禁止手改，一律 codegen。
- 已装用户 DB 的残留表（search_index / vocabulary_words / 生词相关字段）不做破坏性迁移，仅停止使用。

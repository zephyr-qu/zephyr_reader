# Rust 冗余代码与文件专项报告（单引擎决策下）

> 生成日期：2026-08-02 · 分支 `feature/mvp-readium-only` · commit 基准 `c1932bfb`
> 判定方法：**API 层 ↔ Dart 调用方 调用图**（82 个 FRB API，49 个有调用方 / 33 个零调用）+ Rust 内部模块可达性追踪（沿存活 API 下行）。
> 前提：单引擎（Readium EPUB）决策已定，内置阅读引擎（Builtin IR 渲染管线）退出当前路线（ADR-020）。
> 状态：**仅报告，未删任何文件**。删除动作走 R14，由用户确认。

---

## 结论

单引擎决策下，Rust 侧当前 22,871 行源码中，**约 4,200+ 行是纯死代码（无任何调用路径），另有 ~2,300 行与已失去调用方的功能绑定，属于"可删或需补功能"的决策区**。删除后 Rust 存活面约保留 14,000 行（API 薄层 + 领域 CRUD + 备份 + 导入/封面/目录 + 词典管理 + 搜索外壳）。

死代码根因是同一件事的两面：**内置引擎的"富文本渲染 IR 管线"（pipeline + EPUB rich parser）在单引擎下无人消费**；**迁移到 Readium 时 UI 侧丢掉了写入动作（索引、会话、生词、查词），只剩查询 API 空转**。

---

## A. 死模块 — 整文件可删（~4,154 行）

这些模块的每个公开函数都无调用方（或调用方全部在下面的死模块里），单引擎下没有保留理由。

### A1. `pipeline/` 整个目录（1,219 行）

| 文件 | 行数 | 证据 |
| ------ | ------ | ------ |
| `pipeline/plain_projector.rs` | 585 | `project_block_joined` / `validate_chapter_plain` / `PlainProjector` 全仓零调用 |
| `pipeline/block_joined_builder.rs` | 195 | `BlockJoinedPlainBuilder` 全仓零调用 |
| `pipeline/chapter_ir.rs` | 240 | `get_chapter_bounds` / `load_chapter_content_ir` / `save_ir_cache` / `get_ir_cache` 零调用；仅 `new` + `invalidate_book_cache` 被 `delete_book` 调用（见 A4 说明，可一并摘除） |
| `pipeline/types.rs` | 199 | `ReaderChapterIr` 等 IR 类型只被死模块与 kv_store 引用 |

### A2. `parser/epub/` 富文本渲染子模块（2,641 行）

| 文件 | 行数 | 证据 |
| ------ | ------ | ------ |
| `parser/epub/rich_parser.rs` | 737 | 唯一调用方是 content_ir（死） |
| `parser/epub/content_ir.rs` | 274 | `get_chapter_content_ir` / `html_to_chapter_ir` 全仓零调用 |
| `parser/epub/plain_text.rs` | 415 | 仅被 content_ir + provider（均死）引用 |
| `parser/epub/provider.rs` | 333 | `EpubContentProvider` / `ChapterContentProvider` 仅被 content_ir/image_size（均死）引用 |
| `parser/epub/css.rs` | 321 | 仅被 rich_parser / rich_style（均死）引用 |
| `parser/epub/rich_style.rs` | 218 | 仅被 rich_parser（死）引用 |
| `parser/epub/processed_image.rs` | 192 | 仅被死 API `get_processed_epub_image*` 与 content_ir（死）引用 |
| `parser/epub/image_size.rs` | 90 | 仅被死 API `get_image_dimensions` 与 content_ir（死）引用 |
| `parser/epub/rich_paragraph.rs` | 61 | 仅被 content_ir / rich_parser（均死）引用 |

> 保留 `archive_reader.rs`(302) / `toc.rs`(268) / `parse.rs`(189) — 它们是 `import_book` 的唯一解析路径（轻量元数据+章节），存活。
> 保留 `entry_extractor.rs` 中的 `get_metadata_first`（archive_reader 依赖），其 `get_epub_metadata` 函数随死 API 删除。
> 保留 `asset_registry.rs` 中的 `normalize_asset_path`（archive_reader 依赖），其余函数随死模块删除。

### A3. `infra/kv_store.rs`（294 行）— 整个 IR 缓存子系统

- `KvStore` / `ScrollIrCache` 的唯一消费方是 `chapter_ir`（死）与 `delete_book` 的缓存失效逻辑。
- IR 缓存**从不写入**（save/get 无调用方）→ 失效逻辑是空转。
- **删除原因**：连带 `redb`、`bincode` 两个依赖一起删。`delete_book` 中 `invalidate_book_cache` 那段（service.rs:95-113）可整体移除。

### A4. `pipeline` 删除后的级联修改点

- `domain/book/service.rs:18,100` — 移除 `IrCacheRepository` 导入与 delete_book 内的缓存失效块。
- `infra/manager.rs` — 移除 `kv` 字段与 `KvStore::new`（storage 初始化里建 cache 目录的逻辑）。

---

## B. 死 API 函数 — 33 个（对应 domain 服务/仓储函数随同删除）

按模块列出，均为 `lib/`（排除生成目录）零调用、已逐项人工复核。

| 模块 | 死函数 | 级联删除的 domain 面 |
| ------ | -------- | ---------------------- |
| `api/book.rs` | `get_book_by_file_path`, `create_web_book`, `get_epub_metadata`, `get_processed_epub_image_bytes`, `get_processed_epub_image`, `get_image_dimensions` | `book/service::create_web_book`；`EpubMetadata`/`EpubTocItem` struct（epub/mod.rs）及生成的 `parser/epub.dart` |
| `api/bookmark.rs` | `upsert_bookmark`, `delete_bookmarks`, `get_bookmark`, `delete_bookmarks_by_book`, `import_bookmarks`, `count_bookmarks_by_book` | bookmark_repo 对应方法（list/create/delete 单条存活） |
| `api/cover.rs` | `extract_book_cover` | cover/engine 对应分支（`extract_and_save_cover` 存活） |
| `api/dictionary.rs` | `create_dictionary`, `get_dictionary`, `lookup_mdict`, `suggest_mdict`, `extract_audio` | `dictionary/engine::lookup/suggest/extract_audio/has_resource`（open/close 存活） |
| `api/search.rs` | `index_chapter`, `count_matches`, `clear_search_index`, `delete_by_book`, `get_index_stats`, `segment_chinese_text` | search/engine 对应方法（`search`/`search_all_books` 存活） |
| `api/session.rs` | `list_sessions_by_book`, `list_sessions_by_date_range`, `create_session`, `upsert_session` | session_repo 对应方法（`list_by_recent`/`delete_by_book` 存活） |
| `api/stats.rs` | `get_today_reading_stats`, `get_reading_stats_by_range`, `get_reading_stats_by_days`, `update_daily_stats` | stats_repo 对应方法（`get_global`/`get_by_days_with_fill` 存活） |
| `api/vocab.rs` | `create_vocabulary_word` | vocab_repo 对应方法 |

> `backup.rs` 全部 5 个函数**存活**（备份/恢复 UI 正常调用）。

**删除原因（共性）**：Flutter 侧在迁移 Readium 时丢掉了对这些写入/管理动作的调用，函数成为 FRB 死导出；Dart 侧 `analysis_options.yaml` 排除 `lib/src/**`，生成文件静默存活，运行时也永远不会被调。删除需同步跑 `flutter_rust_bridge_codegen generate` 清理生成物（见主报告 A 类 11 个陈旧文件）。

---

## C. 死 Cargo 依赖

| 依赖 | 证据 | 动作 |
| ------ | ------ | ------ |
| `md5` | 全仓 0 处使用 | 直接删 |
| `itertools` | 全仓 0 处使用 | 直接删 |
| `unicode-segmentation` | 全仓 0 处使用 | 直接删 |
| `html5ever` + `markup5ever_rcdom` | 仅 rich_parser/css（死） | 随 A2 删 |
| `xxhash-rust` | 仅 processed_image（死） | 随 A2 删 |
| `dirs` | 仅 processed_image（死） | 随 A2 删 |
| `image` | 仅 processed_image/image_size/content_ir（均死）；cover/engine 走 epub crate 不直接用 image | 随 A2 删（删除前再确认 cover 路径无 `image::`） |
| `redb` + `bincode` | 仅 kv_store / pipeline types（死） | 随 A3 删 |
| `jieba-rs` | 仅 search/engine（index/segment 死，`search` 存活但查询是否分词待查） | 待查：若 `search` 不依赖分词，随 B 删 |
| `rs-mdict` | dictionary/engine `open` 存活（init/close 管理），lookup/suggest 死 | 保留（open 用） |

---

## D. 半死模块 — 只删死函数，保留存活面

- `parser/epub/entry_extractor.rs` — 保留 `get_metadata_first`，删 `get_epub_metadata` 及 EpubMetadata 结构。
- `parser/epub/asset_registry.rs` — 保留 `normalize_asset_path`，其余删。
- `domain/dictionary/engine.rs` — 保留 open/close，删 lookup/suggest/extract_audio。
- `domain/search/engine.rs` — 保留 new/ensure_table/search/search_all_books，删 index_chapter/count_matches/delete_by_book/clear_all/get_index_stats/tokenize_chinese_text。
- `domain/book/service.rs` — 删 create_web_book + delete_book 里的 IR 缓存失效块。
- `infra/manager.rs` / `infra/mod.rs` — 删 kv 相关字段与 mod 声明。

---

## E. 待决策区 — 功能缺口（不是纯冗余，需要产品决策）

这 5 项是"Rust 代码还活着、但 Flutter 侧写入动作已消失"的僵尸功能。保留则维持现状（功能不可用），删除则需连同对应 UI/统计一并下线。**建议 R14 之前逐项定夺**。

| # | 僵尸功能 | 现状 | 选项 |
| --- | ---------- | ------ | ------ |
| E1 | **TXT 全链**（`parser/txt/` 1,132 行 + `chapter_detect/` 324 行 + `encoding_rs`/`chardetng`/`memmap2` 依赖） | 导入仍允许 .txt（book_import_service 扩展名含 txt），但阅读入口显式拒绝（reader_page: "当前 MVP 仅支持 EPUB"） | A. 单引擎彻底化：导入也拒绝 txt → 全删。B. 保留 txt 导入（书架可管理，阅读不可用）→ 暂留 |
| E2 | **正文搜索索引**（FTS5） | `index_chapter` 无调用方 → 索引永远为空 → `search` 查询恒空。search_all_books/书名/生词搜索存活 | A. 用 Readium 读 spine 回填索引（补功能）。B. 删索引机制，仅留书名搜索 |
| E3 | **阅读会话记录** | `create_session`/`upsert_session` 无调用方 → 阅读时长/统计恒为 0（Readium view model 未接） | A. R10 补回（进度/Locator 保存时记录会话）。B. 统计页连同 stats 查询一起下线 |
| E4 | **生词本写入** | `create_vocabulary_word` 无调用方 → 生词页只读 | A. R13 补 UI。B. 删 vocab 写入面，仅保留统计展示 |
| E5 | **MDict 查词** | `lookup_mdict`/`suggest_mdict` 无调用方（Readium 无选区事件，查词入口缺失） | A. 等选区能力补上再恢复。B. 承认词典功能只剩管理，删查词引擎面 |

> E2-E5 与最近三次 commit 是同一根因：`19a878c8`（移除高亮按钮）、`c1932bfb`（移除 notes 系统）——**Readium 包装层没有选区/交互事件**，依赖选区的功能全部失去入口。若 R12/R13 恢复这些功能，对应的 Rust 面应保留而非删除。

---

## 删除后存活面预估

```
api/     book(子集) bookmark(子集) category cover backup dictionary(管理子集)
         search(子集) session(子集) stats(子集) vocab(子集)   ≈ 700 行
domain/  book bookmark category cover backup progress dictionary(子集)
         search(子集) sessions(子集) stats(子集) vocab(子集)
         chapter(+chapter_detect 依 E1)                        ≈ 3,200 行
parser/  epub{archive_reader,toc,parse,entry_extractor(子集),asset_registry(子集)}
         txt(依 E1) registry types provider                    ≈ 1,800 行
infra/   init manager(去 kv) common                            ≈ 500 行
```

删除 A 类 + B 类 + C 类后，Rust 源码约 14,000~15,500 行（视 E1 决策），全部有明确调用路径。

---

## 执行建议（走 R14）

1. **顺序**：A2/A3/A4（parser rich + pipeline + kv_store）→ A1 pipeline 目录 → B（死 API + domain 死函数）→ C（Cargo 依赖）→ D（半死修剪）→ E 逐项决策。
2. **门禁**：每步 `cargo clippy --all-targets -- -D warnings` + `cargo test`（金路径测试保持绿）；最后 `flutter_rust_bridge_codegen generate` 清理生成物 + `dart analyze --fatal-infos`。
3. **注意事项**：
   - `rust/tests/api_test.rs` 有用户未提交的 2 行修改，禁止 git reset/checkout 触碰（GIT 铁律）。
   - 删除 API 函数会连带删掉对应测试（如 `search_test.rs` 的 index/count 用例、`dictionary` 查词用例）——测试删减需在 R14 单独列清单。
   - `poc_path_escape.rs`（I1）与本报告无关，独立处理。

---

## ✅ 执行状态（R14 第一步，2026-08-02）

**已完成删除**：

| 类别 | 删除内容 | 说明 |
| ------ | --------- | ------ |
| A1 | `pipeline/` 整目录（5 文件） | 死模块 |
| A2 | `parser/epub/` 富文本 9 模块（content_ir/rich_parser/rich_style/rich_paragraph/css/image_size/processed_image/plain_text/provider） | 死模块 |
| A3 | `infra/kv_store.rs`（redb IR 缓存） | 死模块 |
| — | `parser/txt/` 整目录（5 文件） | TXT 链下线（单引擎 EPUB-only） |
| — | `domain/chapter_detect/` 整目录（6 文件） | TXT 链下线 |
| — | `parser/provider.rs`（ChapterContentProvider trait） | 仅被死模块引用 |
| B | `create_vocabulary_word` + `Vocab::new` + `vocab_repo.save` | 生词本写入下线（保留读取/更新/删除） |
| — | `BookMetadata`、`Parser::extract_metadata`、`BookFormat::Txt` 解析路径 | 单引擎决策落地；`format_from_extension("txt")` 返回 UnsupportedFormat |
| C | 死依赖：md5、itertools、unicode-segmentation、html5ever、markup5ever_rcdom、xxhash-rust、dirs、image、redb、bincode、chardetng、memmap2、regex | 保留 encoding_rs（archive_reader 活跃使用）、lru、uuid、parking_lot、epub、strum |

**级联修改**：`parser/mod.rs`（去 txt/provider）、`parser/types.rs`（去 BookMetadata）、`parser/registry.rs`（parser_for_format→Result）、`parser/epub/mod.rs`（去 9 子模块声明 + EpubMetadata/EpubTocItem）、`entry_extractor.rs`（去 get_epub_metadata）、`asset_registry.rs`（裁剪至 normalize_asset_path）、`infra/manager.rs`（去 kv 字段/4 处 flush）、`domain/book/service.rs`（去 IR 缓存失效）、`domain/mod.rs`/`infra/mod.rs`（去模块声明）、`api/vocab.rs`。

**测试**：删除 `api_chapter_test.rs`、`progress_test.rs`（测试已移除的 API 层）；`api_test.rs` 重写为 EPUB-only（保留用户未提交的 import 删除）；`storage_test.rs` 删 note 用例、适配 bookmark API 新签名；`api_session_test.rs` 适配 delete_sessions_by_book；删除孤儿测试辅助 `tests/common/reading_chain.rs`、`epub_local.rs` 及 `truncate_snippet`。

**门禁结果**：`cargo check --all-targets` ✅ · `cargo clippy --all-targets -- -D warnings` ✅ · `cargo test` 129 passed / 0 failed ✅ · FRB codegen ✅ · `dart analyze --fatal-infos` ✅

**未删（后续步骤）**：book 6 / bookmark 6 / dictionary 5 / search 6 / stats 4 / cover 1 死 API；session 4 按用户决策**保留**（R10 接线）；E2-E5 待决策区。

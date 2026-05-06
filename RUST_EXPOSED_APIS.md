# Rust 引擎暴露的 API 文档

> 自动生成时间: 2026-04-08  
> 总计暴露的公开函数: **104 个**

---

## 目录

- [一、核心 API 模块 (`api/core.rs`)](#一核心-api-模块-apicores)
- [二、存储 API 模块 (`api/storage.rs`)](#二存储-api-模块-apistoragers)
- [三、搜索 API 模块 (`api/search.rs`)](#三搜索-api-模块 apisearchrs)
- [四、EPUB API 模块 (`api/epub.rs`)](#四epub-api-模块-apiepubrs)
- [五、封面 API 模块 (`api/cover.rs`)](#五封面-api-模块-apicoverrs)
- [六、增量解析 API 模块 (`api/incremental.rs`)](#六增量解析-api-模块-apiincrementalrs)
- [七、文本排版模块 (`text_process/typeset.rs`)](#七文本排版模块-textprocesstypesetrs)
- [八、双语对齐模块 (`text_process/bilingual.rs`)](#八双语对齐模块-textprocessbilingualrs)
- [九、流式分页模块](#九流式分页模块)
- [十、性能指标模块 (`utils/metrics.rs`)](#十性能指标模块-utilsmetricsrs)
- [十一、PDF 解析模块](#十一pdf-解析模块)
- [十二、TXT 解析模块](#十二txt-解析模块)
- [十三、EPUB 解析模块](#十三epub-解析模块)
- [十四、PDF 封面提取模块](#十四pdf-封面提取模块)
- [统计汇总](#统计汇总)

---

## 一、核心 API 模块 (`api/core.rs`)

| # | 函数签名 | 类型 |
|---|---------|------|
| 1 | `pub fn parse_book(file_path: String) -> ApiResult<ParseResult>` | `sync` |
| 2 | `pub fn extract_metadata(file_path: String) -> ApiResult<BookMetadata>` | `sync` |
| 3 | `pub fn extract_chapter(file_path: String, chapter_id: i32) -> ApiResult<String>` | `sync` |
| 4 | `pub fn get_txt_chapter_content(file_path: String, chapter_index: i32, config: TypesetConfig) -> ApiResult<Vec<PageContent>>` | `sync` |
| 5 | `pub fn get_supported_formats() -> Vec<String>` | `sync` |
| 6 | `pub fn supports_format(format: String) -> bool` | `sync` |
| 7 | `pub fn typeset_text(content: String, language: String, config: TypesetConfig) -> ApiResult<String>` | `sync` |
| 8 | `pub fn get_file_size(file_path: String) -> ApiResult<i64>` | `sync` |
| 9 | `pub fn read_file_chunk(file_path: String, start_pos: i64, chunk_size: i64) -> ApiResult<String>` | `sync` |
| 10 | `pub fn create_page_streamer(content: String, config: TypesetConfig) -> PageStreamer` | `sync` |
| 11 | `pub fn paginate_all_content(content: String, chapter_id: i32, config: TypesetConfig) -> Vec<PageContent>` | `sync` |
| 12 | `pub fn init_app()` | `init` |
| 13 | `pub fn test_connection() -> String` | `sync` |
| 14 | `pub fn set_allowed_base_dir(base_dir: String) -> ApiResult<()>` | `sync` |

### 说明

- **`init_app()`**: 初始化 Rust 应用，设置默认的 user utils
- **`parse_book()`**: 解析书籍文件，返回完整的解析结果
- **`extract_metadata()`**: 提取书籍元数据（标题、作者等）
- **`extract_chapter()`**: 提取指定章节内容
- **`get_txt_chapter_content()`**: 获取 TXT 文件的章节内容（支持排版配置）
- **`create_page_streamer()`**: 创建分页流式读取器
- **`set_allowed_base_dir()`**: 设置允许访问的基础目录（安全限制）

---

## 二、存储 API 模块 (`api/storage.rs`)

### 书籍管理

| # | 函数签名 | 类型 |
|---|---------|------|
| 15 | `pub fn get_all_books() -> ApiResult<Vec<DbBookRecord>>` | `async` |
| 16 | `pub fn save_book(book: DbBookRecord) -> ApiResult<()>` | `async` |
| 17 | `pub fn delete_book(book_id: String) -> ApiResult<()>` | `async` |
| 18 | `pub fn search_books(keyword: String) -> ApiResult<Vec<DbBookRecord>>` | `async` |
| 43 | `pub fn get_book(book_id: String) -> ApiResult<Option<DbBookRecord>>` | `async` |
| 44 | `pub fn get_books_by_status(status: DbBookStatus) -> ApiResult<Vec<DbBookRecord>>` | `async` |
| 45 | `pub fn get_pinned_books() -> ApiResult<Vec<DbBookRecord>>` | `async` |
| 46 | `pub fn get_recently_read_books(limit: usize) -> ApiResult<Vec<DbBookRecord>>` | `async` |

### 章节管理

| # | 函数签名 | 类型 |
|---|---------|------|
| 19 | `pub fn get_chapters_by_book(book_id: String) -> ApiResult<Vec<DbChapter>>` | `async` |
| 20 | `pub fn save_chapters(book_id: String, chapters: Vec<DbChapter>) -> ApiResult<()>` | `async` |
| 21 | `pub fn delete_chapters_by_book(book_id: String) -> ApiResult<()>` | `async` |
| 62 | `pub fn get_chapter_by_index(book_id: String, chapter_index: i32) -> ApiResult<Option<DbChapter>>` | `async` |

### 阅读进度

| # | 函数签名 | 类型 |
|---|---------|------|
| 22 | `pub fn get_reading_progress(book_id: String) -> ApiResult<Option<DbReadingProgress>>` | `async` |
| 23 | `pub fn save_reading_progress(progress: DbReadingProgress) -> ApiResult<()>` | `async` |
| 24 | `pub fn clear_reading_progress(book_id: String) -> ApiResult<()>` | `async` |

### 书签管理

| # | 函数签名 | 类型 |
|---|---------|------|
| 25 | `pub fn get_bookmarks(book_id: String) -> ApiResult<Vec<DbBookmark>>` | `async` |
| 26 | `pub fn create_bookmark(bookmark: DbBookmark) -> ApiResult<()>` | `async` |
| 27 | `pub fn delete_bookmark(bookmark_id: String) -> ApiResult<()>` | `async` |
| 47 | `pub fn get_bookmark(bookmark_id: String) -> ApiResult<Option<DbBookmark>>` | `async` |
| 48 | `pub fn delete_bookmarks_by_book(book_id: String) -> ApiResult<()>` | `async` |
| 49 | `pub fn import_bookmarks(bookmarks: Vec<DbBookmark>) -> ApiResult<()>` | `async` |
| 64 | `pub fn get_bookmark_stats(book_id: String) -> ApiResult<i32>` | `async` |

### 阅读统计

| # | 函数签名 | 类型 |
|---|---------|------|
| 28 | `pub fn record_reading_session(session: DbReadingSession) -> ApiResult<()>` | `async` |
| 29 | `pub fn get_today_reading_stats() -> ApiResult<DbDailyReadingStats>` | `async` |
| 30 | `pub fn get_reading_stats_range(start_date: String, end_date: String) -> ApiResult<Vec<DbDailyReadingStats>>` | `async` |
| 31 | `pub fn get_global_reading_stats() -> ApiResult<DbGlobalStats>` | `async` |
| 69 | `pub fn update_daily_stats(stats: DbDailyReadingStats) -> ApiResult<()>` | `async` |

### 阅读会话

| # | 函数签名 | 类型 |
|---|---------|------|
| 50 | `pub fn get_reading_sessions(book_id: String, limit: usize) -> ApiResult<Vec<DbReadingSession>>` | `async` |
| 51 | `pub fn get_sessions_by_date_range(book_id: String, start_date: String, end_date: String) -> ApiResult<Vec<DbReadingSession>>` | `async` |
| 52 | `pub fn get_recent_sessions(limit: usize) -> ApiResult<Vec<DbReadingSession>>` | `async` |
| 53 | `pub fn delete_sessions_by_book(book_id: String) -> ApiResult<()>` | `async` |

### 分类管理

| # | 函数签名 | 类型 |
|---|---------|------|
| 32 | `pub fn get_all_categories() -> ApiResult<Vec<DbBookCategory>>` | `async` |
| 33 | `pub fn save_category(category: DbBookCategory) -> ApiResult<()>` | `async` |
| 34 | `pub fn delete_category(category_id: String) -> ApiResult<()>` | `async` |
| 35 | `pub fn get_categories_for_book(book_id: String) -> ApiResult<Vec<DbBookCategory>>` | `async` |
| 36 | `pub fn assign_category_to_book(book_id: String, category_id: String) -> ApiResult<()>` | `async` |
| 37 | `pub fn remove_category_from_book(book_id: String, category_id: String) -> ApiResult<()>` | `async` |
| 38 | `pub fn set_categories_for_book(book_id: String, category_ids: Vec<String>) -> ApiResult<()>` | `async` |
| 60 | `pub fn get_category(category_id: String) -> ApiResult<Option<DbBookCategory>>` | `async` |
| 61 | `pub fn clear_categories_for_book(book_id: String) -> ApiResult<()>` | `async` |

### 布局缓存

| # | 函数签名 | 类型 |
|---|---------|------|
| 39 | `pub fn save_layout_cache(cache: DbLayoutCache, key: LayoutCacheKey) -> ApiResult<()>` | `async` |
| 40 | `pub fn get_layout_cache(book_id: String, chapter_index: i32, config_hash: String) -> ApiResult<Option<DbLayoutCache>>` | `async` |
| 41 | `pub fn clear_layout_cache(book_id: String) -> ApiResult<()>` | `async` |
| 42 | `pub fn cleanup_expired_layout_cache(max_age_days: i64) -> ApiResult<usize>` | `async` |

### 同步记录

| # | 函数签名 | 类型 |
|---|---------|------|
| 54 | `pub fn save_sync_record(record: DbSyncRecord) -> ApiResult<()>` | `async` |
| 55 | `pub fn get_pending_sync_records(book_id: String) -> ApiResult<Vec<DbSyncRecord>>` | `async` |
| 56 | `pub fn update_sync_status(record_id: String, status: DbSyncStatus, remote_version: Option<i32>) -> ApiResult<()>` | `async` |
| 57 | `pub fn get_sync_conflicts(book_id: String) -> ApiResult<Vec<DbSyncRecord>>` | `async` |
| 58 | `pub fn clear_sync_conflicts(book_id: String) -> ApiResult<()>` | `async` |
| 59 | `pub fn delete_sync_record(record_id: String) -> ApiResult<()>` | `async` |
| 65 | `pub fn clear_all_sync_records() -> ApiResult<()>` | `async` |

### 书签同步

| # | 函数签名 | 类型 |
|---|---------|------|
| 63 | `pub fn sync_bookmarks(local_bookmarks: Vec<DbBookmark>, remote_bookmarks: Vec<DbBookmark>) -> ApiResult<Vec<DbBookmark>>` | `async` |

### 笔记管理

| # | 函数签名 | 类型 |
|---|---------|------|
| 66 | `pub fn create_note(note: DbNote) -> ApiResult<DbNote>` | `async` |
| 67 | `pub fn get_notes(book_id: String, note_type: Option<DbNoteType>) -> ApiResult<Vec<DbNote>>` | `async` |
| 68 | `pub fn delete_note(note_id: String) -> ApiResult<()>` | `async` |

---

## 三、搜索 API 模块 (`api/search.rs`)

| # | 函数签名 | 类型 |
|---|---------|------|
| 70 | `pub fn init_search_engine(db_path: String) -> ApiResult<()>` | `async` |
| 71 | `pub fn index_chapter_content(book_id: String, chapter_id: i32, chapter_title: String, content: String) -> ApiResult<()>` | `async` |
| 72 | `pub fn search_in_book(book_id: String, query: String, limit: i32) -> ApiResult<Vec<SearchResult>>` | `async` |
| 73 | `pub fn clear_all_search_index() -> ApiResult<()>` | `async` |

### 说明

- **`init_search_engine()`**: 初始化全文搜索引擎（基于 Tantivy）
- **`index_chapter_content()`**: 将章节内容添加到搜索索引
- **`search_in_book()`**: 在指定书籍中搜索
- **`clear_all_search_index()`**: 清空所有搜索索引

---

## 四、EPUB API 模块 (`api/epub.rs`)

| # | 函数签名 | 类型 |
|---|---------|------|
| 74 | `pub fn get_epub_metadata(file_path: String) -> ApiResult<EpubMetadata>` | `sync` |
| 75 | `pub fn parse_epub_chapter_rich(file_path: String, chapter_index: i32) -> ApiResult<RichChapterContent>` | `sync` |
| 76 | `pub fn get_epub_chapter_content(file_path: String, chapter_id: i32, config: TypesetConfig) -> ApiResult<Vec<PageContent>>` | `sync` |
| 77 | `pub fn get_epub_chapter_rich_content(file_path: String, chapter_id: i32, config: TypesetConfig) -> ApiResult<Vec<RichParagraph>>` | `sync` |
| 78 | `pub fn paginate_epub_rich_content(paragraphs: Vec<RichParagraph>, chapter_index: i32, config: TypesetConfig) -> Vec<PageContent>` | `sync` |
| 79 | `pub fn is_epub_file(file_path: String) -> bool` | `sync` |

### 说明

- **`get_epub_metadata()`**: 提取 EPUB 文件元数据
- **`parse_epub_chapter_rich()`**: 解析 EPUB 章节为富文本内容
- **`get_epub_chapter_content()`**: 获取 EPUB 章节的排版后内容
- **`get_epub_chapter_rich_content()`**: 获取 EPUB 章节的富文本段落
- **`paginate_epub_rich_content()`**: 对 EPUB 富文本内容进行分页
- **`is_epub_file()`**: 检查文件是否为 EPUB 格式

---

## 五、封面 API 模块 (`api/cover.rs`)

| # | 函数签名 | 类型 |
|---|---------|------|
| 80 | `pub fn extract_book_cover(file_path: String, output_dir: String) -> ApiResult<String>` | `sync` |
| 81 | `pub fn supports_cover_extraction(file_path: String) -> bool` | `sync` |

### 说明

- **`extract_book_cover()`**: 提取书籍封面图片，返回输出路径
- **`supports_cover_extraction()`**: 检查文件是否支持封面提取

---

## 六、增量解析 API 模块 (`api/incremental.rs`)

| # | 函数签名 | 类型 |
|---|---------|------|
| 82 | `pub fn init_incremental_parser() -> ApiResult<()>` | `sync` |
| 83 | `pub fn parse_local_book_incremental(file_path: String) -> ApiResult<LocalBookInfo>` | `sync` |
| 84 | `pub fn clear_incremental_parser_cache() -> ApiResult<()>` | `sync` |
| 85 | `pub fn get_incremental_parser_stats() -> CacheStats` | `sync` |

### 说明

- **`init_incremental_parser()`**: 初始化增量解析器
- **`parse_local_book_incremental()`**: 使用增量模式解析本地书籍（支持缓存）
- **`clear_incremental_parser_cache()`**: 清空增量解析缓存
- **`get_incremental_parser_stats()`**: 获取增量解析器的缓存统计信息

---

## 七、文本排版模块 (`text_process/typeset.rs`)

| # | 函数签名 | 类型 |
|---|---------|------|
| 86 | `pub fn typeset_content(content: String, language: String, config: TypesetConfig) -> ApiResult<String>` | `sync` |
| 87 | `pub fn apply_hyphenation(text: String, enable_hyphenation: bool) -> String` | `sync` |
| 88 | `pub fn typeset_content_with_hyphenation(content: String, language: String, config: TypesetConfig, enable_hyphenation: bool) -> ApiResult<String>` | `sync` |

### 说明

- **`typeset_content()`**: 对文本内容进行排版（支持语言设置）
- **`apply_hyphenation()`**: 应用英文连字规则
- **`typeset_content_with_hyphenation()`**: 排版内容并支持连字

---

## 八、双语对齐模块 (`text_process/bilingual.rs`)

| # | 函数签名 | 类型 |
|---|---------|------|
| 89 | `pub fn align_bilingual_content(chinese_content: String, english_content: String, min_similarity: f32) -> Result<BilingualAlignment, ParserError>` | `sync` |
| 90 | `pub fn simple_bilingual_align(chinese_content: String, english_content: String) -> BilingualAlignment` | `sync` |

### 说明

- **`align_bilingual_content()`**: 对中英文双语内容进行对齐（支持相似度阈值）
- **`simple_bilingual_align()`**: 简单的双语对齐（使用默认参数）

---

## 九、流式分页模块

### `stream/page_stream.rs`

| # | 函数签名 | 类型 |
|---|---------|------|
| 92 | `pub fn paginate_all(content: String, chapter_id: i32, config: TypesetConfig) -> Vec<PageContent>` | `sync` |

### `stream/file_stream.rs`

| # | 函数签名 | 类型 |
|---|---------|------|
| 91 | `pub fn read_chunk(file_path: String, start_pos: i64, chunk_size: i64) -> ApiResult<String>` | `sync` |

### 说明

- **`read_chunk()`**: 从文件中读取指定位置的文本块
- **`paginate_all()`**: 对全部内容进行分页，返回所有页面

---

## 十、性能指标模块 (`utils/metrics.rs`)

| # | 函数签名 | 类型 |
|---|---------|------|
| 93 | `pub fn get_performance_stats() -> MetricsStats` | `sync` |
| 94 | `pub fn reset_performance_stats()` | `sync` |

### 说明

- **`get_performance_stats()`**: 获取性能指标统计信息
- **`reset_performance_stats()`**: 重置性能指标统计

---

## 十一、PDF 解析模块

### `parser/pdf/parse.rs`

| # | 函数签名 | 类型 |
|---|---------|------|
| 95 | `pub fn parse_pdf(file_path: String) -> ApiResult<ParseResult>` | `sync` |
| 96 | `pub async fn async_parse_pdf_file(file_path: String) -> ApiResult<ParseResult>` | `async` |
| 97 | `pub fn get_pdf_page_count(file_path: String) -> i32` | `sync` |
| 98 | `pub fn get_pdf_metadata(file_path: String) -> PdfMetadata` | `sync` |

### 说明

- **`parse_pdf()`**: 同步解析 PDF 文件
- **`async_parse_pdf_file()`**: 异步解析 PDF 文件（支持大文件）
- **`get_pdf_page_count()`**: 获取 PDF 页数
- **`get_pdf_metadata()`**: 获取 PDF 元数据

---

## 十二、TXT 解析模块

### `parser/txt/parse.rs`

| # | 函数签名 | 类型 |
|---|---------|------|
| 99 | `pub fn parse_txt(file_path: String) -> ApiResult<ParseResult>` | `sync` |
| 100 | `pub fn parse_txt_with_config(file_path: String, config: ParseConfig) -> ApiResult<ParseResult>` | `sync` |

### 说明

- **`parse_txt()`**: 解析 TXT 文件
- **`parse_txt_with_config()`**: 使用配置解析 TXT 文件（支持自定义章节分隔符等）

---

## 十三、EPUB 解析模块

### `parser/epub/parse.rs`

| # | 函数签名 | 类型 |
|---|---------|------|
| 101 | `pub fn parse_epub(file_path: String) -> ApiResult<ParseResult>` | `sync` |
| 102 | `pub fn parse_epub_with_config(file_path: String, config: ParseConfig) -> ApiResult<ParseResult>` | `sync` |

### `parser/epub/unzip.rs`

| # | 函数签名 | 类型 |
|---|---------|------|
| 103 | `pub fn get_epub_metadata(file_path: &str) -> ApiResult<EpubMetadata>` | `sync` |

### 说明

- **`parse_epub()`**: 解析 EPUB 文件
- **`parse_epub_with_config()`**: 使用配置解析 EPUB 文件
- **`get_epub_metadata()`**: 提取 EPUB 元数据

---

## 十四、PDF 封面提取模块

### `parser/pdf/images.rs`

| # | 函数签名 | 类型 |
|---|---------|------|
| 104 | `pub fn extract_pdf_cover(file_path: &str, output_dir: &str) -> ApiResult<String>` | `sync` |

### 说明

- **`extract_pdf_cover()`**: 从 PDF 文件中提取封面图片

---

## 统计汇总

| 标记类型 | 数量 | 说明 |
|---------|------|------|
| `#[frb(sync)]` | **98** | 同步函数，直接在 Dart 主线程或后台执行 |
| `#[frb]` (默认) | **58** | 默认异步函数（FRB 默认为异步） |
| `#[frb(async)]` | **1** | 显式异步函数 (`async_parse_pdf_file`) |
| `#[frb(init)]` | **1** | 初始化函数 (`init_app`) |

**总计暴露的公开函数: 104 个**

---

## 模块文件路径汇总

| 模块 | 文件路径 |
|------|---------|
| 核心 API | `rust/src/api/core.rs` |
| 存储 API | `rust/src/api/storage.rs` |
| 搜索 API | `rust/src/api/search.rs` |
| EPUB API | `rust/src/api/epub.rs` |
| 封面 API | `rust/src/api/cover.rs` |
| 增量解析 | `rust/src/api/incremental.rs` |
| 文本排版 | `rust/src/text_process/typeset.rs` |
| 双语对齐 | `rust/src/text_process/bilingual.rs` |
| 文件流读取 | `rust/src/stream/file_stream.rs` |
| 流式分页 | `rust/src/stream/page_stream.rs` |
| 性能指标 | `rust/src/utils/metrics.rs` |
| PDF 解析 | `rust/src/parser/pdf/parse.rs` |
| TXT 解析 | `rust/src/parser/txt/parse.rs` |
| EPUB 解析 | `rust/src/parser/epub/parse.rs` |
| EPUB 解压 | `rust/src/parser/epub/unzip.rs` |
| PDF 封面 | `rust/src/parser/pdf/images.rs` |

---

## 核心数据类型

### 书籍相关

- `ParseResult` - 解析结果
- `BookMetadata` - 书籍元数据
- `DbBookRecord` - 数据库书籍记录
- `DbChapter` - 数据库章节
- `EpubMetadata` - EPUB 元数据
- `PdfMetadata` - PDF 元数据
- `LocalBookInfo` - 本地书籍信息

### 阅读相关

- `DbReadingProgress` - 阅读进度
- `DbBookmark` - 书签
- `DbReadingSession` - 阅读会话
- `DbDailyReadingStats` - 每日阅读统计
- `DbGlobalStats` - 全局统计

### 排版相关

- `TypesetConfig` - 排版配置
- `PageContent` - 页面内容
- `RichParagraph` - 富文本段落
- `RichChapterContent` - 富文本章节
- `BilingualAlignment` - 双语对齐结果

### 存储相关

- `DbBookCategory` - 书籍分类
- `DbLayoutCache` - 布局缓存
- `DbSyncRecord` - 同步记录
- `DbSyncStatus` - 同步状态
- `DbNote` - 笔记
- `DbNoteType` - 笔记类型
- `DbBookStatus` - 书籍状态
- `LayoutCacheKey` - 布局缓存键

### 搜索相关

- `SearchResult` - 搜索结果

### 其他

- `CacheStats` - 缓存统计
- `MetricsStats` - 性能指标统计
- `ApiResult<T>` - API 返回结果类型
- `PageStreamer` - 分页流式读取器
- `ParseConfig` - 解析配置

---

## 使用示例

### Dart 端调用示例

```dart
import 'package:zephyr_reader/src/rust/api/core.dart' as rust_core;
import 'package:zephyr_reader/src/rust/api/storage.dart' as rust_storage;

// 初始化 Rust 应用
rust_core.initApp();

// 解析书籍
final parseResult = rust_core.parseBook(filePath: 'path/to/book.epub');

// 获取所有书籍
final books = await rust_storage.getAllBooks();

// 保存阅读进度
final progress = DbReadingProgress(
  bookId: 'book-123',
  chapterIndex: 5,
  progress: 0.65,
);
await rust_storage.saveReadingProgress(progress: progress);
```

---

## 注意事项

1. **同步 vs 异步**: 
   - `sync` 函数会阻塞调用线程，适合快速操作
   - `async` 函数在后台执行，不会阻塞 UI，适合数据库操作

2. **错误处理**: 
   - 所有返回 `ApiResult<T>` 的函数都可能抛出异常
   - Dart 端需要使用 `try-catch` 捕获错误

3. **类型映射**:
   - Rust 的 `String` → Dart 的 `String`
   - Rust 的 `Vec<T>` → Dart 的 `List<T>`
   - Rust 的 `Option<T>` → Dart 的 `T?`
   - Rust 的 `i32/i64` → Dart 的 `int`
   - Rust 的 `bool` → Dart 的 `bool`

4. **初始化**: 
   - 必须在应用启动时调用 `init_app()` 
   - 搜索引擎需要单独调用 `init_search_engine()`
   - 增量解析器需要调用 `init_incremental_parser()`

5. **安全限制**:
   - 使用 `set_allowed_base_dir()` 设置允许访问的目录
   - 文件路径必须在允许的目录范围内

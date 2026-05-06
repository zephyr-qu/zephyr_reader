# Rust 阅读引擎

Zephyr Reader 的高性能阅读引擎，基于 Rust 实现，提供书籍解析、文本处理、全文搜索和本地数据库存储等功能。

## 功能特性

### 📖 书籍解析

- **TXT 文件解析**
  - 自动编码检测（UTF-8, GBK, GB2312, Big5 等）
  - 中文章节标题自动识别
  - 流式加载，支持大文件
  - 增量解析（支持缓存优化）

- **EPUB 文件解析**
  - EPUB2/EPUB3 兼容
  - 目录提取
  - 元数据读取（书名、作者、封面）
  - 富文本内容解析（支持 HTML 标签）

- **PDF 文件解析**
  - PDF 文本提取
  - 元数据读取
  - 封面提取
  - 同步/异步解析模式

### 🎨 文本处理

- **智能排版**
  - 中英文智能断行
  - 标点符号避首避尾
  - 中英文混排优化
  - 英文连字支持（Hyphenation）

- **双语对齐**
  - 中英文内容智能对齐
  - 相似度阈值控制
  - 段落级对齐算法

- **章节处理**
  - 章节标题自动检测
  - 章节内容提取
  - 富文本段落解析

### 🔍 全文搜索

- 基于 Tantivy 搜索引擎
- 章节内容索引
- 书籍内搜索
- 高性能查询

### 🗄️ 本地存储

- 基于 Drift (SQLite) 数据库
- 书籍管理（CRUD）
- 章节管理
- 阅读进度跟踪
- 书签管理
- 阅读统计与会话
- 书籍分类
- 布局缓存（排版缓存优化）
- 同步记录（WebDAV 同步）
- 笔记管理

### 📄 流式处理

- 大文件分块读取
- 内存回收机制
- 内容分页输出
- 分页流式读取

### 🖼️ 封面提取

- EPUB 封面提取
- PDF 封面提取
- 格式支持检测

## 目录结构

```
rust/
├── src/
│   ├── api/                      # FFI API 接口
│   │   ├── mod.rs                # 模块声明
│   │   ├── core.rs               # 核心解析 API
│   │   ├── storage.rs            # 数据库存储 API
│   │   ├── search.rs             # 全文搜索 API
│   │   ├── epub.rs               # EPUB 特有功能 API
│   │   ├── cover.rs              # 封面提取 API
│   │   └── incremental.rs        # 增量解析 API
│   │
│   ├── parser/                   # 文件解析器
│   │   ├── mod.rs
│   │   ├── txt/                  # TXT 解析
│   │   │   ├── mod.rs
│   │   │   ├── decode.rs         # 编码检测
│   │   │   └── parse.rs          # 内容解析
│   │   ├── epub/                 # EPUB 解析
│   │   │   ├── mod.rs
│   │   │   ├── unzip.rs          # EPUB 解压
│   │   │   ├── parse.rs          # 内容解析
│   │   │   └── toc.rs            # 目录提取
│   │   └── pdf/                  # PDF 解析
│   │       ├── mod.rs
│   │       ├── parse.rs          # PDF 解析
│   │       └── images.rs         # PDF 封面提取
│   │
│   ├── text_process/             # 文本处理
│   │   ├── mod.rs
│   │   ├── typeset.rs            # 文本排版
│   │   └── bilingual.rs          # 双语对齐
│   │
│   ├── stream/                   # 流式加载
│   │   ├── mod.rs
│   │   ├── file_stream.rs        # 文件流
│   │   └── page_stream.rs        # 分页流
│   │
│   ├── search/                   # 搜索引擎
│   │   ├── mod.rs
│   │   └── engine.rs             # Tantivy 搜索引擎
│   │
│   ├── storage/                  # 数据库存储
│   │   ├── mod.rs
│   │   ├── database.rs           # 数据库连接
│   │   ├── models.rs             # 数据模型
│   │   └── repositories/         # 数据访问层
│   │
│   ├── utils/                    # 工具函数
│   │   ├── mod.rs
│   │   ├── metrics.rs            # 性能指标
│   │   ├── path_util.rs          # 路径工具
│   │   └── string_util.rs        # 字符串工具
│   │
│   ├── lib.rs                    # 库入口
│   └── frb_generated.rs          # FRB 生成代码
│
├── Cargo.toml                    # Rust 依赖配置
└── Cargo.lock                    # 依赖锁定文件
```

## 环境要求

### 必需工具

1. **Rust 工具链** (Edition 2021+)
   ```bash
   # 安装 Rust
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

   # 验证安装
   rustc --version
   cargo --version
   ```

2. **Android 交叉编译支持** (仅 Android)
   ```bash
   rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
   ```

3. **C 编译器**
   - **Windows**: Visual Studio Build Tools 2019+
   - **Linux**: gcc, clang
   - **macOS**: Xcode Command Line Tools

## 构建命令

### 检查编译

```bash
cd rust/
cargo check
```

### 开发构建

```bash
cargo build
```

### 发布构建

```bash
cargo build --release
```

### 生成 FRB 绑定代码

在项目根目录运行：

```bash
flutter_rust_bridge_codegen build
```

### 运行测试

```bash
cargo test
```

## API 接口

> 完整 API 文档请查看 [`RUST_EXPOSED_APIS.md`](../RUST_EXPOSED_APIS.md)

### 初始化

```rust
// Rust
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
```

```dart
// Dart
await RustLib.init();
rust_core.initApp();
```

### 解析书籍

```dart
// 自动识别格式
final result = rust_core.parseBook(filePath: path);

// 增量解析（支持缓存）
final incrementalResult = rust_api.parseLocalBookIncremental(filePath: path);

// 提取元数据
final metadata = rust_core.extractMetadata(filePath: path);
```

### 获取章节内容

```dart
// 获取 TXT 章节
final pages = rust_core.getTxtChapterContent(
  filePath: path,
  chapterIndex: index,
  config: typesetConfig,
);

// 获取 EPUB 章节
final epubPages = rust_epub.getEpubChapterContent(
  filePath: path,
  chapterId: chapterId,
  config: typesetConfig,
);

// 获取 EPUB 富文本内容
final richContent = rust_epub.getEpubChapterRichContent(
  filePath: path,
  chapterId: chapterId,
  config: typesetConfig,
);
```

### 文本排版

```dart
// 基础排版
final typeset = rust_core.typesetText(
  content: text,
  language: 'zh',
  config: typesetConfig,
);

// 带连字的排版
final typesetWithHyphen = rust_typeset.typesetContentWithHyphenation(
  content: text,
  language: 'en',
  config: typesetConfig,
  enableHyphenation: true,
);
```

### 双语对齐

```dart
// 带相似度阈值的双语对齐
final alignment = rust_bilingual.alignBilingualContent(
  chineseContent: chineseText,
  englishContent: englishText,
  minSimilarity: 0.8,
);

// 简单双语对齐
final simpleAlignment = rust_bilingual.simpleBilingualAlign(
  chineseContent: chineseText,
  englishContent: englishText,
);
```

### 全文搜索

```dart
// 初始化搜索引擎
await rust_search.initSearchEngine(dbPath: dbPath);

// 索引章节内容
await rust_search.indexChapterContent(
  bookId: bookId,
  chapterId: chapterId,
  chapterTitle: title,
  content: content,
);

// 在书籍中搜索
final results = await rust_search.searchInBook(
  bookId: bookId,
  query: '搜索词',
  limit: 20,
);
```

### 数据库存储

```dart
// 书籍管理
final books = await rust_storage.getAllBooks();
await rust_storage.saveBook(book: bookRecord);
await rust_storage.deleteBook(bookId: bookId);
final searchBooks = await rust_storage.searchBooks(keyword: '关键词');

// 阅读进度
final progress = await rust_storage.getReadingProgress(bookId: bookId);
await rust_storage.saveReadingProgress(progress: progress);

// 书签管理
final bookmarks = await rust_storage.getBookmarks(bookId: bookId);
await rust_storage.createBookmark(bookmark: bookmark);

// 阅读统计
final todayStats = await rust_storage.getTodayReadingStats();
final rangeStats = await rust_storage.getReadingStatsRange(
  startDate: '2024-01-01',
  endDate: '2024-12-31',
);
```

## 数据结构

### 核心类型

#### ParseResult
```rust
pub struct ParseResult {
    pub book_info: BookInfo,
    pub chapters: Vec<ChapterInfo>,
    pub metadata: BookMetadata,
}
```

#### BookMetadata
```rust
pub struct BookMetadata {
    pub title: String,
    pub author: String,
    pub description: String,
    pub publisher: String,
    pub language: String,
    pub cover_path: Option<String>,
}
```

#### PageContent
```rust
pub struct PageContent {
    pub chapter_id: i32,
    pub page_index: i32,
    pub content: String,
    pub is_last_page: bool,
}
```

#### TypesetConfig
```rust
pub struct TypesetConfig {
    pub page_width: i32,
    pub page_height: i32,
    pub font_size: i32,
    pub line_spacing: f64,
    pub letter_spacing: f64,
    pub paragraph_spacing: f64,
    pub first_line_indent: i32,
    pub language: String,
}
```

### 数据库类型

#### DbBookRecord
```rust
pub struct DbBookRecord {
    pub book_id: String,
    pub title: String,
    pub author: String,
    pub file_path: String,
    pub file_type: String,
    pub cover_path: Option<String>,
    pub chapter_count: i32,
    pub total_characters: i64,
    pub status: DbBookStatus,
    pub is_pinned: bool,
    pub created_at: i64,
    pub updated_at: i64,
}
```

#### DbChapter
```rust
pub struct DbChapter {
    pub chapter_id: String,
    pub book_id: String,
    pub title: String,
    pub chapter_index: i32,
    pub start_offset: i64,
    pub end_offset: i64,
    pub content_length: i64,
}
```

#### DbReadingProgress
```rust
pub struct DbReadingProgress {
    pub book_id: String,
    pub chapter_index: i32,
    pub chapter_id: Option<String>,
    pub progress: f64,
    pub character_offset: i64,
    pub last_read_at: i64,
}
```

#### DbBookmark
```rust
pub struct DbBookmark {
    pub bookmark_id: String,
    pub book_id: String,
    pub chapter_index: i32,
    pub character_offset: i64,
    pub note: String,
    pub created_at: i64,
}
```

### 搜索类型

#### SearchResult
```rust
pub struct SearchResult {
    pub book_id: String,
    pub chapter_id: i32,
    pub chapter_title: String,
    pub snippet: String,
    pub score: f32,
    pub character_offset: i64,
}
```

### 双语对齐类型

#### BilingualAlignment
```rust
pub struct BilingualAlignment {
    pub pairs: Vec<(String, String)>,
    pub confidence: f32,
}
```

## 支持的格式

| 格式 | 解析 | 元数据 | 封面 | 搜索 |
|------|------|--------|------|------|
| TXT  | ✅   | ✅     | ❌   | ✅   |
| EPUB | ✅   | ✅     | ✅   | ✅   |
| PDF  | ✅   | ✅     | ✅   | ✅   |

## 错误处理

所有 API 调用返回 `ApiResult<T>` 类型，建议使用 try-catch 处理：

```dart
try {
  final result = rust_core.parseBook(filePath: path);
  // 处理结果
} catch (e) {
  // 处理错误
  print('解析失败：$e');
}
```

常见错误类型：
- `FileNotFound` - 文件不存在
- `UnsupportedFormat` - 不支持的文件格式
- `ParseError` - 解析错误
- `DatabaseError` - 数据库操作错误
- `SearchError` - 搜索引擎错误

## 性能优化

### 解析优化

1. **增量解析**: 使用 `parseLocalBookIncremental` 支持缓存，避免重复解析
2. **异步解析**: PDF 支持异步解析模式 (`asyncParsePdfFile`)
3. **流式加载**: 大文件使用流式 API，避免一次性加载

### 存储优化

1. **布局缓存**: 排版结果缓存到数据库，加速重复访问
2. **批量操作**: 使用批量保存接口减少数据库事务
3. **索引优化**: 数据库索引优化查询性能

### 搜索优化

1. **倒排索引**: 基于 Tantivy 的倒排索引
2. **限制结果**: 使用 `limit` 参数限制搜索结果数量
3. **增量索引**: 支持增量更新搜索索引

### 内存管理

1. **分页加载**: 使用分页 API 按需加载内容
2. **及时释放**: 不再使用的页面内容及时释放
3. **缓存清理**: 定期清理过期缓存 (`cleanupExpiredLayoutCache`)

## 开发注意事项

1. **编码问题**: TXT 文件会自动检测编码，但建议在导入时告知用户
2. **EPUB 兼容性**: 支持主流 EPUB2/EPUB3 格式，但某些特殊 EPUB 可能无法解析
3. **章节检测**: 使用正则表达式匹配章节标题，可能无法识别所有格式
4. **排版规则**: 中英文混排已优化，但特殊格式可能需要手动调整
5. **安全限制**: 使用 `setAllowedBaseDir` 设置允许访问的目录
6. **初始化顺序**: 
   - 必须先调用 `initApp()`
   - 搜索引擎需要单独调用 `initSearchEngine()`
   - 增量解析器需要调用 `initIncrementalParser()`

## API 分类

### 同步 API (`#[frb(sync)]`)

直接在 Dart 调用，适合快速操作：
- 书籍解析
- 文本排版
- 封面提取
- 文件格式检查

### 异步 API (`#[frb]` 默认)

在后台执行，不阻塞 UI：
- 数据库操作
- 搜索操作
- 阅读统计

### 特殊 API

- `init_app()` - 初始化应用
- `async_parse_pdf_file()` - 显式异步 PDF 解析

## 测试

运行单元测试：

```bash
cargo test
```

测试覆盖：
- 编码检测
- 章节提取
- 断行规则
- 排版优化
- 文件流读取
- 数据库操作
- 搜索引擎

## 完整 API 列表

查看完整的 API 文档：[`RUST_EXPOSED_APIS.md`](../RUST_EXPOSED_APIS.md)

包含 **104 个公开函数**，分布在 **14 个模块**中。

## 许可证

本项目为个人自用项目，不对外分发。
